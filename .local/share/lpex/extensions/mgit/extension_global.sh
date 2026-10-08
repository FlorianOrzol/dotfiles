#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 0.1.0
# @meta_date        : 2026-10-04
#
# @desc_short       : Shared logic of all mgit submodules.
# @desc_detailed    : Manages bare repositories whose work tree is $HOME (dotfiles
# @desc_detailed    : principle). Every repository belongs to an area — public or
# @desc_detailed    : private. The area is the first path segment after 'mgit' and
# @desc_detailed    : doubles as branch name. Thin submodules (public/add, all/push …)
# @desc_detailed    : only call the mgit_action_* functions below with their area.
#
# @req_packages     : git, curl, jq, find, realpath, sudo (apply only)
#
# @config_env       : SERVERS_PUBLIC      | Server keys of the public area, first = fetch source
# @config_env       : SERVERS_PRIVATE     | Server keys of the private area
# @config_env       : SERVER_<KEY>_TYPE   | github | forgejo | gitlab
# @config_env       : SERVER_<KEY>_URL_SSH| SSH clone URL, %s = repository name
# @config_env       : SERVER_<KEY>_URL_API| API base URL
# @config_env       : SERVER_<KEY>_OWNER  | User or organisation that owns the repositories
# @config_env       : SERVER_<KEY>_OWNER_IS_ORG | 1 = create in organisation, 0 = in user account
# @config_env       : SERVER_<KEY>_TOKEN_CMD    | Command printing the API token (empty = prompt)
#
# @notes            : Data zone layout ($PATH_EXTENSION_DATA = ~/.local/state/lpex/data/mgit):
# @notes            :   repos/<area>/<repo>/      git dir (excluded from every scan)
# @notes            :   <area>/<repo>.remotes     remote URLs, first = fetch, all = push (registry)
# @notes            :   <area>/<repo>.tracked     tracked roots relative to $HOME
# @notes            :   <area>/<repo>.excluded    paths inside tracked roots kept out
# @notes            :   <area>/<repo>.conf        optional: WORKTREE=<relpath> (project repo), BRANCH=<name>
# @notes            :   system.list + system/     root-owned files for 'private apply'
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# Paths, binaries and check patterns shared by all actions. Wrapped in a function
# with declare -g, because the completion engine sources this file inside a
# function — plain declarations would turn local there.
# ==============================================================================
function _mgit_globals {
    declare -g CMD_GIT="/usr/bin/git"                                   # git binary
    declare -g CMD_CURL="/usr/bin/curl"                                 # HTTP client for the server APIs
    declare -g CMD_JQ="/usr/bin/jq"                                     # JSON parser for API answers
    declare -g PATH_MGIT_DATA="${PATH_EXTENSION_DATA:-$HOME/.local/state/lpex/data/mgit}"   # data zone of the extension
    declare -g PATH_MGIT_REPOS="${PATH_MGIT_DATA}/repos"                # git dirs: repos/<area>/<repo>
    declare -g RELPATH_MGIT_REPOS="${PATH_MGIT_REPOS#"$HOME"/}"         # same, relative to the work tree
    declare -g PATH_MGIT_SYSTEM="${PATH_MGIT_DATA}/system"              # sources of root-owned files
    declare -g FILE_MGIT_SYSTEM_LIST="${PATH_MGIT_DATA}/system.list"    # target, mode, owner, validator per line
    declare -g THRESHOLD_FILE_SIZE_KB=1024                              # larger public files need a confirmation
    declare -ga MGIT_AREAS=("public" "private")                         # all areas — also the branch names
    declare -gA MGIT_TOKENS=()                                          # API tokens fetched during this run

    # Paths never allowed in a public repo (extended regex against the $HOME-relative path)
    declare -ga PATTERNS_DENY_PATH=(
        '(^|/)\.ssh/'
        '(^|/)\.gnupg/'
        '(^|/)\.password-store/'
        '(^|/)\.local/share/keyrings/'
        '(^|/)\.config/rbw/'
        '(^|/)\.local/share/rbw/'
        '(^|/)id_[A-Za-z0-9_]+(\.pub)?$'
        '\.(pem|key|p12|pfx|kdbx|gpg|asc)$'
        '(^|/)\.env(\.[^/]*)?$'
        '(^|/)\.netrc$'
        '(^|/)\.git-credentials$'
        '(^|/)\.?[^/]*_history$'
        '(^|/)\.histfile$'
        '(^|/)[Cc]ookies[^/]*$'
    )

    # File content that is always a secret — blocks add and commit
    declare -ga PATTERNS_SECRET_HARD=(
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
        'gh[pousr]_[A-Za-z0-9]{36}'
        'github_pat_[A-Za-z0-9_]{22,}'
        'glpat-[A-Za-z0-9_-]{20}'
        'AKIA[0-9A-Z]{16}'
        'xox[abprs]-[A-Za-z0-9-]{10,}'
    )

    # File content that may be a secret — asked interactively, blocked in the hook
    declare -ga PATTERNS_SECRET_SOFT=(
        '(password|passwd|secret|token|api[_-]?key)[[:space:]]*[:=][[:space:]]*["'\'']?[^[:space:]"'\''$]{8,}'
    )
}
_mgit_globals

# ==============================================================================
# --- Actions ---
# One function per CLI action. Every action takes the area as first parameter;
# the 'all' submodules call them once per area.
# ==============================================================================

# --- mgit_action_list ---
# @desc_short       : Shows repositories, remotes, tracked roots and exclusions.
# @usage            : mgit_action_list <area> [repo] [show_files]
# @parameter        : $1 | area       | public | private
# @parameter        : $2 | repo       | Only this repository (default: all of the area)
# @parameter        : $3 | show_files | 1 = also print every tracked file
# ================================================================================
function mgit_action_list {
    local area="$1"
    local repo_filter="$2"
    local show_files="${3:-0}"
    local repos=()
    local repo url_remote relpath_entry count_files state_local

    # Resolve the repositories to show — a given name must be registered
    _mgit_repos_of_area @repos "$area" "$repo_filter" || return 1

    output --section "${area^^}"

    # An area without repositories still gets its header, so 'all list' stays readable
    if (( ! ${#repos[@]} )); then
        output --info "No repositories. Create one with: lpex mgit ${area} create <repo>"
        return 0
    fi

    # One block per repository
    for repo in "${repos[@]}"; do
        # Count tracked files only when the git dir exists on this machine
        if [[ -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
            count_files="$(_mgit_git "$area" "$repo" ls-files | wc -l)"
            state_local="${count_files} files, $(_mgit_sync_state "$area" "$repo")"
        else
            state_local="not cloned — run: lpex mgit ${area} pull ${repo}"
        fi
        output --subsection "${repo}  (${state_local})"

        # Branch and work tree — project repositories live outside $HOME's root
        printf '%b\n' "  ${FONT_GRAY}branch${FONT_RESET} $(_mgit_branch "$area" "$repo")  ${FONT_GRAY}worktree${FONT_RESET} $(_mgit_worktree "$area" "$repo" | sed "s|^${HOME}|~|")"

        # Remotes: the first one is the fetch source
        while IFS= read -r url_remote; do
            [[ -n "$url_remote" ]] && printf '%b\n' "  ${FONT_GRAY}remote${FONT_RESET} ${url_remote}"
        done < "$(_mgit_file_list "$area" "$repo" remotes)"

        # Tracked roots in green
        while IFS= read -r relpath_entry; do
            [[ -n "$relpath_entry" ]] && printf '%b\n' "  ${FONT_GREEN}[+]${FONT_RESET} ~/${relpath_entry}"
        done < <(_mgit_read_list "$area" "$repo" tracked)

        # Exclusions in red
        while IFS= read -r relpath_entry; do
            [[ -n "$relpath_entry" ]] && printf '%b\n' "  ${FONT_RED}[-]${FONT_RESET} ~/${relpath_entry}"
        done < <(_mgit_read_list "$area" "$repo" excluded)

        # Optional full file listing — only possible with a local git dir
        if (( show_files )) && [[ -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
            _mgit_git "$area" "$repo" ls-files | sed 's|^|      ~/|'
        fi
    done
}

# --- mgit_action_status ---
# @desc_short       : Shows changed files and files the next push would add.
# @usage            : mgit_action_status <area> [repo]
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Only this repository (default: all of the area)
# ================================================================================
function mgit_action_status {
    local area="$1"
    local repo_filter="$2"
    local repos=()
    local pathspecs=()
    local files_new=()
    local files_taken=()
    local repo relpath_new

    # Resolve the repositories to inspect
    _mgit_repos_of_area @repos "$area" "$repo_filter" || return 1

    output --section "${area^^}"

    # One block per repository
    for repo in "${repos[@]}"; do
        # Skip repositories that only exist in the registry
        if [[ ! -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
            output --subsection "${repo}  (not cloned)"
            continue
        fi
        output --subsection "${repo}  ($(_mgit_sync_state "$area" "$repo"))"

        # Changes of already tracked files
        _mgit_git "$area" "$repo" status --short

        # Project repositories show untracked files in 'status' already
        _mgit_is_project "$area" "$repo" && continue

        # New files below the tracked roots — everything is ignored by '*', so they show up as ignored
        _mgit_pathspecs @pathspecs "$area" "$repo"
        files_new=()
        # Only query git when there is at least one existing tracked root
        if (( ${#pathspecs[@]} )); then
            mapfile -d '' -t files_new < <(_mgit_git "$area" "$repo" ls-files -z --others --ignored --exclude-standard -- "${pathspecs[@]}")
        fi

        # Files of other repositories in shared folders are not this repository's business
        (( ${#files_new[@]} )) && _mgit_split_foreign @files_new @files_taken "$area" "$repo" "${files_new[@]}"

        # List what the next push would add — public asks first
        for relpath_new in "${files_new[@]}"; do
            if [[ "$area" == "public" ]]; then
                printf '%b\n' " ${FONT_GREEN}+${FONT_RESET} ${relpath_new}  ${FONT_GRAY}(new, asked on push)${FONT_RESET}"
            else
                printf '%b\n' " ${FONT_GREEN}+${FONT_RESET} ${relpath_new}  ${FONT_GRAY}(new, added on push)${FONT_RESET}"
            fi
        done
    done
}

# --- mgit_action_add ---
# @desc_short       : Adds a file or directory to a repository after safety checks.
# @usage            : mgit_action_add <area> <repo> <path>
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Target repository
# @parameter        : $3 | path | File or directory below $HOME
# ================================================================================
function mgit_action_add {
    local area="$1"
    local repo="$2"
    local path_input="$3"
    local relpath=""
    local files=()
    local files_own=()
    local files_taken=()
    local relpath_file

    # 1. --- Validation ---------------
    _mgit_require_local "$area" "$repo" || return 1
    _mgit_require_home "$area" "$repo" add || return 1

    # A path is required — fzf cannot offer one
    if [[ -z "$path_input" ]]; then
        ERROR "No path specified. Usage: lpex mgit ${area} add ${repo} --path <path>"
        return 1
    fi

    # Normalize to a $HOME-relative path
    _mgit_relpath @relpath "$path_input" || return 1

    # The path must exist — otherwise there is nothing to add
    if [[ ! -e "${HOME}/${relpath}" && ! -L "${HOME}/${relpath}" ]]; then
        ERROR "Path does not exist: ~/${relpath}"
        return 1
    fi

    # Never track the git dirs of mgit itself
    if [[ "$relpath" == "$RELPATH_MGIT_REPOS" || "$relpath" == "$RELPATH_MGIT_REPOS/"* ]]; then
        ERROR "The git dirs of mgit cannot be added: ~/${relpath}"
        return 1
    fi

    # A folder that is its own repository would only be stored as a pointer (gitlink), never its files
    if [[ -e "${HOME}/${relpath}/.git" ]]; then
        ERROR "~/${relpath} is its own git repository."
        INFO "Git would store only a link to its commit. Take it over as project repository instead:"
        INFO "  lpex mgit ${area} import <repo> --path ~/${relpath}"
        return 1
    fi

    # 2. --- Preview and checks ---------------
    # Collect every file the path brings in, minus exclusions of this repository
    _mgit_collect_files @files "$area" "$repo" "$relpath"

    # An empty directory gives git nothing to track
    if (( ! ${#files[@]} )); then
        WARN "No files found below ~/${relpath}."
        return 1
    fi

    # A file lives in exactly one repository — files of others stay there (shared folder)
    _mgit_split_foreign @files_own @files_taken "$area" "$repo" "${files[@]}"
    if (( ${#files_taken[@]} )); then
        output --info "${#files_taken[@]} of ${#files[@]} file(s) already belong to other repositories — they stay there:"
        printf '  %s\n' "${files_taken[@]:0:20}"
        (( ${#files_taken[@]} > 20 )) && output --info "… and $(( ${#files_taken[@]} - 20 )) more."
    fi
    files=("${files_own[@]}")

    # Everything is taken: the folder can still be shared for future files
    if (( ! ${#files[@]} )); then
        if question "No free files. Register ~/${relpath} as shared folder, so new files can go to ${area}/${repo}?" --default-no; then
            _mgit_list_add "$area" "$repo" tracked "$relpath"
            OK "~/${relpath} registered as shared folder in ${area}/${repo}."
        fi
        return 0
    fi

    # Public content gets the secret and size checks
    if [[ "$area" == "public" ]]; then
        _mgit_check_public interactive "$HOME" "${files[@]}" || return 1
    fi

    output --section "Add to ${area^^} repository '${repo}'"
    output --info "Path: ~/${relpath} (${#files[@]} files)"

    # Show the files — long lists are cut, the count above stays exact
    for relpath_file in "${files[@]:0:40}"; do
        printf '%b\n' "  ${FONT_GREEN}+${FONT_RESET} ${relpath_file}"
    done
    # Hint at the cut part of the list
    if (( ${#files[@]} > 40 )); then
        output --info "… and $(( ${#files[@]} - 40 )) more."
    fi

    # 3. --- Confirmation ---------------
    # First gate: the path itself
    if ! question "Add these files to the ${area^^} repository '${repo}'?" --default-no; then
        output --info "Skipped ~/${relpath}."
        return 0
    fi

    # Second gate for public: name the servers the files will be visible on
    if [[ "$area" == "public" ]]; then
        if ! question "The files become PUBLICLY visible on: $(_mgit_list_remote_hosts "$area" "$repo"). Really continue?" --default-no; then
            output --info "Skipped ~/${relpath}."
            return 0
        fi
    fi

    # 4. --- Stage and remember ---------------
    # Force-add exactly the reviewed files past the '*' exclude — never files of other repositories
    if ! printf '%s\0' "${files[@]/#/:(literal)}" | _mgit_git "$area" "$repo" add -f --pathspec-from-file=- --pathspec-file-nul; then
        ERROR "git add failed for ~/${relpath}"
        return 1
    fi

    # Remember the root, so the next push picks up new files below it
    _mgit_list_add "$area" "$repo" tracked "$relpath"

    # Adding a path again lifts an earlier exclusion of exactly this path
    _mgit_list_remove "$area" "$repo" excluded "$relpath"

    OK "~/${relpath} staged in ${area}/${repo}. Commit and upload with: lpex mgit ${area} push ${repo}"
}

# --- mgit_action_rm ---
# @desc_short       : Stops tracking a path; the files stay on disk.
# @usage            : mgit_action_rm <area> <repo> <path>
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Repository
# @parameter        : $3 | path | File or directory below $HOME
# ================================================================================
function mgit_action_rm {
    local area="$1"
    local repo="$2"
    local path_input="$3"
    local relpath=""
    local relpath_root
    local is_inside_root=0

    _mgit_require_local "$area" "$repo" || return 1
    _mgit_require_home "$area" "$repo" rm || return 1

    # A path is required
    if [[ -z "$path_input" ]]; then
        ERROR "No path specified. Usage: lpex mgit ${area} rm ${repo} --path <path>"
        return 1
    fi

    # Normalize — the path itself may already be gone from disk
    _mgit_relpath @relpath "$path_input" || return 1

    # Remove from the index only — --cached keeps the files in $HOME
    if ! _mgit_git "$area" "$repo" rm -r -q --cached --ignore-unmatch -- ":(literal)${relpath}"; then
        ERROR "git rm failed for ~/${relpath}"
        return 1
    fi

    # Exactly a tracked root: forget the root
    if _mgit_list_contains "$area" "$repo" tracked "$relpath"; then
        _mgit_list_remove "$area" "$repo" tracked "$relpath"
        OK "~/${relpath} removed from the tracked roots of ${area}/${repo}."
        return 0
    fi

    # Inside a tracked root: the next push would add it again — exclude it
    while IFS= read -r relpath_root; do
        # Prefix match on whole path segments
        if [[ "$relpath" == "${relpath_root}/"* ]]; then
            is_inside_root=1
            break
        fi
    done < <(_mgit_read_list "$area" "$repo" tracked)

    # Only paths inside a root need the exclusion list
    if (( is_inside_root )); then
        _mgit_list_add "$area" "$repo" excluded "$relpath"
        OK "~/${relpath} excluded from ${area}/${repo} (inside ~/${relpath_root})."
    else
        WARN "~/${relpath} is not part of ${area}/${repo}'s tracked roots — only the index was cleaned."
    fi
    INFO "The removal is uploaded with: lpex mgit ${area} push ${repo}"
}

# --- mgit_action_push ---
# @desc_short       : Picks up new files, commits and uploads to all remotes.
# @usage            : mgit_action_push <area> [repo] [message]
# @parameter        : $1 | area    | public | private
# @parameter        : $2 | repo    | Only this repository (default: all of the area)
# @parameter        : $3 | message | Commit message (default: timestamp)
# ================================================================================
function mgit_action_push {
    local area="$1"
    local repo_filter="$2"
    local message="${3:-Update $(date '+%Y-%m-%d %H:%M')}"
    local repos=()
    local files_changed=()
    local repo count_ahead
    local count_failed=0

    # Resolve the repositories to upload
    _mgit_repos_of_area @repos "$area" "$repo_filter" || return 1

    # One block per repository — a failing repository does not stop the others
    for repo in "${repos[@]}"; do
        output --section "Push ${area}/${repo}"

        # Repositories that only exist in the registry have nothing to upload
        if [[ ! -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
            WARN "Not cloned on this machine — run: lpex mgit ${area} pull ${repo}"
            continue
        fi

        # 1. --- Stage ---------------
        _mgit_stage_tracked "$area" "$repo" || { (( count_failed++ )); continue; }

        # Shared folders: files of other repositories stay there
        _mgit_drop_foreign "$area" "$repo"
        # Public decides first which new files are published — the rest stays private
        [[ "$area" == "public" ]] && _mgit_review_new_public "$area" "$repo"

        # 2. --- Review staged changes ---------------
        # Commit only when the index differs from HEAD
        if ! _mgit_git "$area" "$repo" diff --cached --quiet; then
            # Show what goes into the commit
            _mgit_git "$area" "$repo" diff --cached --name-status

            mapfile -d '' -t files_changed < <(_mgit_git "$area" "$repo" diff --cached --name-only -z --diff-filter=ACMRT)

            # Public: secret and size checks over everything that changed
            if [[ "$area" == "public" ]] && (( ${#files_changed[@]} )); then
                # Checks failed or were declined — leave the index for the next attempt
                if ! _mgit_check_public interactive "$(_mgit_worktree "$area" "$repo")" "${files_changed[@]}"; then
                    ERROR "Nothing committed in ${area}/${repo}."
                    (( count_failed++ ))
                    continue
                fi
            fi

            # --no-verify: the hook runs the same checks non-interactively, they just passed
            if ! _mgit_git "$area" "$repo" commit -q --no-verify -m "$message"; then
                ERROR "Commit failed in ${area}/${repo}."
                (( count_failed++ ))
                continue
            fi
        else
            output --info "No local changes."
        fi

        # 3. --- Upload ---------------
        count_ahead="$(_mgit_git "$area" "$repo" rev-list --count "@{u}..HEAD" 2>/dev/null || echo "unknown")"

        # Nothing ahead of the remote: done
        if [[ "$count_ahead" == "0" ]]; then
            output --info "Remote is up to date."
            continue
        fi

        # Push to every push URL of origin
        if _mgit_git "$area" "$repo" push -q -u origin "$(_mgit_branch "$area" "$repo")"; then
            OK "${area}/${repo} pushed."
        else
            ERROR "Push of ${area}/${repo} failed. Remote ahead? Run: lpex mgit ${area} pull ${repo}"
            (( count_failed++ ))
        fi
    done

    # Non-zero when at least one repository failed
    (( count_failed == 0 ))
}

# --- mgit_action_pull ---
# @desc_short       : Fetches and applies remote changes; clones missing repositories.
# @usage            : mgit_action_pull <area> [repo]
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Only this repository (default: all of the area)
# ================================================================================
function mgit_action_pull {
    local area="$1"
    local repo_filter="$2"
    local repos=()
    local repo
    local count_failed=0

    # Resolve the repositories to update
    _mgit_repos_of_area @repos "$area" "$repo_filter" || return 1

    # One block per repository — a failing repository does not stop the others
    for repo in "${repos[@]}"; do
        output --section "Pull ${area}/${repo}"

        # Missing on this machine: first-time checkout into $HOME
        if [[ ! -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
            _mgit_clone "$area" "$repo" || (( count_failed++ ))
            continue
        fi

        # Rebase local commits on top, stash uncommitted edits meanwhile
        if _mgit_git "$area" "$repo" pull -q --rebase --autostash origin "$(_mgit_branch "$area" "$repo")"; then
            OK "${area}/${repo} is up to date."
        else
            ERROR "Pull of ${area}/${repo} failed. Resolve with: lpex mgit ${area} git ${repo} status"
            (( count_failed++ ))
        fi
    done

    # Non-zero when at least one repository failed
    (( count_failed == 0 ))
}

# --- mgit_action_create ---
# @desc_short       : Creates a repository on the area's servers and locally.
# @usage            : mgit_action_create <area> <repo> [local_only] [path]
# @parameter        : $1 | area       | public | private
# @parameter        : $2 | repo       | Name of the new repository
# @parameter        : $3 | local_only | 1 = skip the server API (repository exists already)
# @parameter        : $4 | path       | Project folder — without it a home repository is created
# ================================================================================
function mgit_action_create {
    local area="$1"
    local repo="$2"
    local local_only="${3:-0}"
    local path_input="${4:-}"
    local servers=()
    local urls=()
    local relpath_worktree=""
    local server

    # 1. --- Validation ---------------
    # Ask for the name when none was given
    if [[ -z "$repo" ]]; then
        lx input @repo --prompt "Name of the new ${area} repository" || return 1
    fi

    _mgit_validate_new "$area" "$repo" || return 1

    # Project folder relative to $HOME; '~' itself means home repository
    _mgit_worktree_input @relpath_worktree "$path_input" || return 1

    # The area needs at least one configured server
    _mgit_area_servers @servers "$area" || return 1
    _mgit_server_urls @urls "$repo" "${servers[@]}"

    # 2. --- Confirmation ---------------
    output --section "Create ${area^^} repository '${repo}'"
    printf '  %s\n' "${urls[@]}"
    # Creating is cheap to undo, but public visibility is not
    if ! question "Create ${area} repository '${repo}' (branch '${area}')?"; then
        output --info "Aborted."
        return 0
    fi

    # 3. --- Servers ---------------
    # Without --local-only every server gets the repository via its API
    if (( ! local_only )); then
        for server in "${servers[@]}"; do
            _mgit_server_create "$area" "$server" "$repo" || return 1
        done
    fi

    # 4. --- Local repository ---------------
    _mgit_register "$area" "$repo" "$relpath_worktree" "" "${urls[@]}"

    _mgit_init_local "$area" "$repo" || return 1

    # An empty first commit gives the branch something to push
    if ! _mgit_git "$area" "$repo" commit -q --allow-empty --no-verify -m "Initialize ${area} repository ${repo}"; then
        ERROR "Initial commit failed."
        return 1
    fi

    # Upload the branch to every push URL
    if ! _mgit_git "$area" "$repo" push -q -u origin "$(_mgit_branch "$area" "$repo")"; then
        ERROR "Initial push failed — check SSH access to the servers."
        return 1
    fi

    # The default branch can only be set once the branch exists on the server
    if (( ! local_only )); then
        for server in "${servers[@]}"; do
            _mgit_server_set_default_branch "$area" "$server" "$repo"
        done
    fi

    OK "${area}/${repo} created. Add content with: lpex mgit ${area} add ${repo} --path <path>"
}

# --- mgit_action_import ---
# @desc_short       : Takes over a repository that exists on the server, with its history.
# @usage            : mgit_action_import <area> <repo> [path] [branch]
# @parameter        : $1 | area   | public | private
# @parameter        : $2 | repo   | Name of the repository on the servers
# @parameter        : $3 | path   | Project folder — without it a home repository (paths relative to $HOME)
# @parameter        : $4 | branch | Branch to use (default: the server's default branch)
# @notes            : The first server must have the repository. Further servers of the
# @notes            : area get it created if missing and receive the history (mirror).
# ================================================================================
function mgit_action_import {
    local area="$1"
    local repo="$2"
    local path_input="${3:-}"
    local branch="${4:-}"
    local servers=()
    local urls=()
    local relpath_worktree=""
    local server

    # 1. --- Validation ---------------
    _mgit_validate_new "$area" "$repo" || return 1
    _mgit_area_servers @servers "$area" || return 1
    _mgit_server_urls @urls "$repo" "${servers[@]}"

    # Project folder relative to $HOME; '~' itself means home repository
    _mgit_worktree_input @relpath_worktree "$path_input" || return 1

    # Default branch of the source, read over SSH — needs no API token
    if [[ -z "$branch" ]]; then
        branch="$("$CMD_GIT" ls-remote --symref "${urls[0]}" HEAD 2>/dev/null | sed -n 's|^ref: refs/heads/\(.*\)\tHEAD$|\1|p')"
    fi
    # Nothing came back: unreachable, missing or empty repository
    if [[ -z "$branch" ]]; then
        ERROR "${urls[0]} is not reachable or has no branch — does the repository exist?"
        return 1
    fi

    # 2. --- Confirmation ---------------
    output --section "Import ${area^^} repository '${repo}'"
    printf '  %s\n' "${urls[@]}"
    output --info "Branch: ${branch}"
    # Home repositories check out right into $HOME — say so explicitly
    if [[ -n "$relpath_worktree" ]]; then
        output --info "Project folder: ~/${relpath_worktree}"
    else
        output --warn "Home repository: its files are checked out relative to \$HOME."
    fi
    if ! question "Import ${area}/${repo}?"; then
        output --info "Aborted."
        return 0
    fi

    # 3. --- Mirrors ---------------
    # Every server after the first gets the repository if it does not exist yet
    for server in "${servers[@]:1}"; do
        _mgit_server_create "$area" "$server" "$repo" || return 1
    done

    # 4. --- Local repository ---------------
    _mgit_register "$area" "$repo" "$relpath_worktree" "$branch" "${urls[@]}"
    # Differing local files are only overwritten after a question
    _mgit_clone "$area" "$repo" || return 1

    # Mirrors start empty — hand them the full history once
    if (( ${#servers[@]} > 1 )); then
        _mgit_git "$area" "$repo" push -q origin "$branch" || WARN "Mirror push failed — retry with: lpex mgit ${area} push ${repo}"
    fi

    # Home repositories need their roots, or push only sees already tracked files
    if [[ -z "$relpath_worktree" ]]; then
        INFO "Register the tracked roots so push finds new files: lpex mgit ${area} add ${repo} --path <path>"
    fi
}

# --- mgit_action_delete ---
# @desc_short       : Deletes a repository on its servers and locally.
# @usage            : mgit_action_delete <area> <repo> [local_only]
# @parameter        : $1 | area       | public | private
# @parameter        : $2 | repo       | Repository to delete
# @parameter        : $3 | local_only | 1 = keep it on the servers, only forget it on this machine
# @notes            : Files in $HOME are never touched. The servers come from the
# @notes            : repository's .remotes — only configured servers can be reached
# @notes            : by API; unknown remotes are reported and left alone.
# ================================================================================
function mgit_action_delete {
    local area="$1"
    local repo="$2"
    local local_only="${3:-0}"
    local servers=()
    local servers_delete=()
    local urls_remote=()
    local name_confirm=""
    local server url_server url_remote is_known

    # 1. --- Validation ---------------
    _mgit_require_registered "$area" "$repo" || return 1

    mapfile -t urls_remote < <(_mgit_read_list "$area" "$repo" remotes)

    # Match every remote URL to a configured server of the area
    if (( ! local_only )); then
        _mgit_area_servers @servers "$area" || return 1
        for url_remote in "${urls_remote[@]}"; do
            is_known=0
            for server in "${servers[@]}"; do
                # shellcheck disable=SC2059  # the template is the format string by design
                url_server="$(printf "$(_mgit_server_var "$server" URL_SSH)" "$repo")"
                # Same URL: this server hosts the repository
                if [[ "$url_server" == "$url_remote" ]]; then
                    servers_delete+=("$server")
                    is_known=1
                fi
            done
            # A remote outside the config cannot be deleted by API
            (( is_known )) || WARN "No configured server for ${url_remote} — delete it there by hand."
        done
    fi

    # 2. --- Confirmation ---------------
    output --section "Delete ${area^^} repository '${repo}'"
    # Show exactly what is going to disappear
    if (( ${#servers_delete[@]} )); then
        output --warn "On the servers (with its whole history): ${servers_delete[*]}"
    else
        output --info "The servers keep the repository."
    fi
    output --warn "On this machine: git dir and registry entry (.remotes, .tracked, .excluded)"
    output --info "Files in $(_mgit_worktree "$area" "$repo" | sed "s|^${HOME}|~|") stay untouched."

    # Public repositories may have users beyond this machine
    if [[ "$area" == "public" ]] && (( ${#servers_delete[@]} )); then
        WARN "This is a PUBLIC repository — clones and links of other people break."
    fi

    # Typing the name prevents deleting the wrong repository by a slip
    lx input @name_confirm --prompt "Type '${repo}' to confirm" || return 1
    if [[ "$name_confirm" != "$repo" ]]; then
        output --info "Name did not match — nothing deleted."
        return 0
    fi

    # 3. --- Servers ---------------
    # Stop on the first failure — the local entry stays, so the call can be repeated
    for server in "${servers_delete[@]}"; do
        _mgit_server_delete "$server" "$repo" || return 1
    done

    # 4. --- Local ---------------
    rm -rf -- "$(_mgit_path_gitdir "$area" "$repo")"
    rm -f -- "$(_mgit_file_list "$area" "$repo" remotes)" \
        "$(_mgit_file_list "$area" "$repo" tracked)" \
        "$(_mgit_file_list "$area" "$repo" excluded)" \
        "$(_mgit_file_list "$area" "$repo" conf)"

    OK "${area}/${repo} deleted."
}

# --- mgit_action_git ---
# @desc_short       : Runs a raw git command against a repository (exception wrapper).
# @usage            : mgit_action_git <area> <repo> <git-args…>
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Repository
# @parameter        : $@ | args | Arguments passed to git unchanged
# @notes            : Runs in the caller's directory (no -C $HOME), so relative paths
# @notes            : typed by the user keep their meaning.
# ================================================================================
function mgit_action_git {
    local area="$1"
    local repo="$2"
    shift 2

    _mgit_require_local "$area" "$repo" || return 1

    # Hand everything to git with the repository's git dir and work tree
    "$CMD_GIT" --git-dir="$(_mgit_path_gitdir "$area" "$repo")" --work-tree="$(_mgit_worktree "$area" "$repo")" "$@"
}

# --- mgit_action_check ---
# @desc_short       : Non-interactive check of the staged files (pre-commit hook).
# @usage            : mgit_action_check <area> <repo>
# @parameter        : $1 | area | public | private
# @parameter        : $2 | repo | Repository
# @notes            : Exit 1 blocks the commit. Private repositories always pass.
# ================================================================================
function mgit_action_check {
    local area="$1"
    local repo="$2"
    local files_changed=()
    local files_new=()

    _mgit_require_local "$area" "$repo" || return 1

    # Only public content needs protection
    [[ "$area" == "public" ]] || return 0

    # Staged additions and modifications — GIT_INDEX_FILE of a running commit is honoured
    mapfile -d '' -t files_changed < <(_mgit_git "$area" "$repo" diff --cached --name-only -z --diff-filter=ACMRT)
    mapfile -d '' -t files_new < <(_mgit_git "$area" "$repo" diff --cached --name-only -z --diff-filter=A)

    # Nothing staged: nothing to block
    (( ${#files_changed[@]} )) || return 0

    # New files must not belong to another repository
    if (( ${#files_new[@]} )); then
        _mgit_check_overlap "$area" "$repo" "${files_new[@]}" || return 1
    fi

    # Secret checks — soft findings block too, there is nobody to ask
    _mgit_check_public hook "$(_mgit_worktree "$area" "$repo")" "${files_changed[@]}"
}

# --- mgit_action_apply ---
# @desc_short       : Installs root-owned files from the private data zone (e.g. sudoers).
# @usage            : mgit_action_apply [collect]
# @parameter        : $1 | collect | 1 = copy the system files into the sources instead
# @notes            : system.list line format: <target> <mode> <owner:group> <validator>
# @notes            :   e.g. /etc/sudoers.d/florian 0440 root:root visudo
# @notes            : Validators: visudo | none
# ================================================================================
function mgit_action_apply {
    local collect="${1:-0}"
    local file_target mode owner validator file_source

    # Nothing registered yet: explain the format instead of failing
    if [[ ! -s "$FILE_MGIT_SYSTEM_LIST" ]]; then
        output --info "No system files registered."
        output --info "Add lines to ${FILE_MGIT_SYSTEM_LIST}: <target> <mode> <owner:group> <visudo|none>"
        return 0
    fi

    output --section "System files"

    # One entry per line on fd 3 — stdin stays free for the questions
    while read -r -u 3 file_target mode owner validator; do
        # Comments and empty lines
        [[ -z "$file_target" || "$file_target" == "#"* ]] && continue
        file_source="${PATH_MGIT_SYSTEM}${file_target}"
        output --subsection "$file_target"

        # Collect mode: system → source, nothing is installed
        if (( collect )); then
            # Root-only files (sudoers) need sudo to be read
            if sudo test -e "$file_target"; then
                mkdir -p "$(dirname "$file_source")"
                sudo cat "$file_target" > "$file_source"
                OK "Collected into ${file_source}"
            else
                WARN "Not present on this system — skipped."
            fi
            continue
        fi

        # A registered file without source cannot be installed
        if [[ ! -f "$file_source" ]]; then
            WARN "No source at ${file_source} — run: lpex mgit private apply --collect"
            continue
        fi

        # Identical content: nothing to do
        if sudo cmp -s "$file_source" "$file_target" 2>/dev/null; then
            output --info "Unchanged."
            continue
        fi

        # Show the change — a missing target diffs against nothing
        sudo diff -u --label "$file_target" --label "source" "$(sudo test -e "$file_target" && echo "$file_target" || echo /dev/null)" "$file_source"

        # Validate before anything touches the system — a broken sudoers locks out sudo
        case "$validator" in
            visudo)
                sudo visudo -c -q -f "$file_source" || { ERROR "visudo rejects ${file_source} — not installed."; continue; } ;;
            none|"") ;;
            *)
                ERROR "Unknown validator '${validator}' — not installed."; continue ;;
        esac

        # Last gate before the root-owned file is replaced
        if ! question "Install ${file_target} (${mode} ${owner})?" --default-no; then
            output --info "Skipped."
            continue
        fi

        # install sets content, mode and owner in one step
        sudo install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$file_source" "$file_target" \
            && OK "Installed." \
            || ERROR "Install failed."
    done 3< "$FILE_MGIT_SYSTEM_LIST"
}

# ==============================================================================
# --- Repository Helpers ---
# Paths, registry lists and the git call itself.
# ==============================================================================

# --- mgit_repo_names ---
# @desc_short       : Prints the registered repositories of an area, one per line.
# @usage            : mgit_repo_names <area>
# @notes            : Exported — used by --option-cmd inside a bash -c subshell.
# ================================================================================
function mgit_repo_names {
    local area="$1"
    local file_remotes

    # Every registered repository owns a .remotes file named after it
    for file_remotes in "${PATH_MGIT_DATA}/${area}"/*.remotes; do
        # The unmatched glob stays literal when the area is empty
        [[ -e "$file_remotes" ]] || continue
        basename "$file_remotes" .remotes
    done
}

# --- _mgit_path_gitdir ---
# @desc_short       : Prints the git dir of a repository.
# @usage            : _mgit_path_gitdir <area> <repo>
# ================================================================================
function _mgit_path_gitdir {
    local area="$1"
    local repo="$2"
    echo "${PATH_MGIT_REPOS}/${area}/${repo}"
}

# --- _mgit_file_list ---
# @desc_short       : Prints the path of a registry list (remotes | tracked | excluded).
# @usage            : _mgit_file_list <area> <repo> <kind>
# ================================================================================
function _mgit_file_list {
    local area="$1"
    local repo="$2"
    local kind="$3"
    echo "${PATH_MGIT_DATA}/${area}/${repo}.${kind}"
}

# --- _mgit_git ---
# @desc_short       : Runs git against a repository from inside $HOME.
# @usage            : _mgit_git <area> <repo> <git-args…>
# ================================================================================
function _mgit_git {
    local area="$1"
    local repo="$2"
    shift 2
    local path_worktree
    path_worktree="$(_mgit_worktree "$area" "$repo")"
    "$CMD_GIT" -C "$path_worktree" --git-dir="$(_mgit_path_gitdir "$area" "$repo")" --work-tree="$path_worktree" "$@"
}

# --- _mgit_repo_setting ---
# @desc_short       : Prints a per-repository setting from <repo>.conf (WORKTREE | BRANCH).
# @usage            : _mgit_repo_setting <area> <repo> <key>
# @notes            : Missing file or key prints nothing — the caller applies the default.
# ================================================================================
function _mgit_repo_setting {
    local area="$1"
    local repo="$2"
    local key="$3"
    local file_conf
    file_conf="$(_mgit_file_list "$area" "$repo" conf)"
    # Plain KEY=value lines; never sourced, so the file cannot run code
    [[ -f "$file_conf" ]] && sed -n "s/^${key}=//p" "$file_conf" | head -n1
    return 0
}

# --- _mgit_worktree ---
# @desc_short       : Prints the absolute work tree: $HOME, or the project folder.
# @usage            : _mgit_worktree <area> <repo>
# ================================================================================
function _mgit_worktree {
    local relpath_worktree
    relpath_worktree="$(_mgit_repo_setting "$1" "$2" WORKTREE)"
    # No WORKTREE: a home repository
    if [[ -n "$relpath_worktree" ]]; then
        echo "${HOME}/${relpath_worktree}"
    else
        echo "$HOME"
    fi
}

# --- _mgit_branch ---
# @desc_short       : Prints the branch of a repository (default: the area name).
# @usage            : _mgit_branch <area> <repo>
# ================================================================================
function _mgit_branch {
    local branch
    branch="$(_mgit_repo_setting "$1" "$2" BRANCH)"
    echo "${branch:-$1}"
}

# --- _mgit_is_project ---
# @desc_short       : Succeeds for project repositories (own work tree instead of $HOME).
# @usage            : _mgit_is_project <area> <repo>
# ================================================================================
function _mgit_is_project {
    [[ -n "$(_mgit_repo_setting "$1" "$2" WORKTREE)" ]]
}

# --- _mgit_repos_of_area ---
# @desc_short       : Returns all registered repositories of an area, or a validated single one.
# @usage            : _mgit_repos_of_area @return_var <area> [repo]
# ================================================================================
function _mgit_repos_of_area {
    local -n return_mgit_repos_of_area="${1#@}"
    local area="$2"
    local repo="$3"

    # A given name must be registered
    if [[ -n "$repo" ]]; then
        _mgit_require_registered "$area" "$repo" || return 1
        return_mgit_repos_of_area=("$repo")
        return 0
    fi
    mapfile -t return_mgit_repos_of_area < <(mgit_repo_names "$area")
}

# --- _mgit_require_registered ---
# @desc_short       : Fails with a message when a repository is not registered.
# @usage            : _mgit_require_registered <area> <repo>
# ================================================================================
function _mgit_require_registered {
    local area="$1"
    local repo="$2"

    # No name at all — fzf was cancelled or nothing was typed
    if [[ -z "$repo" ]]; then
        ERROR "No repository specified."
        return 1
    fi

    # The .remotes file is the registry entry
    if [[ ! -f "$(_mgit_file_list "$area" "$repo" remotes)" ]]; then
        ERROR "Unknown repository ${area}/${repo}. Known: $(mgit_repo_names "$area" | tr '\n' ' ')"
        return 1
    fi
}

# --- _mgit_validate_new ---
# @desc_short       : Fails unless the name is valid and not yet registered in the area.
# @usage            : _mgit_validate_new <area> <repo>
# ================================================================================
function _mgit_validate_new {
    local area="$1"
    local repo="$2"

    # Nothing given at all
    if [[ -z "$repo" ]]; then
        ERROR "No repository specified."
        return 1
    fi

    # Names end up in URLs and file names — keep them simple
    if [[ ! "$repo" =~ ^[A-Za-z0-9._-]+$ ]]; then
        ERROR "Invalid repository name '${repo}' — allowed: letters, digits, '.', '_', '-'."
        # A path in the name slot: options were given before the name
        [[ "$repo" == */* ]] && INFO "The repository name comes first: lpex mgit ${area} <action> <repo> [--path …]"
        return 1
    fi

    # Convention: lower case with hyphens (GitHub ignores case, shells do not)
    [[ "$repo" =~ [A-Z_] ]] && WARN "Convention is lower case with hyphens, e.g. '$(tr 'A-Z_' 'a-z-' <<< "$repo")'."

    # Refuse duplicates within the area
    if [[ -f "$(_mgit_file_list "$area" "$repo" remotes)" ]]; then
        ERROR "Repository ${area}/${repo} already exists."
        return 1
    fi
}

# --- _mgit_register ---
# @desc_short       : Writes the registry entry of a repository.
# @usage            : _mgit_register <area> <repo> <relpath_worktree> <branch> <url…>
# @parameter        : $3 | relpath_worktree | Project folder relative to $HOME, empty = home repository
# @parameter        : $4 | branch           | Kept branch, empty = area name
# ================================================================================
function _mgit_register {
    local area="$1"
    local repo="$2"
    local relpath_worktree="$3"
    local branch="$4"
    shift 4

    mkdir -p "${PATH_MGIT_DATA}/${area}"
    # One URL per line, the first one is the fetch source
    printf '%s\n' "$@" > "$(_mgit_file_list "$area" "$repo" remotes)"

    # Settings only where they differ from the defaults
    {
        [[ -n "$relpath_worktree" ]] && echo "WORKTREE=${relpath_worktree}"
        [[ -n "$branch" && "$branch" != "$area" ]] && echo "BRANCH=${branch}"
    } > "$(_mgit_file_list "$area" "$repo" conf)"
    # No settings: no file
    [[ -s "$(_mgit_file_list "$area" "$repo" conf)" ]] || rm -f "$(_mgit_file_list "$area" "$repo" conf)"

    # Home repositories start with an empty root list — filled by 'add'
    [[ -z "$relpath_worktree" ]] && : > "$(_mgit_file_list "$area" "$repo" tracked)"
    return 0
}

# --- _mgit_require_local ---
# @desc_short       : Fails with a message when a repository is not cloned on this machine.
# @usage            : _mgit_require_local <area> <repo>
# ================================================================================
function _mgit_require_local {
    local area="$1"
    local repo="$2"

    _mgit_require_registered "$area" "$repo" || return 1

    # Registered but never pulled here
    if [[ ! -d "$(_mgit_path_gitdir "$area" "$repo")" ]]; then
        ERROR "${area}/${repo} is not cloned on this machine — run: lpex mgit ${area} pull ${repo}"
        return 1
    fi
}

# --- _mgit_require_home ---
# @desc_short       : Fails for project repositories — they track their whole folder.
# @usage            : _mgit_require_home <area> <repo> <action>
# ================================================================================
function _mgit_require_home {
    local area="$1"
    local repo="$2"
    local action="$3"

    # Home repositories are the only ones with tracked roots
    _mgit_is_project "$area" "$repo" || return 0

    ERROR "'${action}' is for home repositories. ${area}/${repo} tracks its whole folder $(_mgit_worktree "$area" "$repo" | sed "s|^${HOME}|~|")."
    INFO "Keep files out with a .gitignore there; everything else is picked up by: lpex mgit ${area} push ${repo}"
    return 1
}

# --- _mgit_sync_state ---
# @desc_short       : Prints ahead/behind against the last fetched remote state.
# @usage            : _mgit_sync_state <area> <repo>
# ================================================================================
function _mgit_sync_state {
    local area="$1"
    local repo="$2"
    local counts=""
    local count_ahead count_behind

    # Left = local only, right = remote only; fails without upstream
    counts="$(_mgit_git "$area" "$repo" rev-list --left-right --count "HEAD...@{u}" 2>/dev/null)"

    # No upstream yet (never pushed)
    if [[ -z "$counts" ]]; then
        echo "no upstream"
        return 0
    fi
    read -r count_ahead count_behind <<< "$counts"
    echo "ahead ${count_ahead}, behind ${count_behind}"
}

# --- _mgit_relpath ---
# @desc_short       : Converts a path into a $HOME-relative path.
# @usage            : _mgit_relpath @return_var <path>
# @notes            : Symlinks are not resolved — git tracks the link itself.
# ================================================================================
function _mgit_relpath {
    local -n return_mgit_relpath="${1#@}"
    local path_input="$2"
    local path_absolute

    path_absolute="$(realpath -s -m -- "$path_input")"

    # Only paths below $HOME can live in a work tree that is $HOME
    if [[ "$path_absolute" != "$HOME/"* ]]; then
        ERROR "Path is not below \$HOME: ${path_absolute}"
        return 1
    fi
    return_mgit_relpath="${path_absolute#"$HOME"/}"
}

# --- _mgit_worktree_input ---
# @desc_short       : Converts a --path value into the stored WORKTREE (relative to $HOME).
# @usage            : _mgit_worktree_input @return_var <path>
# @notes            : Empty or $HOME itself → empty result = home repository.
# ================================================================================
function _mgit_worktree_input {
    local -n return_mgit_worktree_input="${1#@}"
    local path_input="$2"

    return_mgit_worktree_input=""
    # No path: home repository
    [[ -z "$path_input" ]] && return 0
    # '~', './' in $HOME or the full home path: also a home repository
    [[ "$(realpath -s -m -- "$path_input")" == "$HOME" ]] && return 0
    _mgit_relpath @return_mgit_worktree_input "$path_input"
}

# --- _mgit_collect_files ---
# @desc_short       : Lists the files a path brings in, relative to $HOME.
# @usage            : _mgit_collect_files @return_var <area> <repo> <relpath>
# @notes            : Skips mgit's git dirs, nested .git dirs and this repo's exclusions.
# ================================================================================
function _mgit_collect_files {
    local -n return_mgit_collect_files="${1#@}"
    local area="$2"
    local repo="$3"
    local relpath="$4"
    local files_found=()
    local relpaths_nested=()
    local relpath_file

    # Walk from $HOME so every printed path is already relative to it; folders holding a .git
    # are nested repositories — skipped as a whole, git could only store a link to them
    mapfile -d '' -t files_found < <(
        cd "$HOME" && find "$relpath" \( -path "$RELPATH_MGIT_REPOS" -o -name .git -o -type d -exec test -e '{}/.git' \; \) -prune \
            -o \( -type f -o -type l \) -print0
    )

    # Name the skipped nested repositories, so nothing disappears silently
    mapfile -t relpaths_nested < <(cd "$HOME" && find "$relpath" -mindepth 1 -name .git -printf '%h\n' 2>/dev/null)
    (( ${#relpaths_nested[@]} )) && WARN "Skipped nested git repositories: ${relpaths_nested[*]}"

    return_mgit_collect_files=()
    # Drop everything this repository excludes
    for relpath_file in "${files_found[@]}"; do
        _mgit_is_excluded "$area" "$repo" "$relpath_file" || return_mgit_collect_files+=("$relpath_file")
    done
}

# --- _mgit_is_excluded ---
# @desc_short       : Succeeds when a file lies in an excluded path of the repository.
# @usage            : _mgit_is_excluded <area> <repo> <relpath>
# ================================================================================
function _mgit_is_excluded {
    local area="$1"
    local repo="$2"
    local relpath="$3"
    local relpath_excluded

    # Exact match or below an excluded directory
    while IFS= read -r relpath_excluded; do
        [[ -z "$relpath_excluded" ]] && continue
        [[ "$relpath" == "$relpath_excluded" || "$relpath" == "${relpath_excluded}/"* ]] && return 0
    done < <(_mgit_read_list "$area" "$repo" excluded)
    return 1
}

# --- _mgit_pathspecs ---
# @desc_short       : Returns the pathspecs of all existing tracked roots plus exclusions.
# @usage            : _mgit_pathspecs @return_var <area> <repo>
# @notes            : Empty result = no existing root — callers must not run git then.
# ================================================================================
function _mgit_pathspecs {
    local -n return_mgit_pathspecs="${1#@}"
    local area="$2"
    local repo="$3"
    local pathspecs_exclude=()
    local relpath_entry

    return_mgit_pathspecs=()
    # Vanished roots are left to 'add -u', which stages their deletion
    while IFS= read -r relpath_entry; do
        [[ -z "$relpath_entry" ]] && continue
        [[ -e "${HOME}/${relpath_entry}" || -L "${HOME}/${relpath_entry}" ]] && return_mgit_pathspecs+=(":(literal)${relpath_entry}")
    done < <(_mgit_read_list "$area" "$repo" tracked)

    # Without a root there is nothing to exclude from
    (( ${#return_mgit_pathspecs[@]} )) || return 0

    _mgit_pathspecs_exclude @pathspecs_exclude "$area" "$repo"
    return_mgit_pathspecs+=("${pathspecs_exclude[@]}")
}

# --- _mgit_pathspecs_exclude ---
# @desc_short       : Returns the exclusion pathspecs: mgit's git dirs plus the repo's exclusions.
# @usage            : _mgit_pathspecs_exclude @return_var <area> <repo>
# ================================================================================
function _mgit_pathspecs_exclude {
    local -n return_mgit_pathspecs_exclude="${1#@}"
    local area="$2"
    local repo="$3"
    local relpath_entry

    # mgit's own git dirs never go into any repository
    return_mgit_pathspecs_exclude=(":(literal,exclude)${RELPATH_MGIT_REPOS}")
    # Paths the user removed from inside a root
    while IFS= read -r relpath_entry; do
        [[ -n "$relpath_entry" ]] && return_mgit_pathspecs_exclude+=(":(literal,exclude)${relpath_entry}")
    done < <(_mgit_read_list "$area" "$repo" excluded)
}

# --- _mgit_stage_tracked ---
# @desc_short       : Stages changes, deletions and new files below the tracked roots.
# @usage            : _mgit_stage_tracked <area> <repo>
# ================================================================================
function _mgit_stage_tracked {
    local area="$1"
    local repo="$2"
    local pathspecs=()
    local relpaths_excluded=()

    # Project repositories: the whole folder, filtered by its own .gitignore
    if _mgit_is_project "$area" "$repo"; then
        _mgit_git "$area" "$repo" add -A || { ERROR "git add -A failed in ${area}/${repo}."; return 1; }
        return 0
    fi

    # Modifications and deletions of files that are already tracked
    _mgit_git "$area" "$repo" add -u || { ERROR "git add -u failed in ${area}/${repo}."; return 1; }

    # New files below the roots — forced past the '*' exclude
    _mgit_pathspecs @pathspecs "$area" "$repo"
    # Only when at least one root still exists
    if (( ${#pathspecs[@]} )); then
        _mgit_git "$area" "$repo" add -f -- "${pathspecs[@]}" || { ERROR "git add failed in ${area}/${repo}."; return 1; }
    fi

    # Nested repositories end up as gitlinks (mode 160000) — a pointer without files, never wanted
    _mgit_drop_gitlinks "$area" "$repo"

    # Exclusions may still sit in the index from earlier commits — drop them there
    mapfile -t relpaths_excluded < <(_mgit_read_list "$area" "$repo" excluded | sed 's|^|:(literal)|')
    # Only when the repository has exclusions at all
    if (( ${#relpaths_excluded[@]} )); then
        _mgit_git "$area" "$repo" rm -r -q --cached --ignore-unmatch -- "${relpaths_excluded[@]}" >/dev/null
    fi
    return 0
}

# --- _mgit_drop_gitlinks ---
# @desc_short       : Removes gitlinks (nested repositories) from the index of a home repository.
# @usage            : _mgit_drop_gitlinks <area> <repo>
# ================================================================================
function _mgit_drop_gitlinks {
    local area="$1"
    local repo="$2"
    local relpaths_gitlink=()

    # ls-files -s prints '<mode> <hash> <stage>\t<path>' — 160000 marks a gitlink
    mapfile -t relpaths_gitlink < <(_mgit_git "$area" "$repo" ls-files -s | awk -F'\t' '$1 ~ /^160000 / {print $2}')
    # No nested repository picked up
    (( ${#relpaths_gitlink[@]} )) || return 0

    _mgit_git "$area" "$repo" rm -q --cached -- "${relpaths_gitlink[@]/#/:(literal)}"
    WARN "Skipped nested git repositories (only a link would be stored): ${relpaths_gitlink[*]}"
    INFO "Take them over as project repositories: lpex mgit ${area} import <repo> --path ~/<folder>"
}

# --- _mgit_init_local ---
# @desc_short       : Creates and configures the local git dir of a registered repository.
# @usage            : _mgit_init_local <area> <repo>
# ================================================================================
function _mgit_init_local {
    local area="$1"
    local repo="$2"
    local path_gitdir
    local urls_remote=()
    local url_remote

    local path_worktree
    local branch
    path_gitdir="$(_mgit_path_gitdir "$area" "$repo")"
    path_worktree="$(_mgit_worktree "$area" "$repo")"
    branch="$(_mgit_branch "$area" "$repo")"

    # Project folders may not exist yet on a new machine
    mkdir -p "$path_worktree"

    # Bare layout: the directory itself is the git dir, nothing is placed in the work tree
    "$CMD_GIT" init -q --bare "$path_gitdir" || { ERROR "git init failed: ${path_gitdir}"; return 1; }

    # Turn it into a regular repository with its work tree — plain 'git --git-dir=…' works then
    _mgit_git "$area" "$repo" config core.bare false
    _mgit_git "$area" "$repo" config core.worktree "$path_worktree"
    # Area name, or the branch kept from an imported repository
    _mgit_git "$area" "$repo" symbolic-ref HEAD "refs/heads/${branch}"

    # Home repositories only: $HOME is full of foreign files
    if ! _mgit_is_project "$area" "$repo"; then
        # Never list the untracked files of $HOME
        _mgit_git "$area" "$repo" config status.showUntrackedFiles no
        # Ignore everything; content only enters via 'add -f' of tracked roots
        printf '%s\n' "# Managed by lpex mgit — content is added explicitly with 'add -f'" "*" > "${path_gitdir}/info/exclude"
    fi

    # Remote: first URL fetches, every URL receives pushes
    mapfile -t urls_remote < <(grep -v '^[[:space:]]*$' "$(_mgit_file_list "$area" "$repo" remotes)")
    _mgit_git "$area" "$repo" remote add origin "${urls_remote[0]}"
    # A second server turns every URL into an explicit push URL
    if (( ${#urls_remote[@]} > 1 )); then
        for url_remote in "${urls_remote[@]}"; do
            _mgit_git "$area" "$repo" config --add remote.origin.pushurl "$url_remote"
        done
    fi
    _mgit_git "$area" "$repo" config "branch.${branch}.remote" origin
    _mgit_git "$area" "$repo" config "branch.${branch}.merge" "refs/heads/${branch}"

    # Public repositories get the secret check as pre-commit hook
    if [[ "$area" == "public" ]]; then
        printf '%s\n' "#!/bin/bash" \
            "# Generated by lpex mgit — blocks sensitive content in public/${repo}" \
            "exec lpex mgit public check ${repo}" > "${path_gitdir}/hooks/pre-commit"
        chmod +x "${path_gitdir}/hooks/pre-commit"
    fi
}

# --- _mgit_clone ---
# @desc_short       : First checkout of a registered repository into $HOME.
# @usage            : _mgit_clone <area> <repo>
# @notes            : Never overwrites differing local files without asking.
# ================================================================================
function _mgit_clone {
    local area="$1"
    local repo="$2"
    local files_differing=()
    local files_missing=()
    local files_changed=()
    local relpath_file
    local branch path_worktree

    _mgit_init_local "$area" "$repo" || return 1

    # Get the remote state
    if ! _mgit_git "$area" "$repo" fetch -q origin; then
        ERROR "Fetch failed — check SSH access. Git dir kept: $(_mgit_path_gitdir "$area" "$repo")"
        return 1
    fi

    branch="$(_mgit_branch "$area" "$repo")"
    path_worktree="$(_mgit_worktree "$area" "$repo")"

    # Point the branch at the remote state — mixed reset fills the index, the work tree stays untouched
    _mgit_git "$area" "$repo" reset -q "origin/${branch}" || { ERROR "Branch '${branch}' not found on origin."; return 1; }

    # Every file where $HOME differs from the repository
    mapfile -d '' -t files_changed < <(_mgit_git "$area" "$repo" diff --name-only -z)

    # Split into files that are simply missing and files with other content
    for relpath_file in "${files_changed[@]}"; do
        if [[ -e "${path_worktree}/${relpath_file}" || -L "${path_worktree}/${relpath_file}" ]]; then
            files_differing+=("$relpath_file")
        else
            files_missing+=("$relpath_file")
        fi
    done

    # Missing files are written without asking — nothing gets lost
    if (( ${#files_missing[@]} )); then
        _mgit_git "$area" "$repo" checkout -- "${files_missing[@]/#/:(literal)}"
        output --info "${#files_missing[@]} file(s) written to $(sed "s|^${HOME}|~|" <<< "$path_worktree")."
    fi

    # Differing files: the user decides
    if (( ${#files_differing[@]} )); then
        WARN "${#files_differing[@]} local file(s) differ from the repository:"
        printf '  %s\n' "${files_differing[@]}"
        # Yes = repository wins; No = local version stays and is uploaded by the next push
        if question "Overwrite them with the repository version?" --default-no; then
            _mgit_git "$area" "$repo" checkout -- "${files_differing[@]/#/:(literal)}"
            output --info "Local files replaced."
        else
            WARN "Local versions kept — the next 'lpex mgit ${area} push ${repo}' uploads them."
        fi
    fi

    OK "${area}/${repo} cloned."
}

# ==============================================================================
# --- Registry Lists ---
# Plain text lists in the data zone, one $HOME-relative path per line.
# ==============================================================================

# --- _mgit_read_list ---
# @desc_short       : Prints a registry list; nothing when it does not exist.
# @usage            : _mgit_read_list <area> <repo> <kind>
# ================================================================================
function _mgit_read_list {
    local file_list
    file_list="$(_mgit_file_list "$1" "$2" "$3")"
    # Missing list = empty list
    [[ -f "$file_list" ]] && grep -v '^[[:space:]]*$' "$file_list"
    return 0
}

# --- _mgit_list_contains ---
# @desc_short       : Succeeds when the list holds exactly this line.
# @usage            : _mgit_list_contains <area> <repo> <kind> <line>
# ================================================================================
function _mgit_list_contains {
    local file_list
    file_list="$(_mgit_file_list "$1" "$2" "$3")"
    grep -Fxq -- "$4" "$file_list" 2>/dev/null
}

# --- _mgit_list_add ---
# @desc_short       : Appends a line once.
# @usage            : _mgit_list_add <area> <repo> <kind> <line>
# ================================================================================
function _mgit_list_add {
    local file_list
    file_list="$(_mgit_file_list "$1" "$2" "$3")"
    # Duplicates would show up twice in 'list'
    _mgit_list_contains "$1" "$2" "$3" "$4" || echo "$4" >> "$file_list"
}

# --- _mgit_list_remove ---
# @desc_short       : Removes every occurrence of a line.
# @usage            : _mgit_list_remove <area> <repo> <kind> <line>
# ================================================================================
function _mgit_list_remove {
    local file_list
    file_list="$(_mgit_file_list "$1" "$2" "$3")"
    # Nothing to do when the line is absent
    _mgit_list_contains "$1" "$2" "$3" "$4" || return 0
    grep -Fxv -- "$4" "$file_list" > "${file_list}.tmp"
    mv "${file_list}.tmp" "$file_list"
}

# ==============================================================================
# --- Safety Checks ---
# Overlap between repositories and secret detection for the public area.
# ==============================================================================

# --- _mgit_split_foreign ---
# @desc_short       : Splits files into own ones and ones another repository of the same area tracks.
# @usage            : _mgit_split_foreign @own @foreign <area> <repo> <relpath…>
# @parameter        : @own     | Files no other repository of the area tracks
# @parameter        : @foreign | Taken files as "<relpath>  → <area>/<repo>"
# @notes            : Only the own area counts: public and private may hold the same file
# @notes            : (private as full copy). Within an area a file has exactly one owner,
# @notes            : otherwise two clones would write the same file.
# @notes            : Paths are compared absolute — home and project repos have other work trees.
# ================================================================================
function _mgit_split_foreign {
    local -n return_mgit_split_foreign_own="${1#@}"
    local -n return_mgit_split_foreign_taken="${2#@}"
    local area="$3"
    local repo="$4"
    shift 4
    local -A map_owner_by_file=()
    local area_other repo_other relpath_file path_worktree path_worktree_other owner

    # Index every file of every other cloned repository of the same area
    for area_other in "$area"; do
        while IFS= read -r repo_other; do
            # Skip the repository itself and repositories missing on this machine
            [[ "$area_other" == "$area" && "$repo_other" == "$repo" ]] && continue
            [[ -d "$(_mgit_path_gitdir "$area_other" "$repo_other")" ]] || continue
            path_worktree_other="$(_mgit_worktree "$area_other" "$repo_other")"
            while IFS= read -r -d '' relpath_file; do
                map_owner_by_file["${path_worktree_other}/${relpath_file}"]="${area_other}/${repo_other}"
            done < <(_mgit_git "$area_other" "$repo_other" ls-files -z)
        done < <(mgit_repo_names "$area_other")
    done

    path_worktree="$(_mgit_worktree "$area" "$repo")"
    return_mgit_split_foreign_own=()
    return_mgit_split_foreign_taken=()
    # Sort every file into one of the two lists
    for relpath_file in "$@"; do
        owner="${map_owner_by_file[${path_worktree}/${relpath_file}]:-}"
        if [[ -n "$owner" ]]; then
            return_mgit_split_foreign_taken+=("${relpath_file}  → ${owner}")
        else
            return_mgit_split_foreign_own+=("$relpath_file")
        fi
    done
}

# --- _mgit_check_overlap ---
# @desc_short       : Fails when a file is already tracked by another local repository.
# @usage            : _mgit_check_overlap <area> <repo> <relpath…>
# @notes            : Strict variant for the pre-commit hook; add and push skip such files instead.
# ================================================================================
function _mgit_check_overlap {
    local area="$1"
    local repo="$2"
    shift 2
    local files_own=()
    local files_taken=()

    _mgit_split_foreign @files_own @files_taken "$area" "$repo" "$@"

    # No conflicts
    (( ${#files_taken[@]} )) || return 0

    ERROR "${#files_taken[@]} file(s) already belong to another repository:"
    printf '  %s\n' "${files_taken[@]}" >&2
    INFO "Remove them there first, or exclude them here with: lpex mgit ${area} rm ${repo} --path <path>"
    return 1
}

# --- _mgit_drop_foreign ---
# @desc_short       : Unstages new files of shared folders that another repository owns.
# @usage            : _mgit_drop_foreign <area> <repo>
# ================================================================================
function _mgit_drop_foreign {
    local area="$1"
    local repo="$2"
    local files_new=()
    local files_own=()
    local files_taken=()
    local relpaths_taken=()
    local entry

    mapfile -d '' -t files_new < <(_mgit_git "$area" "$repo" diff --cached --name-only -z --diff-filter=A)
    # Nothing new: nothing can be taken
    (( ${#files_new[@]} )) || return 0

    _mgit_split_foreign @files_own @files_taken "$area" "$repo" "${files_new[@]}"
    # All new files are free
    (( ${#files_taken[@]} )) || return 0

    # Strip the owner part, keep the path as literal pathspec
    for entry in "${files_taken[@]}"; do
        relpaths_taken+=(":(literal)${entry%%  → *}")
    done
    _mgit_git "$area" "$repo" rm -q --cached -- "${relpaths_taken[@]}"
    output --info "${#files_taken[@]} new file(s) in shared folders belong to other repositories — left to them."
}

# --- _mgit_review_new_public ---
# @desc_short       : Lets the user decide which new files really become public.
# @usage            : _mgit_review_new_public <area> <repo>
# @notes            : Declined files are unstaged and excluded for good, so a private
# @notes            : repository with the same folder picks them up instead.
# ================================================================================
function _mgit_review_new_public {
    local area="$1"
    local repo="$2"
    local files_new=()
    local files_private=()
    local relpath_file

    mapfile -d '' -t files_new < <(_mgit_git "$area" "$repo" diff --cached --name-only -z --diff-filter=A)
    # No new files: nothing to decide
    (( ${#files_new[@]} )) || return 0

    WARN "${#files_new[@]} new file(s) would become PUBLIC:"
    printf '  %s\n' "${files_new[@]}"

    # Fast path: everything is meant to be public
    question "Publish all of them?" --default-no && return 0

    # Per file, or keep the whole batch private
    if question "Decide per file? (No = keep all of them private)" --default-no; then
        for relpath_file in "${files_new[@]}"; do
            question "Publish ${relpath_file}?" --default-no || files_private+=("$relpath_file")
        done
    else
        files_private=("${files_new[@]}")
    fi

    # Everything was accepted one by one
    (( ${#files_private[@]} )) || return 0

    # Out of the index and onto the exclusion list — never asked again
    _mgit_git "$area" "$repo" rm -q --cached -- "${files_private[@]/#/:(literal)}"
    for relpath_file in "${files_private[@]}"; do
        _mgit_list_add "$area" "$repo" excluded "$relpath_file"
    done
    output --info "${#files_private[@]} file(s) kept private — a private repository with this folder takes them."
}

# --- _mgit_check_public ---
# @desc_short       : Checks files for forbidden paths, secrets, size and binary content.
# @usage            : _mgit_check_public <interactive|hook> <path_base> <relpath…>
# @parameter        : $1 | mode      | interactive = ask on soft findings, hook = block them
# @parameter        : $2 | path_base | Work tree the relative paths belong to
# @notes            : Hard findings (deny paths, private keys, tokens) always block.
# ================================================================================
function _mgit_check_public {
    local mode="$1"
    local path_base="$2"
    shift 2
    local hits_hard=()
    local hits_soft=()
    local hits_large=()
    local args_grep_hard=()
    local args_grep_soft=()
    local relpath_file file_absolute pattern size_kb

    # grep -e per pattern — some patterns start with '-'
    for pattern in "${PATTERNS_SECRET_HARD[@]}"; do args_grep_hard+=(-e "$pattern"); done
    for pattern in "${PATTERNS_SECRET_SOFT[@]}"; do args_grep_soft+=(-e "$pattern"); done

    # Check every file — a path hit makes content checks pointless
    for relpath_file in "$@"; do
        # Forbidden locations and file types
        for pattern in "${PATTERNS_DENY_PATH[@]}"; do
            if [[ "$relpath_file" =~ $pattern ]]; then
                hits_hard+=("${relpath_file}  (forbidden path)")
                continue 2
            fi
        done

        file_absolute="${path_base}/${relpath_file}"
        # Links carry no content of their own; deleted files nothing to scan
        [[ -L "$file_absolute" || ! -f "$file_absolute" ]] && continue

        # Unmistakable secrets — -I skips binary files
        if grep -qIE "${args_grep_hard[@]}" -- "$file_absolute"; then
            hits_hard+=("${relpath_file}  (key or token: $(grep -oIE "${args_grep_hard[@]}" -- "$file_absolute" | head -n1 | cut -c1-12)…)")
            continue
        fi

        # Assignments that look like credentials
        if grep -qIEi "${args_grep_soft[@]}" -- "$file_absolute"; then
            hits_soft+=("${relpath_file}  (line $(grep -nIEi "${args_grep_soft[@]}" -- "$file_absolute" | head -n1 | cut -d: -f1): possible credential)")
        fi

        size_kb=$(( $(stat -c %s -- "$file_absolute") / 1024 ))
        # Large files bloat the history for good
        if (( size_kb > THRESHOLD_FILE_SIZE_KB )); then
            hits_large+=("${relpath_file}  (${size_kb} KB)")
        # Non-empty binary files cannot be reviewed in a diff
        elif [[ -s "$file_absolute" ]] && ! grep -qI '' -- "$file_absolute"; then
            hits_large+=("${relpath_file}  (binary)")
        fi
    done

    # Hard findings block in every mode
    if (( ${#hits_hard[@]} )); then
        ERROR "Blocked — sensitive content for a PUBLIC repository:"
        printf '  %s\n' "${hits_hard[@]}" >&2
        return 1
    fi

    # Hook mode cannot ask — soft findings block, size and binary only warn
    if [[ "$mode" == "hook" ]]; then
        (( ${#hits_large[@]} )) && { WARN "Large or binary files:"; printf '  %s\n' "${hits_large[@]}"; }
        # Soft findings need a human decision
        if (( ${#hits_soft[@]} )); then
            ERROR "Blocked — possible credentials:"
            printf '  %s\n' "${hits_soft[@]}" >&2
            INFO "Review interactively with: lpex mgit public push"
            return 1
        fi
        return 0
    fi

    # Interactive: soft findings need an explicit yes
    if (( ${#hits_soft[@]} )); then
        WARN "Possible credentials:"
        printf '  %s\n' "${hits_soft[@]}"
        question "Publish these files anyway?" --default-no || return 1
    fi

    # Interactive: large and binary files need an explicit yes
    if (( ${#hits_large[@]} )); then
        WARN "Large or binary files:"
        printf '  %s\n' "${hits_large[@]}"
        question "Publish these files anyway?" --default-no || return 1
    fi
    return 0
}

# ==============================================================================
# --- Server API ---
# Creates repositories on GitHub, Forgejo and GitLab. Server definitions come
# from config.conf (SERVERS_<AREA>, SERVER_<KEY>_*).
# ==============================================================================

# --- _mgit_area_servers ---
# @desc_short       : Returns the server keys configured for an area.
# @usage            : _mgit_area_servers @return_var <area>
# ================================================================================
function _mgit_area_servers {
    local -n return_mgit_area_servers="${1#@}"
    local area="$2"
    local var_servers="SERVERS_${area^^}"

    read -r -a return_mgit_area_servers <<< "${!var_servers:-}"

    # Without servers neither create nor clone can work
    if (( ! ${#return_mgit_area_servers[@]} )); then
        ERROR "No servers configured for '${area}' (${var_servers})."
        INFO "Edit the config with: lpex --config mgit"
        return 1
    fi
}

# --- _mgit_server_urls ---
# @desc_short       : Returns the SSH URL of a repository on each given server.
# @usage            : _mgit_server_urls @return_var <repo> <server…>
# ================================================================================
function _mgit_server_urls {
    local -n return_mgit_server_urls="${1#@}"
    local repo="$2"
    shift 2
    local server

    return_mgit_server_urls=()
    # Fill the URL template of every server with the repository name
    for server in "$@"; do
        # shellcheck disable=SC2059  # the template is the format string by design
        return_mgit_server_urls+=("$(printf "$(_mgit_server_var "$server" URL_SSH)" "$repo")")
    done
}

# --- mgit_server_repo_names ---
# @desc_short       : Completion for import: repositories on the area's servers not registered yet.
# @usage            : mgit_server_repo_names <area>
# @notes            : Exported for --option-cmd. Only GitHub lists public repositories without
# @notes            : a token — other servers are skipped, completion must never ask for secrets.
# ================================================================================
function mgit_server_repo_names {
    local area="$1"
    local var_servers="SERVERS_${area^^}"
    local server type_server owner name_repo

    # The bash -c subshell of --option-cmd knows no config — load it here
    source "${PATH_MGIT_DATA}/config.conf" 2>/dev/null || return 0

    # Ask every token-free server for its repositories
    for server in ${!var_servers}; do
        type_server="$(_mgit_server_var "$server" TYPE)"
        owner="$(_mgit_server_var "$server" OWNER)"
        [[ "$type_server" == "github" ]] || continue
        # Short timeout — completion must stay responsive offline
        while IFS= read -r name_repo; do
            # Registered repositories are no import candidates
            [[ -f "${PATH_MGIT_DATA}/${area}/${name_repo}.remotes" ]] || echo "$name_repo"
        done < <(/usr/bin/curl -s --max-time 3 "https://api.github.com/users/${owner}/repos?per_page=100" | /usr/bin/jq -r '.[].name' 2>/dev/null)
    done
}

# --- _mgit_server_var ---
# @desc_short       : Prints a setting of a server (SERVER_<KEY>_<NAME>).
# @usage            : _mgit_server_var <server> <name>
# ================================================================================
function _mgit_server_var {
    local server="$1"
    local name="$2"
    local var_setting="SERVER_${server^^}_${name}"
    echo "${!var_setting:-}"
}

# --- _mgit_list_remote_hosts ---
# @desc_short       : Prints the hosts of a repository's remotes, comma separated.
# @usage            : _mgit_list_remote_hosts <area> <repo>
# ================================================================================
function _mgit_list_remote_hosts {
    # 'git@host:owner/repo.git' → host
    sed -E 's|^[^@]*@([^:/]+).*|\1|' "$(_mgit_file_list "$1" "$2" remotes)" | paste -sd ',' | sed 's/,/, /g'
}

# --- _mgit_server_token ---
# @desc_short       : Returns the API token of a server (cached for this run).
# @usage            : _mgit_server_token @return_var <server>
# @notes            : TOKEN_CMD output goes through a file, never a pipe: rbw starts
# @notes            : its agent on demand, and an agent holding the pipe of a
# @notes            : $(…) would block forever.
# ================================================================================
function _mgit_server_token {
    local -n return_mgit_server_token="${1#@}"
    local server="$2"
    local cmd_token
    local file_token
    local token_value=""

    # Reuse a token fetched earlier in this run
    if [[ -n "${MGIT_TOKENS[$server]:-}" ]]; then
        return_mgit_server_token="${MGIT_TOKENS[$server]}"
        return 0
    fi

    cmd_token="$(_mgit_server_var "$server" TOKEN_CMD)"
    # Configured command: run it into a private temp file
    if [[ -n "$cmd_token" ]]; then
        file_token="$(mktemp)"
        chmod 600 "$file_token"
        # stderr is dropped: a token pasted here by mistake would otherwise be echoed by bash
        if ! bash -c "$cmd_token" > "$file_token" 2>/dev/null < /dev/null; then
            rm -f "$file_token"
            ERROR "SERVER_${server^^}_TOKEN_CMD failed. It must be a command that prints the token,"
            ERROR "e.g. rbw get '<vault entry>' --field <field> — never the token itself."
            return 1
        fi
        token_value="$(head -n1 "$file_token")"
        rm -f "$file_token"
    else
        lx input @token_value --prompt "API token for ${server}" --password || return 1
    fi

    # An empty token would only produce a confusing 401
    if [[ -z "$token_value" ]]; then
        ERROR "No API token for ${server}."
        # A working command without output: usually a missing vault field
        [[ -n "$cmd_token" ]] && INFO "SERVER_${server^^}_TOKEN_CMD printed nothing — does the vault entry/field exist?"
        return 1
    fi
    MGIT_TOKENS["$server"]="$token_value"
    return_mgit_server_token="$token_value"
}

# --- _mgit_api ---
# @desc_short       : Calls a server API; returns HTTP code and body.
# @usage            : _mgit_api @code @body <server> <method> <path> [json]
# @notes            : The auth header is passed as file — the token never shows up in ps.
# ================================================================================
function _mgit_api {
    local -n return_mgit_api_code="${1#@}"
    local -n return_mgit_api_body="${2#@}"
    local server="$3"
    local method="$4"
    local path_api="$5"
    local data_json="${6:-}"
    local type_server url_api token=""
    local file_header file_body
    local args_curl=()

    type_server="$(_mgit_server_var "$server" TYPE)"
    url_api="$(_mgit_server_var "$server" URL_API)"
    _mgit_server_token @token "$server" || return 1

    file_header="$(mktemp)"
    file_body="$(mktemp)"
    chmod 600 "$file_header"

    # Each server type expects its own auth header
    case "$type_server" in
        github)  printf '%s\n' "Authorization: Bearer ${token}" "Accept: application/vnd.github+json" > "$file_header" ;;
        forgejo) printf '%s\n' "Authorization: token ${token}" "Accept: application/json" > "$file_header" ;;
        gitlab)  printf '%s\n' "PRIVATE-TOKEN: ${token}" "Accept: application/json" > "$file_header" ;;
        *)       ERROR "Unknown server type '${type_server}' for ${server}."; rm -f "$file_header" "$file_body"; return 1 ;;
    esac

    args_curl=(-sS -o "$file_body" -w '%{http_code}' -X "$method" -H "@${file_header}")
    # Only requests with a payload send JSON
    [[ -n "$data_json" ]] && args_curl+=(-H "Content-Type: application/json" --data "$data_json")

    return_mgit_api_code="$("$CMD_CURL" "${args_curl[@]}" "${url_api}${path_api}")"
    return_mgit_api_body="$(cat "$file_body")"
    rm -f "$file_header" "$file_body"
}

# --- _mgit_server_create ---
# @desc_short       : Creates an empty repository on one server.
# @usage            : _mgit_server_create <area> <server> <repo>
# @notes            : An existing repository counts as success (re-run after a partial failure).
# ================================================================================
function _mgit_server_create {
    local area="$1"
    local server="$2"
    local repo="$3"
    local type_server owner is_org is_private path_api data_json
    local code="" body=""

    type_server="$(_mgit_server_var "$server" TYPE)"
    owner="$(_mgit_server_var "$server" OWNER)"
    is_org="$(_mgit_server_var "$server" OWNER_IS_ORG)"
    # Visibility follows the area
    [[ "$area" == "private" ]] && is_private=true || is_private=false

    # Endpoint and payload per server type
    case "$type_server" in
        github|forgejo)
            # Organisations have their own endpoint, the user account uses /user
            [[ "$is_org" == "1" ]] && path_api="/orgs/${owner}/repos" || path_api="/user/repos"
            data_json="$("$CMD_JQ" -nc --arg name "$repo" --argjson private "$is_private" '{name: $name, private: $private, auto_init: false}')" ;;
        gitlab)
            path_api="/projects"
            data_json="$("$CMD_JQ" -nc --arg name "$repo" --arg vis "$area" '{name: $name, path: $name, visibility: $vis}')" ;;
        *)
            ERROR "Unknown server type '${type_server}' for ${server}."; return 1 ;;
    esac

    _mgit_api @code @body "$server" POST "$path_api" "$data_json" || return 1

    # 201 = created; 409/422/400 with 'exist' = already there
    if [[ "$code" == "201" ]]; then
        OK "Created on ${server}."
    elif [[ "$code" =~ ^(400|409|422)$ && "$body" == *"xist"* ]]; then
        output --info "Already exists on ${server} — reused."
    else
        ERROR "Creating on ${server} failed (HTTP ${code}): $(echo "$body" | "$CMD_JQ" -r '.message // .error // .' 2>/dev/null | head -c 300)"
        return 1
    fi
}

# --- _mgit_server_set_default_branch ---
# @desc_short       : Makes the area branch the default branch on one server.
# @usage            : _mgit_server_set_default_branch <area> <server> <repo>
# ================================================================================
function _mgit_server_set_default_branch {
    local area="$1"
    local server="$2"
    local repo="$3"
    local type_server owner data_json
    local code="" body=""

    type_server="$(_mgit_server_var "$server" TYPE)"
    owner="$(_mgit_server_var "$server" OWNER)"
    data_json="$("$CMD_JQ" -nc --arg branch "$area" '{default_branch: $branch}')"

    # GitLab addresses projects by URL-encoded path and uses PUT
    case "$type_server" in
        github|forgejo) _mgit_api @code @body "$server" PATCH "/repos/${owner}/${repo}" "$data_json" || return 1 ;;
        gitlab)         _mgit_api @code @body "$server" PUT "/projects/${owner}%2F${repo}" "$data_json" || return 1 ;;
    esac

    # A failure here is cosmetic — the branch exists and works
    if [[ "$code" == "200" ]]; then
        output --info "Default branch on ${server}: ${area}"
    else
        WARN "Could not set the default branch on ${server} (HTTP ${code})."
    fi
}

# --- _mgit_server_delete ---
# @desc_short       : Deletes a repository on one server.
# @usage            : _mgit_server_delete <server> <repo>
# @notes            : A repository that is already gone counts as success.
# @notes            : GitHub tokens need 'Administration: Read and write' (fine-grained)
# @notes            : or 'delete_repo' (classic).
# ================================================================================
function _mgit_server_delete {
    local server="$1"
    local repo="$2"
    local type_server owner
    local code="" body=""

    type_server="$(_mgit_server_var "$server" TYPE)"
    owner="$(_mgit_server_var "$server" OWNER)"

    # GitLab addresses projects by URL-encoded path
    case "$type_server" in
        github|forgejo) _mgit_api @code @body "$server" DELETE "/repos/${owner}/${repo}" || return 1 ;;
        gitlab)         _mgit_api @code @body "$server" DELETE "/projects/${owner}%2F${repo}" || return 1 ;;
        *)              ERROR "Unknown server type '${type_server}' for ${server}."; return 1 ;;
    esac

    # 204/202 = deleted (GitLab deletes asynchronously); 404 = not there anymore
    if [[ "$code" =~ ^(202|204)$ ]]; then
        OK "Deleted on ${server}."
    elif [[ "$code" == "404" ]]; then
        output --info "Not found on ${server} — already deleted."
    else
        ERROR "Deleting on ${server} failed (HTTP ${code}): $(echo "$body" | "$CMD_JQ" -r '.message // .error // .' 2>/dev/null | head -c 300)"
        return 1
    fi
}

# ==============================================================================
# --- Exports ---
# --option-cmd runs in a bash -c subshell: only exported functions and
# variables exist there.
# ==============================================================================
export -f mgit_repo_names mgit_server_repo_names _mgit_server_var
export PATH_MGIT_DATA

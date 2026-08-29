#!/bin/bash
# ==============================================================================
# @meta_name        : _installer.sh
# @desc_short       : Runs ON the target device (as root). Installs staged files
#                     into the target directory with ownership inherited from the
#                     existing directory structure on the device.
# @desc_detailed    : Shipped base64-encoded inside the remote push command and
#                     executed after the payload tar was extracted to a staging
#                     directory. For every entry: missing directories are created
#                     level by level, each inheriting owner/group from its parent;
#                     files always get owner/group of their target directory.
#                     Existing directories are NEVER touched (no chown).
#
# @usage            : _installer.sh <staging_payload_dir> <target_dir>
# @param_fixed      : $1 | STAGING | Directory holding the extracted payload.
# @param_fixed      : $2 | TARGET  | Directory the payload is installed into.
#
# @exit_codes       : 0 | Success.
# @exit_codes       : 1 | Invalid arguments or at least one entry failed.
#
# @req_packages     : bash, find, stat, cp, chown
# @notes            : No LPEX dependencies — must stay standalone.
#                     File modes (+x etc.) are preserved from the mirror source.
#                     Only POSIX-level flags are used: Alpine clients ship busybox,
#                     which knows neither 'chown --reference' nor 'cp --preserve=mode'.
# ==============================================================================

# --- read_owner ---
# @desc_short  : Prints 'uid:gid' of a path, usable as a chown argument.
# @usage       : read_owner <path>
# @parameter   : $1 | path | Existing file or directory to read ownership from
# @notes       : Replaces 'chown --reference' — that flag is GNU-only and absent
#                on busybox (Alpine clients).
# ==============================================================================
function read_owner {
    local path="$1"

    # Numeric ids instead of names — the target may not know the same users.
    stat -c '%u:%g' "$path"
}

# --- ensure_dir_inherit ---
# @desc_short  : Creates a directory chain; every newly created level inherits
#                owner/group from its own parent. Existing dirs stay untouched.
# @usage       : ensure_dir_inherit <dir>
# @parameter   : $1 | dir | Absolute directory path to ensure
# ==============================================================================
function ensure_dir_inherit {
    local dir="$1"

    # Directory already exists — never modify ownership of existing dirs.
    [[ -d "$dir" ]] && return 0

    # Create the parent chain first — recursion walks up to the deepest
    # existing ancestor and creates downwards from there.
    ensure_dir_inherit "$(dirname "$dir")" || return 1

    # Create this level and inherit owner/group from its (now existing) parent.
    mkdir "$dir" || return 1
    chown "$(read_owner "$(dirname "$dir")")" "$dir"
}

# --- install_payload ---
# @desc_short  : Installs all directories and files from staging into target.
# @usage       : install_payload <staging> <target>
# @parameter   : $1 | staging | Directory holding the extracted payload
# @parameter   : $2 | target  | Directory the payload is installed into
# ==============================================================================
function install_payload {
    local staging="$1"
    local target="$2"
    local any_error=0
    local src rel dest

    # Staging must exist and contain the payload — abort otherwise.
    if [[ ! -d "$staging" ]]; then
        echo "installer: staging directory not found: ${staging}" >&2
        return 1
    fi

    # Target root itself may be missing — create it with inherited ownership.
    ensure_dir_inherit "$target" || return 1

    # 1. --- Directories ------------------------------------------------------
    # Created first so empty directories from the mirror are deployed too.
    while IFS= read -r -d '' src; do
        # Path relative to staging maps 1:1 into the target directory.
        rel="${src#"$staging"/}"
        ensure_dir_inherit "${target}/${rel}" || any_error=1
    done < <(find "$staging" -mindepth 1 -type d -print0)

    # 2. --- Files and symlinks ----------------------------------------------
    while IFS= read -r -d '' src; do
        # Path relative to staging maps 1:1 into the target directory.
        rel="${src#"$staging"/}"
        dest="${target}/${rel}"

        # Parent may be missing when the payload is a single file.
        ensure_dir_inherit "$(dirname "$dest")" || { any_error=1; continue; }

        # Remove first, then copy — replaces existing entries like tar did and
        # detaches a running binary from its inode instead of writing into it.
        rm -f "$dest"

        # -P keeps symlinks as links, -p carries the file mode (+x) over from the
        # mirror. Both are POSIX flags — busybox understands them, unlike
        # '--preserve=mode' and '--remove-destination'.
        cp -P -p "$src" "$dest" || { any_error=1; continue; }

        # File always gets owner/group of its target directory (-h: never
        # follow symlinks — adjust the link itself).
        chown -h "$(read_owner "$(dirname "$dest")")" "$dest" || any_error=1
    done < <(find "$staging" -mindepth 1 \( -type f -o -type l \) -print0)

    return "$any_error"
}

install_payload "$@"

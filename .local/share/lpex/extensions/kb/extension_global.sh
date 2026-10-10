#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 0.1.0
# @meta_date        : 2026-10-04
#
# @desc_short       : Shared paths and helpers of the knowledge base.
# @desc_detailed    : Every entry is a Markdown file <topic>/<name>.md in the data
# @desc_detailed    : zone. The kb_* functions are exported: fzf runs its preview
# @desc_detailed    : and key bindings in fresh bash processes that only see
# @desc_detailed    : exported functions and variables.
#
# @req_packages     : fzf, rg, glow, bat, nvim, wl-copy
# @notes            : No secrets in entries — they reference the Vaultwarden entry instead.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# Wrapped in a function with declare -g: the completion engine sources this file
# inside a function, plain declarations would turn local there.
# ==============================================================================
function _kb_globals {
    declare -g PATH_KB_DATA="${PATH_EXTENSION_DATA:-$HOME/.local/state/lpex/data/kb}"  # one <topic>/<name>.md per entry
    declare -g CMD_KB_EDITOR="nvim"                     # editor for new and existing entries
    declare -g CMD_KB_VIEWER="glow"                     # Markdown renderer for preview and view
    declare -g CMD_KB_PAGER="bat"                       # raw view with line highlight (search hits)
    declare -g CMD_KB_CLIPBOARD="wl-copy"               # ctrl-y in the browser
    declare -g PATTERN_KB_NAME='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'   # topic/name, exactly one slash
}
_kb_globals

# ==============================================================================
# --- Entry Helpers ---
# Name handling shared by the actions and the fzf bindings.
# ==============================================================================

# --- kb_entries ---
# @desc_short       : Prints all entry names (topic/name), sorted.
# @usage            : kb_entries
# ================================================================================
function kb_entries {
    # Empty knowledge base: nothing to list, no error
    [[ -d "$PATH_KB_DATA" ]] || return 0
    # Relative paths without the .md suffix are the entry names
    (cd "$PATH_KB_DATA" && find . -type f -name '*.md' -printf '%P\n' | sed 's/\.md$//' | sort)
}

# --- kb_complete_first ---
# @desc_short       : Completion list of the first position: actions plus entries with titles.
# @usage            : kb_complete_first
# ================================================================================
function kb_complete_first {
    local name_entry

    # Actions inline — arrays cannot be exported into the --option-cmd subshell
    printf '%s\n' \
        "new # Create an entry (topic/name)" \
        "edit # Edit an entry in nvim" \
        "rm # Delete an entry" \
        "search # Full text search" \
        "list # All entries with titles"
    # Entries carry their title as description
    while IFS= read -r name_entry; do
        echo "${name_entry} # $(kb_title "$name_entry")"
    done < <(kb_entries)
}

# --- kb_normalize ---
# @desc_short       : Prints an entry name without a trailing .md (search hits carry it).
# @usage            : kb_normalize <name>
# ================================================================================
function kb_normalize {
    local name_entry="$1"
    echo "${name_entry%.md}"
}

# --- kb_file ---
# @desc_short       : Prints the file path of an entry.
# @usage            : kb_file <name>
# ================================================================================
function kb_file {
    local name_entry
    name_entry="$(kb_normalize "$1")"
    echo "${PATH_KB_DATA}/${name_entry}.md"
}

# --- kb_title ---
# @desc_short       : Prints the first Markdown heading of an entry.
# @usage            : kb_title <name>
# ================================================================================
function kb_title {
    local file_entry
    file_entry="$(kb_file "$1")"
    # First '# ' line without the hash; empty when there is none
    sed -n 's/^# //p' "$file_entry" 2>/dev/null | head -n1
}

# --- _kb_validate_name ---
# @desc_short       : Fails with a message unless the name has the form topic/name.
# @usage            : _kb_validate_name <name>
# ================================================================================
function _kb_validate_name {
    local name_entry="$1"

    # Exactly one slash keeps every entry inside a topic folder — and apart from the actions
    if [[ ! "$name_entry" =~ $PATTERN_KB_NAME ]]; then
        ERROR "Invalid entry name '${name_entry}' — use topic/name (letters, digits, '.', '_', '-')."
        return 1
    fi
}

# --- _kb_require_entry ---
# @desc_short       : Fails with similar names as hint when an entry does not exist.
# @usage            : _kb_require_entry <name>
# ================================================================================
function _kb_require_entry {
    local name_entry="$1"
    local names_similar=""

    # Existing entry: nothing to report
    [[ -f "$(kb_file "$name_entry")" ]] && return 0

    names_similar="$(kb_entries | grep -iF -- "${name_entry##*/}" | head -n5 | paste -sd ' ')"
    ERROR "No entry '${name_entry}'."
    # Typos are the usual cause — offer what comes close
    [[ -n "$names_similar" ]] && INFO "Similar: ${names_similar}"
    return 1
}

# ==============================================================================
# --- fzf Bindings ---
# Called by fzf's preview and execute bindings in separate bash processes.
# ==============================================================================

# --- kb_preview ---
# @desc_short       : Preview pane: rendered Markdown, or raw text with the hit highlighted.
# @usage            : kb_preview <name> [line]
# ================================================================================
function kb_preview {
    local file_entry
    local number_line="$2"
    file_entry="$(kb_file "$1")"

    # Search mode delivers a line number — glow cannot highlight lines, bat can
    if [[ "$number_line" =~ ^[0-9]+$ ]]; then
        "$CMD_KB_PAGER" --color always --style numbers --highlight-line "$number_line" \
            --line-range "$(( number_line > 5 ? number_line - 5 : 1 )):" "$file_entry"
    else
        CLICOLOR_FORCE=1 "$CMD_KB_VIEWER" -s dark -w "${FZF_PREVIEW_COLUMNS:-80}" "$file_entry"
    fi
}

# --- kb_view ---
# @desc_short       : Full-screen view of an entry in glow's pager.
# @usage            : kb_view <name>
# ================================================================================
function kb_view {
    local count_columns

    # glow wraps at 80 columns (glow.yml) — use the full terminal width instead
    count_columns=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
    "$CMD_KB_VIEWER" -s dark -w "$count_columns" -p "$(kb_file "$1")"
}

# --- kb_open_editor ---
# @desc_short       : Opens an entry in the editor, optionally at a line.
# @usage            : kb_open_editor <name> [line]
# ================================================================================
function kb_open_editor {
    local file_entry
    local number_line="$2"
    file_entry="$(kb_file "$1")"

    # Jump to the search hit when there is one
    if [[ "$number_line" =~ ^[0-9]+$ ]]; then
        "$CMD_KB_EDITOR" "+${number_line}" "$file_entry"
    else
        "$CMD_KB_EDITOR" "$file_entry"
    fi
}

# --- kb_copy ---
# @desc_short       : Copies the content of an entry to the clipboard.
# @usage            : kb_copy <name>
# ================================================================================
function kb_copy {
    "$CMD_KB_CLIPBOARD" < "$(kb_file "$1")"
}

# ==============================================================================
# --- Exports ---
# --option-cmd and fzf both run in fresh bash processes: only exported
# functions and variables exist there.
# ==============================================================================
export -f kb_entries kb_complete_first kb_normalize kb_file kb_title
export -f kb_preview kb_view kb_open_editor kb_copy
export PATH_KB_DATA CMD_KB_EDITOR CMD_KB_VIEWER CMD_KB_PAGER CMD_KB_CLIPBOARD

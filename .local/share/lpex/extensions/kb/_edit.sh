#!/bin/bash
# ==============================================================================
# @meta_name        : _edit.sh
# @desc_short       : Creates and edits entries in nvim.
# ==============================================================================

# --- _kb_action_edit ---
# @desc_short       : Opens an entry in nvim; missing entries start from a template.
# @usage            : _kb_action_edit <name> <new|edit>
# @parameter        : $1 | name | topic/name
# @parameter        : $2 | mode | new = ask for a name when missing; edit = open the browser then
# @notes            : A new entry left unchanged in the editor is discarded again.
# ================================================================================
function _kb_action_edit {
    local name_entry
    local mode="$2"
    local file_entry
    local content_template
    name_entry="$(kb_normalize "$1")"

    # 1. --- Resolve the name ---------------
    if [[ -z "$name_entry" ]]; then
        # 'edit' without a name: pick one in the browser
        if [[ "$mode" == "edit" ]]; then
            _kb_action_browse
            return
        fi
        lx input @name_entry --prompt "New entry (topic/name)" || return 1
    fi

    _kb_validate_name "$name_entry" || return 1
    file_entry="$(kb_file "$name_entry")"

    # 2. --- Template for new entries ---------------
    if [[ ! -f "$file_entry" ]]; then
        content_template="$(_kb_template "$name_entry")"
        mkdir -p "$(dirname "$file_entry")"
        printf '%s\n' "$content_template" > "$file_entry"
    # 'new' on an existing entry: say so, then edit it anyway
    elif [[ "$mode" == "new" ]]; then
        WARN "Entry '${name_entry}' exists — opening it."
    fi

    # 3. --- Edit ---------------
    # Cursor on the last line — the template ends with an empty line for the content
    "$CMD_KB_EDITOR" "+" "$file_entry"

    # Nothing written into a fresh template: no empty entry left behind
    if [[ -n "$content_template" && "$(cat "$file_entry")" == "$content_template" ]]; then
        rm -f "$file_entry"
        rmdir --ignore-fail-on-non-empty "$(dirname "$file_entry")"
        INFO "Unchanged template discarded."
        return 0
    fi
    OK "Saved: ${name_entry}"
}

# --- _kb_template ---
# @desc_short       : Prints the template of a new entry.
# @usage            : _kb_template <name>
# @notes            : The title is the name part with '-'/'_' as spaces, first letter upper case.
# ================================================================================
function _kb_template {
    local name_entry="$1"
    local title="${name_entry##*/}"

    title="${title//[-_]/ }"
    printf '%s\n' "# ${title^}" "" "created: $(date +%Y-%m-%d)" ""
}

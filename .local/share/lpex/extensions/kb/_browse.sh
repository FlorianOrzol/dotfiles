#!/bin/bash
# ==============================================================================
# @meta_name        : _browse.sh
# @desc_short       : fzf browser over all entries — list and full text mode.
# ==============================================================================

# --- _kb_action_browse ---
# @desc_short       : Opens the browser; with a query it starts in full text mode.
# @usage            : _kb_action_browse [query]
# @parameter        : $1 | query | Search text — starts the full text mode with it
# @notes            : Bindings run in bash (SHELL is overridden) and only use the
# @notes            : exported kb_* functions. In full text mode every line is
# @notes            : '<topic/name>.md:<line>:<text>' — field 1 is the entry,
# @notes            : field 2 the line; kb_normalize strips the .md.
# ================================================================================
function _kb_action_browse {
    local query="$1"
    local cmd_list="kb_entries"
    local cmd_lines
    local bind_start

    # Every line of every entry, so fzf can fuzzy match across all content
    cmd_lines="cd $(printf '%q' "$PATH_KB_DATA") && rg --line-number --with-filename --color always --glob '*.md' '^'"

    # Empty knowledge base: the browser would only show an empty list
    if [[ -z "$(kb_entries)" ]]; then
        INFO "The knowledge base is empty. Create the first entry with: kb new <topic/name>"
        return 0
    fi

    # A query from 'kb search' starts in full text mode, otherwise in the entry list
    if [[ -n "$query" ]]; then
        bind_start="start:reload($cmd_lines)"
    else
        bind_start="start:reload($cmd_list)"
    fi

    SHELL=/bin/bash fzf --ansi --reverse --no-sort --exact --delimiter : \
        --query "$query" \
        --preview-window '70%' \
        --preview 'kb_preview {1} {2}' \
        --bind "$bind_start" \
        --bind "ctrl-f:reload($cmd_list)" \
        --bind "ctrl-d:reload($cmd_lines)" \
        --bind "enter:execute(kb_view {1})" \
        --bind "ctrl-e:execute(kb_open_editor {1} {2})+refresh-preview" \
        --bind "ctrl-n:execute(lpex kb new {q})+reload($cmd_list)" \
        --bind "ctrl-x:execute(lpex kb rm {1})+reload($cmd_list)" \
        --bind "ctrl-y:execute-silent(kb_copy {1})" \
        --header "knowledge base — ${PATH_KB_DATA/#$HOME/\~}
enter view · ctrl+ (e)dit (n)ew=query (x)delete (y)ank (d)fulltext (f)iles
======================="
}

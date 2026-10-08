# ==============================================================================
# @meta_name        : f.fish
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 2.0.0
# @meta_date        : 2026-08-18
#
# @desc_short       : fzf based finder with mode specific previews.
# @desc_detailed    : '--code' browses source files with syntax coloured previews.
# @desc_detailed    : '--docs' browses documents and renders them as images right
# @desc_detailed    : inside the preview pane (ranger style), searches their full
# @desc_detailed    : text through rga - which reaches into PDF, odt, docx and
# @desc_detailed    : epub - and opens the selection in the browser.
#
# @req_packages     : fzf, fd, rg, rga, bat, kitty (kitten icat), poppler,
#                     libreoffice, glow, google-chrome-stable
#
# @param_fixed      : $1 | MODE | --code or --docs
# @param_opt        : $2 | PATH | Search root for --docs (default: current directory)
#
# @notes            : Preview rendering lives in _f_preview_doc.fish. It has to be
#                     its own autoload file because fzf spawns a fresh shell for
#                     every preview call, where local helpers are not visible.
# ==============================================================================

# ==============================================================================
# --- User Configuration ---
# Adjust these to match your environment.
# ==============================================================================

set -q CMD_BROWSER; or set -g CMD_BROWSER google-chrome-stable   # Opens the selected document on <enter>
set -q CMD_EDITOR_TUI; or set -g CMD_EDITOR_TUI nvim             # Opens the selection in the terminal editor

# File types offered by '--docs'. Extend this list to widen the search.
set -q LIST_DOC_EXTENSIONS; or set -g LIST_DOC_EXTENSIONS \
    pdf md txt rtf odt doc docx epub djvu csv ods xls xlsx odp ppt pptx \
    png jpg jpeg gif webp tif tiff svg

# ==============================================================================
# --- Completions ---
# Registered on autoload, so they become active once 'f' has been used.
# ==============================================================================

complete -c f -f
complete -c f -f -n '__fish_use_subcommand' -a '--code' -d 'search code files'
complete -c f -f -n '__fish_use_subcommand' -a '--docs' -d 'search documents, image preview'
complete -c f -F -n '__fish_seen_subcommand_from --docs' -d 'search root'

# --- f ---
# @desc_short       : Mode dispatcher for the fzf finders.
# @usage            : f <mode> [path]
#
# @modes            : --code  : source files, syntax coloured preview
#                     --docs  : documents, rendered image preview
# @options          : [path]  : search root, only honoured by --docs
# ==============================================================================
function f --description 'my custom fzf finders'
    switch "$argv[1]"
        case '--code'
            _f_code
        case '--docs'
            _f_docs $argv[2]
        case '*'
            _f_usage
    end
end

# --- _f_code ---
# @desc_short       : Browses source files with a syntax coloured preview.
# @usage            : _f_code
# ==============================================================================
function _f_code --description 'fzf browser for source files'
    # Plain file listing - the mode fzf starts in
    set -l cmd_list 'fd -H -t f --color always'

    # Every line of every file, so fzf itself can fuzzy match across all content.
    # The pattern stays single quoted here; the original nested double quotes made
    # fish concatenate the strings and hand '^' to rg unquoted.
    set -l cmd_lines 'rg --hidden \'^\' --with-filename --line-number --color always'

    # Field 2 only exists after ctrl-d. In the plain file list it is empty, and
    # 'bat --highlight-line \'\'' aborts with "Empty line range" - so both actions
    # have to branch on whether a line number is actually present.
    set -l cmd_pager "if test -n {2}; bat --force-colorization --paging=always --highlight-line {2} {1}; else; bat --force-colorization --paging=always {1}; end"
    set -l cmd_edit "if test -n {2}; $CMD_EDITOR_TUI +{2} {1}; else; $CMD_EDITOR_TUI {1}; end"

    fzf --ansi --reverse --no-sort --exact --delimiter : \
        --preview-window '70%' \
        --preview '_f_preview_doc {1} {2}' \
        --bind "start:reload($cmd_list)+change-preview(_f_preview_doc {})" \
        --bind "ctrl-f:reload($cmd_list)+change-preview(_f_preview_doc {})+change-preview-window(70%)" \
        --bind "ctrl-d:reload($cmd_lines)+change-preview(_f_preview_doc {1} {2})+change-preview-window(70%)" \
        --bind "ctrl-n:execute($cmd_edit)" \
        --bind "enter:execute($cmd_pager)" \
        --bind "ctrl-b:execute($cmd_pager)" \
        --header "$(pwd)
ctrl+ (f)iles (d)etailed (n)vim (b)at=(enter)
=======================
"
end

# --- _f_docs ---
# @desc_short       : Browses documents with an in-terminal image preview.
# @usage            : _f_docs [path]
# @parameter        : $1 | path | Search root, defaults to the current directory.
# ==============================================================================
function _f_docs --description 'fzf browser for documents with image preview'
    set -l path_search $argv[1]

    # No search root given - stay in the current directory, same as --code does
    test -n "$path_search"; or set path_search '.'

    # Bail out early instead of letting fd fail inside the fzf reload
    if not test -d "$path_search"
        echo "f --docs: no such directory: $path_search" >&2
        return 1
    end

    # Quote the path once here so spaces survive the trip through the fzf bind string
    set -l path_search_quoted (string escape -- "$path_search")

    # Expand the extension list into the repeated '-e <ext>' sequence fd expects
    set -l args_extensions
    for file_extension in $LIST_DOC_EXTENSIONS
        set -a args_extensions -e $file_extension
    end

    # Plain document listing - the mode fzf starts in
    set -l cmd_list "fd -H -t f $args_extensions . $path_search_quoted --color always"

    # Fulltext search driven by the current fzf query. Unlike --code this cannot
    # dump every line up front: rga has to extract text from every PDF and office
    # file first, which is far too slow to run on an empty query.
    set -l cmd_search "if test -n {q}; rga --hidden --line-number --with-filename --color always --smart-case --no-messages -- {q} $path_search_quoted; else; $cmd_list; end"

    fzf --ansi --reverse --no-sort --exact --delimiter : \
        --preview-window '70%' \
        --preview '_f_preview_doc {}' \
        --bind "start:reload($cmd_list)+change-preview(_f_preview_doc {})" \
        --bind "ctrl-f:reload($cmd_list)+change-preview(_f_preview_doc {})" \
        --bind "ctrl-d:reload($cmd_search)+change-preview(_f_preview_doc {1} {2} {3})" \
        --bind "ctrl-n:execute($CMD_EDITOR_TUI {1})" \
        --bind "enter:execute-silent($CMD_BROWSER {1} &)" \
        --bind "ctrl-b:execute-silent($CMD_BROWSER {1} &)" \
        --header "$path_search
ctrl+ (f)iles (d)ocsearch=type first (n)vim (b)rowser=(enter)
=======================
"
end

# --- _f_usage ---
# @desc_short       : Prints the mode overview when no valid mode was given.
# @usage            : _f_usage
# ==============================================================================
function _f_usage --description 'usage overview for f'
    echo "f - fzf finders"
    echo
    echo "  f --code          source files, syntax coloured preview"
    echo "  f --docs [path]   documents, rendered image preview"
    echo
    echo "  ctrl-f  back to the file list"
    echo "  ctrl-d  content search   (--code: all lines / --docs: type a query first)"
    echo "  ctrl-n  open in $CMD_EDITOR_TUI"
    echo "  ctrl-b  open like <enter>"
    echo "  enter   --code: bat pager / --docs: $CMD_BROWSER"
end

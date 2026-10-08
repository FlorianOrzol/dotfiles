# ==============================================================================
# @meta_name        : _f_preview_doc.fish
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 1.0.0
# @meta_date        : 2026-08-18
#
# @desc_short       : fzf preview dispatcher for the 'f --docs' document browser.
# @desc_detailed    : Renders documents as images directly inside the terminal
# @desc_detailed    : preview pane (ranger style) via the kitty graphics protocol.
# @desc_detailed    : Page based formats are rasterised with pdftoppm, office
# @desc_detailed    : formats are routed through libreoffice first. Plain text
# @desc_detailed    : formats stay textual on purpose - an image of text loses
# @desc_detailed    : syntax colouring and is not scrollable.
#
# @req_packages     : kitty (kitten icat), poppler (pdftoppm/pdftotext),
#                     libreoffice, bat, glow
#
# @param_fixed      : $1 | FILE | Path of the file to preview.
# @param_opt        : $2 | LINE | Line number of a grep hit (text formats only).
# @param_opt        : $3 | PAGE | rga page field, e.g. "Page 3" (page formats only).
#
# @notes            : Rendered pages are cached under PATH_CACHE_PREVIEW, keyed by
#                     path + mtime + page, so revisiting a file is instant.
# ==============================================================================

# ==============================================================================
# --- User Configuration ---
# Adjust these to match your environment. Every value can be overridden from
# config.fish, the 'set -q' guard keeps a pre-existing definition intact.
# ==============================================================================

# Fall back to the XDG default when the cache root is not exported by the session
set -q XDG_CACHE_HOME; or set -g XDG_CACHE_HOME "$HOME/.cache"

set -q PATH_CACHE_PREVIEW; or set -g PATH_CACHE_PREVIEW "$XDG_CACHE_HOME/f_preview"   # Rendered page images and intermediate PDFs
set -q RENDER_PREVIEW_DPI;  or set -g RENDER_PREVIEW_DPI 150                          # Rasterisation density - higher = sharper but slower
set -q TIMEOUT_PREVIEW_CONVERT; or set -g TIMEOUT_PREVIEW_CONVERT 45                  # Hard stop for libreoffice, keeps fzf responsive
set -q RETENTION_CACHE_DAYS; or set -g RETENTION_CACHE_DAYS 14                        # Renders older than this are dropped on the next cache miss

# ==============================================================================
# --- Script Internals ---
# External tools as CMD_ variables so they can be swapped in one place.
# ==============================================================================

set -q CMD_ICAT;        or set -g CMD_ICAT        kitten
set -q CMD_PDFTOPPM;    or set -g CMD_PDFTOPPM    pdftoppm
set -q CMD_PDFTOTEXT;   or set -g CMD_PDFTOTEXT   pdftotext
set -q CMD_LIBREOFFICE; or set -g CMD_LIBREOFFICE libreoffice
set -q CMD_BAT;         or set -g CMD_BAT         bat
set -q CMD_GLOW;        or set -g CMD_GLOW        glow
set -q CMD_DJVUTXT;     or set -g CMD_DJVUTXT     djvutxt
set -q CMD_PANDOC;      or set -g CMD_PANDOC      pandoc

# --- _f_preview_doc ---
# @desc_short       : Dispatches a file to the matching preview renderer.
# @usage            : _f_preview_doc <file> [line] [page_field]
# @parameter        : $1 | file       | Path of the file to preview.
# @parameter        : $2 | line       | Grep hit line number, may be empty.
# @parameter        : $3 | page_field | rga page marker "Page N", may be empty.
# ==============================================================================
function _f_preview_doc --description 'fzf preview dispatcher for f --docs'
    set -l file_path $argv[1]
    set -l line_number $argv[2]
    set -l page_field $argv[3]

    # Nothing selected yet (empty result list) - stay silent instead of erroring
    if test -z "$file_path"
        return 0
    end

    # Guard against stale entries: the list may outlive the file it points to
    if not test -f "$file_path"
        echo "no such file: $file_path"
        return 1
    end

    # rga marks PDF hits as "Page N" in the third field - use it as the render target
    set -l page_number 1
    if string match -qr '^Page [0-9]+$' -- "$page_field"
        set page_number (string replace -r '^Page ' '' -- "$page_field")
    end

    # Lowercase the extension so .PDF and .pdf take the same branch
    set -l file_extension (string lower -- (path extension -- "$file_path" | string replace -r '^\.' ''))

    switch $file_extension
        # Native page formats: rasterise the requested page directly
        case pdf
            _f_render_page "$file_path" $page_number

        # Already an image: hand it to icat untouched, no conversion needed
        case png jpg jpeg gif webp bmp tif tiff svg avif
            _f_show_image "$file_path"

        # Office formats: no page renderer of their own, detour via libreoffice
        case odt doc docx rtf epub ods xls xlsx odp ppt pptx odg
            _f_render_page "$file_path" $page_number

        # DjVu carries no PDF pipeline here - fall back to its text layer
        case djvu
            $CMD_DJVUTXT "$file_path" 2>/dev/null | $CMD_BAT --color always -pp -l txt

        # Markdown reads far better rendered as styled text than as a picture.
        # A grep hit needs the raw source though - glow cannot highlight a line.
        case md markdown
            if string match -qr '^[0-9]+$' -- "$line_number"
                _f_show_text "$file_path" "$line_number"
            else
                $CMD_GLOW -w $FZF_PREVIEW_COLUMNS "$file_path" 2>/dev/null
            end

        # Plain text: keep syntax colouring and highlight the grep hit if we got one
        case '*'
            _f_show_text "$file_path" "$line_number"
    end
end

# --- _f_render_page ---
# @desc_short       : Renders one page of a document as PNG and shows it inline.
# @usage            : _f_render_page <file> <page_number>
# @parameter        : $1 | file        | Source document (pdf or office format).
# @parameter        : $2 | page_number | 1-based page to rasterise.
# ==============================================================================
function _f_render_page --description 'rasterise one document page and display it'
    set -l file_path $argv[1]
    set -l page_number $argv[2]

    # Ensure the cache root exists before anything tries to write into it
    mkdir -p "$PATH_CACHE_PREVIEW"

    # Key the cache on path + mtime + page so an edited file re-renders automatically
    set -l file_mtime (stat -c %Y -- "$file_path" 2>/dev/null)
    set -l cache_key (echo "$file_path|$file_mtime|$page_number|$RENDER_PREVIEW_DPI" | sha256sum | string sub -l 32)
    set -l cache_base "$PATH_CACHE_PREVIEW/$cache_key"

    # Reuse a previous render instead of paying the conversion cost again
    if test -f "$cache_base.png"
        _f_show_image "$cache_base.png"
        return 0
    end

    # Cache miss from here on - a good moment to drop stale renders
    _f_prune_cache

    # Office formats need a PDF intermediate, PDFs are already the input we want
    set -l file_source "$file_path"
    if not string match -qi 'pdf' -- (path extension -- "$file_path" | string replace -r '^\.' '')
        set file_source (_f_convert_to_pdf "$file_path" "$cache_key")

        # Conversion failed or timed out - degrade to a text preview rather than a blank pane
        if test -z "$file_source"
            echo "preview: conversion failed, falling back to text"
            _f_show_text_fallback "$file_path"
            return 1
        end
    end

    # -singlefile drops the page suffix so the output path is predictable
    $CMD_PDFTOPPM -png -singlefile -r $RENDER_PREVIEW_DPI \
        -f $page_number -l $page_number \
        "$file_source" "$cache_base" 2>/dev/null

    # Rasterisation can still fail on damaged files - show the text layer instead of nothing
    if not test -f "$cache_base.png"
        echo "preview: could not render page $page_number, falling back to text"
        _f_show_text_fallback "$file_path"
        return 1
    end

    _f_show_image "$cache_base.png"
end

# --- _f_convert_to_pdf ---
# @desc_short       : Converts an office document to PDF inside the preview cache.
# @usage            : _f_convert_to_pdf <file> <cache_key>
# @parameter        : $1 | file      | Source document.
# @parameter        : $2 | cache_key | Hash used as the cache subdirectory name.
# @notes            : Echoes the resulting PDF path, or nothing on failure.
# ==============================================================================
function _f_convert_to_pdf --description 'convert an office document to PDF for preview'
    set -l file_path $argv[1]
    set -l cache_key $argv[2]

    set -l path_outdir "$PATH_CACHE_PREVIEW/$cache_key.d"
    mkdir -p "$path_outdir"

    # A private profile keeps this from clashing with an interactive libreoffice session
    timeout $TIMEOUT_PREVIEW_CONVERT $CMD_LIBREOFFICE \
        -env:UserInstallation="file://$PATH_CACHE_PREVIEW/lo_profile" \
        --headless --convert-to pdf --outdir "$path_outdir" "$file_path" >/dev/null 2>&1

    # libreoffice names the output after the input basename - pick up whatever landed there
    set -l list_converted "$path_outdir"/*.pdf
    if test -f "$list_converted[1]"
        echo "$list_converted[1]"
    end
end

# --- _f_show_image ---
# @desc_short       : Draws an image into the fzf preview pane via the kitty protocol.
# @usage            : _f_show_image <image_file>
# @parameter        : $1 | image_file | Path of the image to display.
# ==============================================================================
function _f_show_image --description 'display an image inside the fzf preview pane'
    set -l file_image $argv[1]

    # Unicode placeholders let fzf keep track of the image when the pane redraws;
    # --place pins it to the pane geometry fzf exports for this preview call.
    $CMD_ICAT icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
        --place "$FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES"@0x0 \
        "$file_image" 2>/dev/null
end

# --- _f_show_text ---
# @desc_short       : Shows a text file with syntax colouring, centred on a hit line.
# @usage            : _f_show_text <file> [line]
# @parameter        : $1 | file | Path of the text file.
# @parameter        : $2 | line | Line number to highlight, may be empty.
# ==============================================================================
function _f_show_text --description 'text preview with optional grep hit highlighting'
    set -l file_path $argv[1]
    set -l line_number $argv[2]

    # No hit line: plain top-of-file preview
    if not string match -qr '^[0-9]+$' -- "$line_number"
        $CMD_BAT --color always --style plain "$file_path" 2>/dev/null
        return 0
    end

    # Scroll so the hit sits roughly in the middle of the pane instead of at the top
    set -l line_offset (math "max(1, $line_number - $FZF_PREVIEW_LINES / 2)")
    $CMD_BAT --color always --style plain \
        --highlight-line $line_number \
        --line-range "$line_offset:" \
        "$file_path" 2>/dev/null
end

# --- _f_prune_cache ---
# @desc_short       : Drops preview renders that have not been touched recently.
# @usage            : _f_prune_cache
# @notes            : Called on cache misses only. Without it the cache grows
#                     without bound - each rendered page costs a few hundred KB.
# ==============================================================================
function _f_prune_cache --description 'remove stale preview renders'
    # -mtime is measured in whole days, so a value below 1 would delete instantly
    if test $RETENTION_CACHE_DAYS -lt 1
        return 0
    end

    # Rendered pages and the libreoffice intermediates share the same retention
    find "$PATH_CACHE_PREVIEW" -maxdepth 1 -name '*.png' -mtime +$RETENTION_CACHE_DAYS -delete 2>/dev/null
    find "$PATH_CACHE_PREVIEW" -maxdepth 1 -name '*.d' -type d -mtime +$RETENTION_CACHE_DAYS -exec rm -rf {} + 2>/dev/null
end

# --- _f_show_text_fallback ---
# @desc_short       : Extracts a readable text layer when image rendering failed.
# @usage            : _f_show_text_fallback <file>
# @parameter        : $1 | file | Document that could not be rendered as an image.
# @notes            : Piping a binary format straight into bat would fill the pane
#                     with garbage, so each format gets its own extractor.
# ==============================================================================
function _f_show_text_fallback --description 'text extraction fallback for failed renders'
    set -l file_path $argv[1]

    # Lowercase the extension so .PDF and .pdf take the same branch
    set -l file_extension (string lower -- (path extension -- "$file_path" | string replace -r '^\.' ''))

    switch $file_extension
        # poppler reads the embedded text layer even when rasterisation fails
        case pdf
            $CMD_PDFTOTEXT -layout "$file_path" - 2>/dev/null | $CMD_BAT --color always --style plain -l txt

        # Binary office containers - pandoc unpacks them without libreoffice
        case odt docx epub rtf fb2
            $CMD_PANDOC --to=plain --wrap=none -- "$file_path" 2>/dev/null | $CMD_BAT --color always --style plain -l txt

        # Legacy or spreadsheet formats have no reliable extractor here - state that plainly
        case doc ods xls xlsx odp ppt pptx odg
            echo "preview: no text extractor for .$file_extension"

        # Anything else is plain enough for bat to handle directly
        case '*'
            _f_show_text "$file_path" ""
    end
end

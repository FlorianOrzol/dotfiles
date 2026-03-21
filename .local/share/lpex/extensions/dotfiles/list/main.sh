#!/bin/bash
function extension_start() {
    output --section "LPEX Dotfiles Tracker"
    
    show_lists() {
        local type="$1"
        local tracker="$PATH_EXTENSION_DATA/${type}_tracked.txt"
        local excluded="$PATH_EXTENSION_DATA/${type}_excluded.txt"
        
        output --info "=== ${type^} Tracking List ==="
        if [[ -f "$tracker" ]] && [[ -s "$tracker" ]]; then
            cat "$tracker" | sed 's/^/  [+] /'
        else
            echo "  (Empty)"
        fi
        
        if [[ -f "$excluded" ]] && [[ -s "$excluded" ]]; then
            echo "  --- Excluded Exceptions ---"
            cat "$excluded" | sed 's/^/  [-] /'
        fi
        echo ""
    }

    show_lists "public"
    show_lists "private"
}

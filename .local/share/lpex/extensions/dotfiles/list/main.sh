#!/bin/bash
function extension_start() {
    lx output --section "LPEX DOTFILES TRACKER"
    
    show_lists() {
        local type="$1"
        local tracker="$PATH_EXTENSION_DATA/${type}_tracked.txt"
        local excluded="$PATH_EXTENSION_DATA/${type}_excluded.txt"
        
        output --subsection "${type^^} TRACKING LIST"
        if [[ -f "$tracker" ]] && [[ -s "$tracker" ]]; then
#            cat "$tracker" | sed 's/^/  [+] /'
			OUTPUT "${FONT_GREEN} [+] $tracker"
        else
            echo "  (Empty)"
        fi
        
        if [[ -f "$excluded" ]] && [[ -s "$excluded" ]]; then
			OUTPUT "${FONT_RED}  [-] $excluded"
        fi
    }

	SUBSECTION_WIDTH=70
    show_lists "public"
    show_lists "private"
}

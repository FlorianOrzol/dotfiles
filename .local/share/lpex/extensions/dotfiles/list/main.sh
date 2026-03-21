#!/bin/bash
function extension_start() {
    output --section "LPEX Dotfiles Tracker"
    
    local pub_file="$PATH_EXTENSION_DATA/public_tracked.txt"
    local priv_file="$PATH_EXTENSION_DATA/private_tracked.txt"
    
    output --info "=== Public Tracking List ==="
    if [[ -f "$pub_file" ]]; then
        cat "$pub_file" | sed 's/^/  - /'
    else
        echo "  (Empty)"
    fi
    
    echo ""
    output --info "=== Private Tracking List ==="
    if [[ -f "$priv_file" ]]; then
        cat "$priv_file" | sed 's/^/  - /'
    else
        echo "  (Empty)"
    fi
    
    echo ""
    output --warn "Note: These are the top-level paths LPEX scans."
    output --warn "To see every single individual file known to Git, run:"
    output --warn "  git --git-dir=~/.git-dotfiles/public --work-tree=~ ls-files"
}

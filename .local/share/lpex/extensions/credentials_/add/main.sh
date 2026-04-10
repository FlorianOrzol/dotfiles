#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials add
# Creates a new Bitwarden entry using piped input to bypass the editor.
# ==============================================================================

function extension_start() {
    # Ensure daemon is ready
    _unlock_rbw
    
    local name="${ARG_NAME:-}"
    local value="${ARG_VALUE:-}"
    local type="${ARG_TYPE:-password}"
    
    # Validation
    [[ -z "$name" ]] && { output --error "Name is required."; exit 1; }
    [[ -z "$value" ]] && { output --error "Value is required."; exit 1; }

    output --info "Adding entry '$name' to credentials vault..."

    # Logic: rbw add expects username as argument. 
    # It reads Password from line 1 of stdin and Notes from line 2 onwards.
    if [[ "$type" == "password" ]]; then
        # Store in password field
        printf "%s\n" "$value" | rbw add "$name" "$name"
    else
        # Store in notes field (Line 1 empty, Line 2 contains value)
        printf "\n%s" "$value" | rbw add "$name" "$name"
    fi

    if [[ $? -eq 0 ]]; then
        output --ok "Successfully added '$name'."
    else
        output --error "Failed to add entry."
        exit 1
    fi
}

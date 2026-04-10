#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: credentials init
# Defines parameters for initializing the secondary credentials account.
# ==============================================================================

function arguments() {
    # Request credentials with interactive fzf support
    arg_value @email \
        --description "Secondary Bitwarden account email" \
        --fzf

    arg_value @url \
        --description "Vaultwarden server URL (e.g., https://vault.example.com)" \
        --fzf

    arg_value @pass_entry \
        --description "Name of the password entry in 'pass' (default: vaultwarden-credentials)" \
        --fzf
}

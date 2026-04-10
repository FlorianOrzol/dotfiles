#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials init
# Performs isolated initialization and registration for the 'credentials' profile.
# ==============================================================================

function extension_start() {
    # Store provided arguments
    local email="${ARG_EMAIL:-}"
    local url="${ARG_URL:-}"
    local pentry="${ARG_PASS_ENTRY:-}"

    # Enforce email requirement
    if [[ -z "$email" ]]; then
        lx input --prompt "Enter your Bitwarden Email (for 'credentials'):" @email
    fi
    [[ -z "$email" ]] && { output --error "Email is required."; exit 1; }

    # Handle URL formatting
    if [[ -z "$url" ]]; then
        lx input --prompt "Enter Vaultwarden URL (e.g., https://passwords.domain.link):" @url
    fi
    if [[ -n "$url" ]] && [[ "$url" != http* ]]; then
        url="https://$url"
    fi

    # Handle pass entry name
    if [[ -z "$pentry" ]]; then
        lx input --prompt "Enter the password name in 'pass' (default: vaultwarden-credentials):" @pentry
    fi
    [[ -z "$pentry" ]] && pentry="vaultwarden-credentials"

    output --info "Initializing Bitwarden 'credentials' profile in isolated storage..."

    # Persist values to extension config via framework DB helper
    lx db --file "config.conf" --table "config" --insert --data "CRED_EMAIL" "$email" "CRED_BASE_URL" "$url" "CRED_PASS_ENTRY" "$pentry" 2>/dev/null || true
    
    # Ensure current session knows the new pass entry name
    CRED_PASS_ENTRY="$pentry"

    # Apply configuration to the isolated rbw instance
    _rbw config set email "$email"
    if [[ -n "$url" ]]; then
        _rbw config set base_url "$url"
    fi

    # API Key Support
    if lx question "Do you want to configure Bitwarden API Client ID and Secret for this profile?"; then
        local client_id client_secret
        lx input --prompt "Enter Client ID:" @client_id
        lx input --prompt "Enter Client Secret:" --password @client_secret
        
        if [[ -n "$client_id" ]] && [[ -n "$client_secret" ]]; then
            _rbw config set client_id "$client_id"
            _rbw config set client_secret "$client_secret"
            output --ok "API keys configured."
        fi
    fi

    # Retrieve master password and register
    local vault_pass
    # Get master password helper uses the global CRED_PASS_ENTRY we just set
    vault_pass=$(_get_master_password) || { output --error "Pass entry '$pentry' not found."; exit 1; }

    output --info "Registering device with server: ${url:-api.bitwarden.com}..."
    if ! printf "%s" "$vault_pass" | _rbw register; then
        output --error "Registration failed. Check your credentials and URL."
        exit 1
    fi

    output --ok "Bitwarden 'credentials' profile successfully initialized."
}

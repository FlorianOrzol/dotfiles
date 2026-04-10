#!/bin/bash
# ==============================================================================
# --- Extension Global Library: Credentials ---
# Provides isolated rbw functions for the 'credentials' module.
# ==============================================================================

# Force rbw to use a dedicated profile for the secondary credentials account.
export RBW_PROFILE="credentials"

# ------------------------------------------------------------------------------
# Feature: Initialization Check
# Returns 0 if the isolated configuration exists, 1 otherwise.
# ------------------------------------------------------------------------------
function _is_initialized() {
    # Check for the existence of the private config file for credentials
    [[ -f "${PATH_EXTENSION_DATA}/config/rbw/config.json" ]] && return 0
    return 1
}

# ------------------------------------------------------------------------------
# Feature: RBW Wrapper
# Executes rbw with a localized configuration path for total isolation.
# ------------------------------------------------------------------------------
function _rbw() {
    # Ensure the private config directory exists
    mkdir -p "$PATH_EXTENSION_DATA/config"
    
    # Run rbw with a temporary XDG_CONFIG_HOME.
    # We explicitly UNSET RBW_PROFILE to use 'default' inside this private folder.
    XDG_CONFIG_HOME="$PATH_EXTENSION_DATA/config" RBW_PROFILE="" command rbw "$@"
}

# ------------------------------------------------------------------------------
# Feature: Master Password Retrieval
# Safely retrieves the vault password for the credentials module from 'pass'.
# ------------------------------------------------------------------------------
function _get_master_password() {
    # Determine the pass entry name from configuration or default
    local cmd_pass="${CRED_PASS_ENTRY:-vaultwarden-credentials}"

    # Explicitly set GPG_TTY for pinentry popups
    export GPG_TTY=$(tty)
    
    local vault_pass
    # Retrieve the password from the pass store
    if ! vault_pass=$(pass show "$cmd_pass" 2>/dev/null | head -n 1); then
        return 1
    fi
    
    echo "$vault_pass"
}

# ------------------------------------------------------------------------------
# Feature: RBW Unlocking
# Performs unlocking using the localized configuration path.
# ------------------------------------------------------------------------------
function _unlock_rbw() {
    if _rbw unlocked &> /dev/null; then
        return 0
    fi

    local vault_pass
    vault_pass=$(_get_master_password) || { output --error "Failed to get password from pass."; exit 1; }

    expect <<EOF &> /dev/null
log_user 0
spawn XDG_CONFIG_HOME="${PATH_EXTENSION_DATA}/config" RBW_PROFILE="" rbw unlock
expect "Master Password:"
send "${vault_pass}\r"
expect eof
EOF
    
    _rbw sync &> /dev/null
}

# ------------------------------------------------------------------------------
# Feature: Command Check
# ------------------------------------------------------------------------------
function _check_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        output --error "Error: The required command '$cmd' is not installed."
        exit 1 
    fi
}

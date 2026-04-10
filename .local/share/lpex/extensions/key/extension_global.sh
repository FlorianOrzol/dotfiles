#!/bin/bash
# ==============================================================================
# --- Extension Global Library: Key ---
# Provides isolated rbw functions and robust initialization logic.
# ==============================================================================

# ------------------------------------------------------------------------------
# Feature: Initialization Check
# ------------------------------------------------------------------------------
function _is_initialized() {
    _rbw config show &>/dev/null && return 0 || return 1
}



# ------------------------------------------------------------------------------
# Feature: RBW Wrapper
# ------------------------------------------------------------------------------
function _rbw() {
    RBW_PROFILE="$PASS_NAME_VAULTWARDEN" rbw "$@"
}

# ------------------------------------------------------------------------------
# Feature: Master Password Retrieval
# ------------------------------------------------------------------------------
function _get_master_password() {
	local -n return_ref=$1
    
	return_ref=$(pass show "$PASS_NAME_VAULTWARDEN" 2>/dev/null) \
		|| { output --error "Pass entry '$PASS_NAME_VAULTWARDEN' not found."; exit 1; }
}

# ------------------------------------------------------------------------------
# Feature: RBW Unlocking (Bulletproof Version)
# ------------------------------------------------------------------------------
function _unlock_rbw() {
	# if unlocked, return success immediately
    _rbw unlocked &>/dev/null && return 0

    local vault_pass
	_get_master_password vault_pass


    export VAULT_PASS="$vault_pass"
	export RBW_PROFILE="$PASS_NAME_VAULTWARDEN"
    # Ensure RBW_PROFILE is passed explicitly to the spawned process
    expect <<EOF
log_user 0
spawn rbw unlock
expect "Master Password"
send "\$env(VAULT_PASS)\r"
expect eof
EOF
    unset VAULT_PASS # Clear sensitive variable
    
	_rbw unlocked || { output --error "Failed to unlock rbw vault. Please check your credentials." exit 1; }
}


# ------------------------------------------------------------------------------
# Feature: sync RBW Vault
# ------------------------------------------------------------------------------
function _sync_rbw() {
	_rbw sync &>/dev/null || output --error "Failed to sync rbw vault."
}

# ------------------------------------------------------------------------------
# Feature: Initialization Logic
# ------------------------------------------------------------------------------
function _do_init() {

	# Validate url format and prepend https if missing
    if [[ -n "$ARG_URL" ]] && [[ "$ARG_URL" != http* ]]; then
        ARG_URL="https://$ARG_URL"
    fi

#    lx db --file "config.conf" --table "config" --insert --data "KEY_EMAIL" "$email" "KEY_BASE_URL" "$url" "KEY_PASS_ENTRY" "$pentry" 2>/dev/null || true
	output --info "Saving configuration to file"
	echo "" > $FILE_EXTENSION_CONFIG
	echo "PASS_NAME_VAULTWARDEN=\"$ARG_PASS_ENTRY\"" >> $FILE_EXTENSION_CONFIG
	echo "EMAIL_VAULTWARDEN=\"$ARG_EMAIL\"" >> $FILE_EXTENSION_CONFIG
	echo "URL_VAULTWARDEN=\"$ARG_URL\"" >> $FILE_EXTENSION_CONFIG
	source $FILE_EXTENSION_CONFIG

	output --info "Set rbw configuration for profile '$THIS_RBW_PROOFILE'..."
    _rbw config set email "$EMAIL_VAULTWARDEN"
    _rbw config set base_url "$URL_VAULTWARDEN"

	# search for existing pass entry
	if ! pass show "$PASS_NAME_VAULTWARDEN" &>/dev/null; then
		output --error "Pass entry '$PASS_NAME_VAULTWARDEN' not found. Please create it with the master password for your Vaultwarden account."
		if question "Do you want to create a new pass entry named '$PASS_NAME_VAULTWARDEN' now?"; then
			pass insert "$PASS_NAME_VAULTWARDEN" || output --error "Failed to create pass entry." || exit 1
			output --ok "Pass entry '$PASS_NAME_VAULTWARDEN' created successfully."
		else
			output --error "Initialization aborted. Please create the required pass entry and try again."
			exit 1
		fi
	fi

	# unlock to verify credentials and sync
	_unlock_rbw 

	
    output --ok "Initialization successful."
}

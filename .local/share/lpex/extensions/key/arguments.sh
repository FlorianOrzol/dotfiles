#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: key
# ==============================================================================

function arguments() {
    # Define init flag
	arg_flag @_ --description "Use RBW_PROFILE=<config-key> to get auto-completion. Where config-key should be the equal to PASS_NAME_VAULTWARDEN in config"
    arg_flag @init --description "Initialize this isolated Bitwarden account"
    arg_value @email --description "Account email" --depends-on "ARG_INIT"
    arg_value @url --description "Vaultwarden URL" --depends-on "ARG_INIT"
    arg_value @pass_entry --description "Pass entry name" --depends-on "ARG_INIT"

	
    # Autocompletion of rbw if initialized and unlocked
	# ... unlocking if is not done
	if _is_initialized; then
		_unlock_rbw 
		arg_wrap "rbw"
	fi

}

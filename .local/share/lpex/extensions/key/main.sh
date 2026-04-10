#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: key
# Acts as a transparent wrapper for 'rbw' or triggers initialization.
# ==============================================================================
# TODO: config.json anpassen (automatisch werte pinentry: pinentry-curses und lock_timeout... setzen) 
# TODO: Hauptprogramm get-arguments globals und configs laden
function extension_start() {

	echo "Starting Vaultwarden Extension..."
    # Check for initialization request
	(( ARG_INIT )) && _do_init && return 0

    # Perform unlocking
	_unlock_rbw
	_sync_rbw
    
    # Execute the wrapped rbw command
    # LPEX provides the original arguments in an array if defined, 
    # but for a transparent wrapper we can use the remaining unparsed args.
    _rbw "${ARG_RBW[@]}" "$@"
}

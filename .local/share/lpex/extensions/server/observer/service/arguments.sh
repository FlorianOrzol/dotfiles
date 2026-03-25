#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server observer service
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    
    arg_flag @start   --description "Start the service"
    arg_flag @stop    --description "Stop the service"
    arg_flag @restart --description "Restart the service"
    arg_flag @enable  --description "Enable the service at boot"
    
    arg_value @name --description "Name of the systemd service (e.g. check-clients)"
}

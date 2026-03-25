#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server observer logs
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    arg_value @name --description "Name of the systemd service (e.g. check-clients)"
}

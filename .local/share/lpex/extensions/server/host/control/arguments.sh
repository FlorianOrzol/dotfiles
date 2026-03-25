#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server host control
# ==============================================================================

function arguments() {
    arg_value @node   --description "Proxmox Node Name (e.g. pve102)"
    arg_flag  @start  --description "Wake the physical node (WOL/Shelly)"
    arg_flag  @stop   --description "Send an ACPI soft shutdown signal"
}

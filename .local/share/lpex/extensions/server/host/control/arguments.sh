#!/bin/bash
# ==============================================================================
# @meta_module      : server host control
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host control'.
#
# @arg_values       : --node    | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --start   | Wake via Wake-On-LAN
# @arg_flags        : --stop    | ACPI graceful shutdown via SSH
# @arg_flags        : --restart | ACPI reboot via SSH
# ==============================================================================
function arguments() {
    arg_value @node   --description "Proxmox Node Name (e.g. pve102)" --option "pve101" --option "pve102" --option "pve103"
    arg_flag  @start  --description "Wake the physical node via Wake-On-LAN (WOL)"
    arg_flag  @stop   --description "Send an ACPI soft shutdown signal"
    arg_flag  @restart --description "Send an ACPI reboot signal"
}

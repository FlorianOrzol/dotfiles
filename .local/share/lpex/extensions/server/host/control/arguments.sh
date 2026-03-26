#!/bin/bash
function arguments() {
    arg_value @node   --description "Proxmox Node Name (e.g. pve102)" --option "pve101" --option "pve102" --option "pve103"
    arg_flag  @start  --description "Wake the physical node via Wake-On-LAN (WOL)"
    arg_flag  @stop   --description "Send an ACPI soft shutdown signal"
    arg_flag  @restart --description "Send an ACPI reboot signal"
}

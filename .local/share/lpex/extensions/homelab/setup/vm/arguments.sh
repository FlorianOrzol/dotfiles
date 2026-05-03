#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines the CLI arguments for the setup vm submodule.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for VM creation and management.
# @usage            : lpex homelab setup vm <id> [action] [options]
#
# @direct           : <id>         VM VMID (arg_direct)
# @actions          : --create | --delete | --edit | --show-config
# @options          : --name | --host | --iso | --ram | --balloon | --cpu
#                     --max-cpu | --disk | --storage | --ip-address | --gateway
#                     --bridge | --machine | --bios | --os-type | --agent
#                     --autostart | --ha | --auto-backup
# ==============================================================================
function arguments {
    # 1. --- ID (positional) ---------------
    arg_direct @id --description "VM VMID (e.g. 1111)" --fzf \
        --option-cmd "cat '$FILE_VM_LIVE' 2>/dev/null"

    # 2. --- Actions ---------------
    # ------ Mutually exclusive by nature, validated in main.sh.

    arg_flag @create      --description "Create a new VM"
    arg_flag @delete      --description "Delete the VM"
    arg_flag @edit        --description "Edit VM configuration"
    arg_flag @show_config --description "Show current VM configuration"

    # 3. --- Options ---------------
    # ------ Used with --create and --edit. Validated in main.sh.

    arg_value @name --description "Name / hostname of the VM"

    arg_value @host --description "Target host (ID from homelab_conf.db)" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @iso --description "Boot-ISO (Dateiname auf dem Ziel-Host)"

    arg_value @ram     --description "RAM in MB (required)"
    arg_value @cpu     --description "Number of vCPUs (Default: 2)"
    arg_value @max_cpu --description "CPU limit in percent (Default: 100)"
    arg_value @disk    --description "Primary disk size in GB (required; edit: only increase)"

    arg_value @balloon --description "Memory ballooning (Default: yes)" --fzf \
        --option "yes # Ballooning aktiv" \
        --option "no  # Ballooning deaktiviert"

    arg_value @storage --description "Storage pool" --fzf \
        --option "fastpool # Schneller ZFS-Pool" \
        --option "bigpool  # Großer ZFS-Pool"

    arg_value @ip_address --description "IP address with prefix (e.g. 192.168.1.111/24)"
    arg_value @gateway    --description "Default gateway"
    arg_value @bridge     --description "Network bridge (Default: vmbr0)"

    arg_value @machine --description "Machine type (Default: q35)" --fzf \
        --option "q35    # Moderner PCIe-Bus (empfohlen)" \
        --option "i440fx # Älterer PCI-Bus"

    arg_value @bios --description "BIOS type (Default: ovmf)" --fzf \
        --option "ovmf    # UEFI (empfohlen)" \
        --option "seabios # Legacy BIOS"

    arg_value @os_type --description "OS type hint for Proxmox (Default: l26)" --fzf \
        --option "l26   # Linux kernel 2.6+" \
        --option "win11 # Windows 11"

    arg_value @agent --description "QEMU Guest Agent (Default: yes)" --fzf \
        --option "yes # Guest Agent aktiv" \
        --option "no  # Guest Agent deaktiviert"

    arg_value @autostart --description "Autostart on host boot (Default: off)" --fzf \
        --option "on  # Autostart aktiv" \
        --option "off # Autostart deaktiviert"

    arg_value @ha --description "HA configuration (Default: no)" --fzf \
        --option "yes # Zur HA-Liste hinzufügen" \
        --option "no  # Kein HA"

    arg_value @auto_backup --description "Backup-Job-ID des Hosts zuweisen"
}

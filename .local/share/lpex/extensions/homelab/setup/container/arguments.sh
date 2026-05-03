#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines the CLI arguments for the setup container submodule.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for container creation and management.
# @usage            : lpex homelab setup container <id> [action] [options]
#
# @direct           : <id>         Container VMID (arg_direct)
# @actions          : --create | --delete | --edit | --show-config
# @options          : --name | --host | --template | --ram | --swap | --cpu
#                     --max-cpu | --disk | --storage | --binds | --ip-address
#                     --gateway | --bridge | --privileged | --ssh | --features
#                     --autostart | --ha | --auto-backup
# ==============================================================================
function arguments {
    # 1. --- ID (positional) ---------------
    arg_direct @id --description "Container VMID (e.g. 1111)" --fzf \
        --option-cmd "cat '$FILE_CONTAINER_LIVE' 2>/dev/null"

    # 2. --- Actions ---------------
    # ------ Mutually exclusive by nature, validated in main.sh.

    arg_flag @create      --description "Create a new container"
    arg_flag @delete      --description "Delete the container"
    arg_flag @edit        --description "Edit container configuration"
    arg_flag @show_config --description "Show current container configuration"

    arg_value @conf_push --description "Container in conf_targets des Hosts ein-/austragen (on|off)" --fzf \
        --option "on  # In conf_targets aufnehmen (homelab.conf wird gepusht)" \
        --option "off # Aus conf_targets entfernen (homelab.conf wird gepusht)"

    # 3. --- Options ---------------
    # ------ Used with --create and --edit. Validated in main.sh.

    arg_value @name --description "Hostname of the container"

    arg_value @host --description "Target host (ID from homelab_conf.db)" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @template --description "LXC template (e.g. debian-12, ubuntu-22.04)" --fzf \
        --option "debian-12" \
        --option "ubuntu-22.04" \
        --option "ubuntu-24.04"

    arg_value @ram      --description "RAM in MB (required)"
    arg_value @swap     --description "Swap in MB (Default: = RAM)"
    arg_value @cpu      --description "Number of CPU cores (Default: 2)"
    arg_value @max_cpu  --description "CPU limit in percent (Default: 100)"
    arg_value @disk     --description "Root disk size in GB (required; edit: only increase)"

    arg_value @storage --description "Storage pool for root disk" --fzf \
        --option "fastpool # Schneller ZFS-Pool" \
        --option "bigpool  # Großer ZFS-Pool"

    arg_value @binds --description "Bind mount: /host/path:/ct/path (repeatable)" --multi \
        --option "/zfs-pool-fast/data # Fast Pool" \
        --option "/zfs-pool-big/data  # Big Pool"

    arg_value @ip_address --description "IP address with prefix (e.g. 192.168.1.111/24)"
    arg_value @gateway    --description "Default gateway"
    arg_value @bridge     --description "Network bridge (Default: vmbr0)"

    arg_flag @privileged --description "Create privileged container (Default: unprivileged)"

    arg_value @ssh --description "SSH configuration in container (Default: user)" --fzf \
        --option "user # SSH aktiv, nur User-Login, kein Root (Standard)" \
        --option "key  # SSH aktiv, nur Key-Login (kein Passwort)" \
        --option "root # SSH aktiv + Root-Login erlaubt (PermitRootLogin yes)" \
        --option "off  # SSH deaktiviert"

    arg_value @features --description "LXC feature to enable (repeatable)" --multi \
        --option "nesting # Docker-in-LXC u.ä." \
        --option "keyctl  # Keyring-Zugriff" \
        --option "fuse    # FUSE-Mounts"

    arg_value @autostart --description "Autostart on host boot (Default: off)" --fzf \
        --option "on  # Autostart aktiv" \
        --option "off # Autostart deaktiviert"

    arg_value @ha --description "HA configuration (Default: no)" --fzf \
        --option "yes # Zur HA-Liste hinzufügen" \
        --option "no  # Kein HA"

    arg_value @auto_backup --description "Backup-Job-ID des Hosts zuweisen"
}

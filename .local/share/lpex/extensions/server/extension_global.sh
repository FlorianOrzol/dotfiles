#!/bin/bash
# ==============================================================================
# --- Extension Global Library ---
# Auto-loaded by LPEX. Contains global helper functions utilized by all 
# server submodules for database access, host resolution, and payload management.
# ==============================================================================

# ------------------------------------------------------------------------------
# Feature: Strict Configuration Validation
# Ensures that critical configuration variables exist before proceeding.
# Prevents cascading failures caused by typos in config.conf.
# ------------------------------------------------------------------------------
function enforce_config_var() {
    local var_name="$1"
    # Indirect expansion: gets the value of the variable named in $var_name
    local var_value="${!var_name}"
    
    if [[ -z "$var_value" ]]; then
        output --error "Fatal Configuration Error: Variable '$var_name' is missing or empty!"
        output --warn "Please run 'lpex --config server' to define it."
        exit 1 # Hard exit to prevent any further script execution
    fi
}

# ------------------------------------------------------------------------------
# Feature: Active Proxmox Host Resolution
# Retrieves the primary Proxmox host IP, ensuring it's valid.
# ------------------------------------------------------------------------------
function get_active_host() {
    enforce_config_var "IP_ACTIVE_PVE"
    echo "$IP_ACTIVE_PVE"
}

# ------------------------------------------------------------------------------
# Feature: Dynamic Container Completion
# Generates the command string for FZF to fetch live LXC containers.
# ------------------------------------------------------------------------------
function get_lxc_completion_cmd() {
    local ip="${IP_ACTIVE_PVE}"
    local user="${USER_PVE:-root}"
    # Fails silently (2>/dev/null) to prevent breaking the completion menu if the host is down
    echo "ssh -q -o ConnectTimeout=1 $user@$ip 'pct list | awk '\''NR>1 {print \$1 \" # \" \$3 \" - \" \$2}'\''' 2>/dev/null"
}

# ------------------------------------------------------------------------------
# Feature: Observer IP Resolution
# Maps a logical node name (e.g. 'pi1') to its specific IP address defined in config.
# ------------------------------------------------------------------------------
function get_observer_ip() {
    local node="${1^^}" # Convert input to uppercase (pi1 -> PI1)
    # Strip any "OBSERVER-" prefix the user might have typed
    node="${node#OBSERVER-}"
    
    local var_name="IP_OBSERVER_$node"
    local ip="${!var_name}"
    
    if [[ -z "$ip" ]]; then
        output --error "Unknown observer node: $1. Variable '$var_name' not found in config."
        exit 1
    fi
    echo "$ip"
}

# ------------------------------------------------------------------------------
# Feature: Tree Mirror Directory Generation
# ------------------------------------------------------------------------------
function ensure_fs_dir() {
    local target_type="${1:-global}"
    local target_id="${2}"
    local dir_path="$PATH_EXTENSION_DATA/$target_type"
    
    if [[ "$target_type" != "global" ]]; then
        dir_path="$dir_path/$target_id/filesystem"
    else
        dir_path="$dir_path/container/filesystem"
    fi
    mkdir -p "$dir_path" 2>/dev/null
    echo "$dir_path"
}

function init_command_db() {
    local schema="id INTEGER PRIMARY KEY, target_type TEXT, target_id TEXT, alias TEXT, command TEXT, UNIQUE(target_type, target_id, alias)"
    lx db --file "commands.db" --table "device_commands" --create-table --cols "$schema" >/dev/null 2>&1 || true
}

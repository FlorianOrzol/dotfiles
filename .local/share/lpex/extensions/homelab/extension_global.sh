#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @desc_short       : Shared device-list and SSH helpers for all homelab submodules.
# ==============================================================================

# ==============================================================================
# --- Desktop Share-Path Correction ---
# config.conf is identical to homelab.conf (single source of truth) and defines
# MOUNT_POOL_FAST for the nodes (/mnt/pool_fast/data). The desktop autofs mounts
# the share root directly at /mnt/pool_fast — rebase all derived share paths so
# every submodule reads the correct NFS locations without local hardcodes.
# ==============================================================================
# Rebase only when the node path is absent but the desktop mount exists
if [[ ! -d "$MOUNT_POOL_FAST" && -d "/mnt/pool_fast/homelab_monitoring" ]]; then
    MOUNT_POOL_FAST="/mnt/pool_fast"                                            # desktop share root (autofs)
    MOUNT_POOL_BIG="/mnt/pool_big"                                              # desktop big pool root (autofs)
    PATH_SHARE_MONITORING="${MOUNT_POOL_FAST}/homelab_monitoring"               # rebased monitoring base path
    PATH_SHARE_LOGS="${PATH_SHARE_MONITORING}/logs"                             # rebased log path
    PATH_SHARE_OUTPUTS="${PATH_SHARE_MONITORING}/outputs"                       # rebased outputs path
    PATH_SHARE_STATE="${PATH_SHARE_MONITORING}/state"                           # rebased state path
    PATH_SHARE_METRICS="${PATH_SHARE_MONITORING}/metrics"                       # rebased metrics path
    FILE_SHARE_OBSERVER_HEARTBEAT_JSON="${PATH_SHARE_STATE}/observer_heartbeat.json"  # rebased heartbeat file
    FILE_CONTAINER_LIVE="${PATH_SHARE_STATE}/hosts/host_1/lxc-live.txt"         # rebased CT live file
    FILE_VM_LIVE="${PATH_SHARE_STATE}/hosts/host_1/vm-live.txt"                 # rebased VM live file
fi

# --- get_hosts ---
# @desc_short  : Prints all configured hosts as "name # ip", one per line.
# @usage       : get_hosts
# @notes       : Iterates DEVICENAME_HOST_N / IP_HOST_N scalars from config — no array needed.
#                Works inside bash -c subshells when exported (see export block below).
# ==============================================================================
function get_hosts {
    local i=1 host_var ip_var host ip
    while true; do
        host_var="DEVICENAME_HOST_${i}"
        host="${!host_var}"
        [[ -z "$host" ]] && break              # no more hosts defined in config
        ip_var="IP_HOST_${i}"
        ip="${!ip_var}"
        printf '%s # %s\n' "$host" "$ip"
        (( i++ ))
    done
}

# --- get_observers ---
# @desc_short  : Prints all configured observers as "name # ip (role)", one per line.
# @usage       : get_observers
# @notes       : Iterates DEVICENAME_OBSERVER_N / IP_OBSERVER_N scalars from config.
#                Works inside bash -c subshells when exported (see export block below).
# ==============================================================================
function get_observers {
    local i=1 obs_var ip_var observer ip role
    while true; do
        obs_var="DEVICENAME_OBSERVER_${i}"
        observer="${!obs_var}"
        [[ -z "$observer" ]] && break          # no more observers defined in config
        ip_var="IP_OBSERVER_${i}"
        ip="${!ip_var}"
        [[ "$observer" == "$OBSERVER_PRIMARY" ]] && role="primary" || role="standby"
        printf '%s # %s (%s)\n' "$observer" "$ip" "$role"
        (( i++ ))
    done
}

# --- get_nodes ---
# @desc_short  : Prints all physical nodes (hosts + observers) as "name # ip", one per line.
# @usage       : get_nodes
# ==============================================================================
function get_nodes {
    get_hosts                               # all hosts
    get_observers                           # all observers
}

# --- get_containers ---
# @desc_short  : Prints live container names from NFS share, one per line.
# @usage       : get_containers
# ==============================================================================
function get_containers {
    share_mounted             || return 0   # skip silently if NFS share not mounted
    [[ -f "$FILE_CONTAINER_LIVE" ]] || return 0   # skip if live file missing
    cat "$FILE_CONTAINER_LIVE"              # emit container names from live file
}

# --- get_ha_clients ---
# @desc_short  : Prints HA-managed containers in boot order as "id # name - status", one per line.
# @usage       : get_ha_clients
# @notes       : Joins the ha_clients boot order list (NFS, synced by the HA watcher)
#                with the leader's live file — falls back to the bare ID when the
#                live file has no entry (e.g. CT currently on another host).
# ==============================================================================
function get_ha_clients {
    share_mounted || return 0               # skip silently if NFS share not mounted
    local file_list="${PATH_SHARE_STATE}/ha_clients"
    [[ -f "$file_list" ]] || return 0       # skip if HA list not synced to share yet

    local id live_line
    # Walk the list in boot order and enrich each ID with name/status from the live file
    while IFS= read -r id || [[ -n "$id" ]]; do
        id="${id%%#*}"                      # strip optional '# comment' suffix
        id="${id//[[:space:]]/}"            # trim all whitespace around the ID
        [[ -z "$id" ]] && continue          # skip blank/comment-only lines

        live_line=""
        # Match the ID against the live file ("<id> # <name> - <status>")
        [[ -f "$FILE_CONTAINER_LIVE" ]] && live_line=$(awk -v id="$id" '$1==id' "$FILE_CONTAINER_LIVE")
        echo "${live_line:-$id}"            # fall back to the bare ID without live data
    done < "$file_list"
}

# --- get_vms ---
# @desc_short  : Prints live VM names from NFS share, one per line.
# @usage       : get_vms
# ==============================================================================
function get_vms {
    share_mounted             || return 0   # skip silently if NFS share not mounted
    [[ -f "$FILE_VM_LIVE" ]] || return 0   # skip if live file missing
    cat "$FILE_VM_LIVE"                     # emit VM names from live file
}

# --- get_cmd_current_alias ---
# @desc_short  : Prints the alias of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_alias
# ==============================================================================
function get_cmd_current_alias {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "alias" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_cmd ---
# @desc_short  : Prints the cmd of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_cmd
# ==============================================================================
function get_cmd_current_cmd {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "cmd" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_description ---
# @desc_short  : Prints the description of the currently selected entry (pre-fill for edit).
# @usage       : get_cmd_current_description
# ==============================================================================
function get_cmd_current_description {
    local value
    lx db --file "cmds.db" --table "commands" --select @value \
        --cols "description" --where "alias='${ARG_ALIAS}'" --limit 1
    echo "$value"
}

# --- get_cmd_current_devices ---
# @desc_short  : Prints all devices that have the currently selected alias, one per line.
# @usage       : get_cmd_current_devices
# ==============================================================================
function get_cmd_current_devices {
    declare -a rows
    lx db --file "cmds.db" --table "commands" --select @rows \
        --cols "device" --where "alias='${ARG_ALIAS}'"
    printf '%s\n' "${rows[@]}"
}

# --- get_cmd_aliases ---
# @desc_short  : Prints all saved command aliases with their device as "alias # device", one per line.
# @usage       : get_cmd_aliases
# ==============================================================================
function get_cmd_aliases {
    declare -a rows
    lx db --file "cmds.db" --table "commands" --select @rows --cols "alias,device" --sep " # "
    printf '%s\n' "${rows[@]}"
}

# --- get_all_devices ---
# @desc_short  : Prints all known device names (nodes + containers + VMs), one per line.
# @usage       : get_all_devices
# ==============================================================================
function get_all_devices {
    get_nodes                               # physical nodes (hosts + observers)
    get_containers                          # live containers
    get_vms                                 # live VMs
}

# ==============================================================================
# --- SSH Helpers ---
# Functions for resolving device connection details and executing remote commands.
# ==============================================================================

# --- get_device_ip ---
# @desc_short  : Resolves a device name to its IP address.
# @usage       : get_device_ip <device>
# @parameter   : $1 | device | Logical device name (e.g. host_1, observer_2).
# @notes       : Config-driven — adding a new device only requires updating config.conf
#                (HOSTS/OBSERVERS array + IP_HOST_x / IP_OBSERVER_x variable).
#                Uses indirect variable expansion: HOSTS[0]="host_1" → var="IP_HOST_1" → ${!var}
# ==============================================================================
function get_device_ip {
    local device="$1"

    # Search HOSTS array; index i maps to IP_HOST_$(i+1) via indirect expansion
    for i in "${!HOSTS[@]}"; do
        if [[ "${HOSTS[$i]}" == "$device" ]]; then
            local var="IP_HOST_$((i+1))"
            echo "${!var}"
            return 0
        fi
    done

    # Search OBSERVERS array; index i maps to IP_OBSERVER_$(i+1) via indirect expansion
    for i in "${!OBSERVERS[@]}"; do
        if [[ "${OBSERVERS[$i]}" == "$device" ]]; then
            local var="IP_OBSERVER_$((i+1))"
            echo "${!var}"
            return 0
        fi
    done

    ERROR "Unknown device: '${device}'"
    return 1
}

# --- get_device_ssh_user ---
# @desc_short  : Resolves the SSH user for a given device.
# @usage       : get_device_ssh_user <device>
# @parameter   : $1 | device | Logical device name.
# @notes       : User is determined by device type (host → SSH_USER_HOST,
#                observer → SSH_USER_OBSERVER), both defined in config.conf.
# ==============================================================================
function get_device_ssh_user {
    local device="$1"

    # Check if device is a known host
    for host in "${HOSTS[@]}"; do
        if [[ "$host" == "$device" ]]; then
            echo "$SSH_USER_HOST"
            return 0
        fi
    done

    # Check if device is a known observer
    for observer in "${OBSERVERS[@]}"; do
        if [[ "$observer" == "$device" ]]; then
            echo "$SSH_USER_OBSERVER"
            return 0
        fi
    done

    ERROR "Unknown device: '${device}'"
    return 1
}

# --- execute_on_device ---
# @desc_short  : Executes a command on a remote device via SSH.
# @usage       : execute_on_device <device> <cmd>
# @parameter   : $1 | device | Logical device name.
# @parameter   : $2 | cmd    | Shell command to execute remotely.
# ==============================================================================
function execute_on_device {
    local device="$1"
    local cmd="$2"
    local ip user

    # Resolve device to IP and SSH user
    ip=$(get_device_ip "$device")     || return 1
    user=$(get_device_ssh_user "$device") || return 1

    lx cmd --run "ssh ${user}@${ip} '${cmd}'"
}

# --- find_container_host ---
# @desc_short  : Finds which host is running a given container ID.
# @usage       : find_container_host <container_id>
# @parameter   : $1 | container_id | Proxmox container ID (e.g. 101).
# ==============================================================================
function find_container_host {
    local container_id="$1"
    local ip user

    # Query each host via direct SSH — lx cmd --run does not reliably propagate exit codes
    for host in "${HOSTS[@]}"; do
        ip=$(get_device_ip "$host")         || continue
        user=$(get_device_ssh_user "$host") || continue

        # pct list shows all containers regardless of state — grep -qx matches the exact ID
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                "${user}@${ip}" \
                "pct list 2>/dev/null | awk 'NR>1{print \$1}' | grep -qx ${container_id}" \
                2>/dev/null; then
            echo "$host"
            return 0
        fi
    done

    ERROR "Container '${container_id}' not found on any host."
    return 1
}

# --- find_vm_host ---
# @desc_short  : Finds which host is running a given VM ID.
# @usage       : find_vm_host <vm_id>
# @parameter   : $1 | vm_id | Proxmox VM ID (e.g. 201).
# ==============================================================================
function find_vm_host {
    local vm_id="$1"
    local ip user

    # Query each host via direct SSH — lx cmd --run does not reliably propagate exit codes
    for host in "${HOSTS[@]}"; do
        ip=$(get_device_ip "$host")         || continue
        user=$(get_device_ssh_user "$host") || continue

        # qm list shows all VMs regardless of state — grep -qx matches the exact ID
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                "${user}@${ip}" \
                "qm list 2>/dev/null | awk 'NR>1{print \$1}' | grep -qx ${vm_id}" \
                2>/dev/null; then
            echo "$host"
            return 0
        fi
    done

    ERROR "VM '${vm_id}' not found on any host."
    return 1
}

# ==============================================================================
# --- Container / VM Execution ---
# Higher-level execute helpers for indirect device access (via host).
# ==============================================================================

# --- execute_on_container ---
# @desc_short  : Executes a command inside a container via 'pct exec' on its host.
# @usage       : execute_on_container <container_id> <cmd>
# @parameter   : $1 | container_id | Proxmox container ID.
# @parameter   : $2 | cmd          | Command to run inside the container.
# ==============================================================================
function execute_on_container {
    local container_id="$1"
    local cmd="$2"
    local host ip user

    # Locate which host is running this container
    host=$(find_container_host "$container_id") || return 1
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    lx cmd --run "ssh ${user}@${ip} 'pct exec ${container_id} -- ${cmd}'" --show-cmd
}

# --- get_vm_ip ---
# @desc_short  : Resolves a VM's primary IP address via QEMU agent on its host.
# @usage       : get_vm_ip <vm_id>
# @parameter   : $1 | vm_id | Proxmox VM ID.
# @notes       : Requires QEMU guest agent to be running inside the VM.
# ==============================================================================
function get_vm_ip {
    local vm_id="$1"
    local host ip user vm_ip

    host=$(find_vm_host "$vm_id")        || return 1
    ip=$(get_device_ip "$host")           || return 1
    user=$(get_device_ssh_user "$host")   || return 1

    # Query VM's IP via QEMU agent — captures first IP from hostname -I output
    lx cmd --run "ssh ${user}@${ip} 'qm guest exec ${vm_id} -- hostname -I 2>/dev/null'" \
        @vm_ip --quiet --no-error-msg

    # Strip to first IP only (hostname -I may return multiple addresses)
    vm_ip="${vm_ip%% *}"

    if [[ -z "$vm_ip" ]]; then
        ERROR "Could not resolve IP for VM '${vm_id}' — QEMU agent may not be running."
        return 1
    fi

    echo "$vm_ip"
}

# --- execute_on_vm ---
# @desc_short  : Executes a command inside a VM via 'qm guest exec' on its host.
# @usage       : execute_on_vm <vm_id> <cmd>
# @parameter   : $1 | vm_id | Proxmox VM ID.
# @parameter   : $2 | cmd   | Command to run inside the VM.
# @notes       : Requires QEMU guest agent. For file operations use SSH ProxyJump instead.
# ==============================================================================
function execute_on_vm {
    local vm_id="$1"
    local cmd="$2"
    local host ip user

    host=$(find_vm_host "$vm_id")        || return 1
    ip=$(get_device_ip "$host")           || return 1
    user=$(get_device_ssh_user "$host")   || return 1

    lx cmd --run "ssh ${user}@${ip} 'qm guest exec ${vm_id} -- ${cmd}'" --show-cmd
}

# ==============================================================================
# --- _fetch_list_dir ---
# @desc_short  : Lists files and directories inside a given path on a remote device.
#                Used by the --file option-cmd in files/fetch/arguments.sh.
#                One SSH call per FZF open — results are filtered locally by FZF.
# @usage       : _fetch_list_dir <device> <path>
# @parameter   : $1 | device | Device name with type prefix (host_1, ct_3040, vm_101)
# @parameter   : $2 | path   | Base directory to list on the device (e.g. /opt/homelab)
# ==============================================================================
function _fetch_list_dir {
    local device="$1"
    local path="${2:-/}"
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

    # Nothing to list without a device — return empty gracefully.
    [[ -z "$device" ]] && return 0

    # Recursive find — all files and directories under path, sorted for FZF.
    local find_cmd="find '${path}' 2>/dev/null | sort"

    case "$device" in
        ct_*)
            local container_id="${device#ct_}"
            local host ip user

            # Locate the host running this container to route pct exec through it.
            host=$(find_container_host "$container_id") || return 0
            ip=$(get_device_ip "$host")                  || return 0
            user=$(get_device_ssh_user "$host")          || return 0

            # pct exec runs find inside the container — output streams through SSH to local FZF.
            ssh ${ssh_opts} "${user}@${ip}" \
                "pct exec ${container_id} -- find '${path}' 2>/dev/null" \
                2>/dev/null | sort
            ;;
        vm_*)
            local vm_id="${device#vm_}"
            local host host_ip host_user vm_ip

            # Resolve host and VM connection details for ProxyJump.
            host=$(find_vm_host "$vm_id")           || return 0
            host_ip=$(get_device_ip "$host")         || return 0
            host_user=$(get_device_ssh_user "$host") || return 0
            vm_ip=$(get_vm_ip "$vm_id")             || return 0

            # ProxyJump through host to VM — stream find output to local FZF.
            ssh ${ssh_opts} -J "${host_user}@${host_ip}" "root@${vm_ip}" \
                "${find_cmd}" 2>/dev/null
            ;;
        *)
            local ip user

            # Direct SSH for hosts and observers.
            ip=$(get_device_ip "$device")         || return 0
            user=$(get_device_ssh_user "$device") || return 0

            ssh ${ssh_opts} "${user}@${ip}" "${find_cmd}" 2>/dev/null
            ;;
    esac
}

# ==============================================================================
# --- observer_log_event ---
# @desc_short  : Records an event on the primary observer (events.log + daily log)
#                via obs-log-event.sh — makes LPEX actions (deployments, starts)
#                visible in the observer's event history.
# @usage       : observer_log_event <message> [status]
# @parameter   : $1 | message | Event text (e.g. "LPEX: mirror deployed → host_1")
# @parameter   : $2 | status  | Optional status label (default: INFO)
# @notes       : Fire-and-forget — a failed event log must never fail the caller.
#                Runs as fadmin (no sudo) — root has no SSH key on the observer.
# ==============================================================================
function observer_log_event {
    local message="$1"
    local status="${2:-INFO}"
    local ip user

    # Resolve the primary observer — silently skip on config errors.
    ip=$(get_device_ip "$OBSERVER_PRIMARY" 2>/dev/null)         || return 0
    user=$(get_device_ssh_user "$OBSERVER_PRIMARY" 2>/dev/null) || return 0

    # Fire-and-forget with short timeout — event logging must not block actions.
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "${user}@${ip}" \
        "/opt/homelab/bin/observer/obs-log-event.sh \"${message}\" \"${status}\"" 2>/dev/null || true
}

# ==============================================================================
# --- wake_target ---
# @desc_short  : Ensures a target is online before further actions. Delegates to
#                obs-wake.sh on OBSERVER_PRIMARY, which handles WOL (hosts),
#                pct start (containers) and qm start (VMs), blocks until the
#                target is ready and logs the event on the observer — the observer
#                authoritatively knows about every externally requested start.
# @usage       : wake_target <type> <device>
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function wake_target {
    local type="$1" device="$2"
    local target ip user

    # Map type/device to the obs-wake.sh target format.
    case "$type" in
        # Observers are always-on Pis without WOL — nothing to wake.
        observer)  return 0 ;;
        host)      target="$device" ;;
        container) target="ct_${device}" ;;
        vm)        target="vm_${device}" ;;
        # Unknown type indicates a bug in the caller — surface it immediately.
        *)         ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac

    # Resolve the primary observer — the single wake authority.
    ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    INFO "[${device}] Wake-up via ${OBSERVER_PRIMARY} (obs-wake.sh ${target})..."

    # Direct SSH — lx cmd does not reliably propagate exit codes, and the
    # observer script blocks until the target is online (WOL boot: minutes).
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
            "${user}@${ip}" "/opt/homelab/bin/observer/obs-wake.sh ${target}"; then
        ERROR "[${device}] Wake-up failed — see observer logs (events.log / daily log)."
        return 1
    fi

    OK "[${device}] Target is online."
}

# ==============================================================================
# --- Export block ---
# argument_completions.sh runs --option-cmd via `bash -c`, which spawns a new process.
# Bash functions and arrays are NOT inherited — only exported scalars and functions survive.
# This block runs once on source and makes all device-list helpers subshell-safe.
# ==============================================================================
export -f get_hosts get_observers get_nodes get_containers get_vms get_all_devices get_ha_clients share_mounted _fetch_list_dir
for _v in $(compgen -v | grep -E '^(IP_|MAC_|DEVICENAME_|OBSERVER_|MOUNT_|FILE_CONTAINER_|FILE_VM_|PATH_SHARE_)'); do
    export "$_v"
done; unset _v

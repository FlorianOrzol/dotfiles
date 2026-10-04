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

# ==============================================================================
# --- Command Shortcuts (cmd) ---
# Lookups for 'lpex homelab cmd'. They run as --option-cmd inside `bash -c`,
# where neither lx nor ARG_* exist — hence plain sqlite3 on an exported absolute
# path, and the selected alias is passed as parameter instead of read from ARG_*.
# ==============================================================================
FILE_CMDS_DB="${PATH_EXTENSION_DATA}/cmds.db"   # saved shortcuts — absolute, subshells have no lx db path logic
TABLE_CMDS="commands"                            # one row per alias, devices space-separated

# --- get_cmd_devices ---
# @desc_short  : Prints every addressable device in the cmd naming scheme, one per line.
# @usage       : get_cmd_devices
# @notes       : Same names as collect_targets and 'files': host_N, observer_N,
#                ct_<id>, vm_<id>. The live lists carry bare IDs, so they get the prefix.
# ==============================================================================
function get_cmd_devices {
    get_nodes                               # "host_1 # 10.0.101.1", "observer_1 # ... (primary)"

    # "3080 # mqtt - running" becomes "ct_3080 # mqtt - running"
    get_containers | sed 's/^/ct_/'

    # Same for VMs
    get_vms | sed 's/^/vm_/'
}

# --- get_cmd_aliases ---
# @desc_short  : Prints all saved shortcuts as "alias # devices — description".
# @usage       : get_cmd_aliases
# ==============================================================================
function get_cmd_aliases {
    # No database yet means no shortcuts — an empty list, not an error
    [[ -f "$FILE_CMDS_DB" ]] || return 0

    sqlite3 -separator ' # ' "$FILE_CMDS_DB" \
        "SELECT alias, devices || ' — ' || COALESCE(description, '') FROM ${TABLE_CMDS} ORDER BY alias;" 2>/dev/null
}

# --- get_cmd_alias_devices ---
# @desc_short  : Prints the devices stored for one alias, one per line.
# @usage       : get_cmd_alias_devices <alias>
# @parameter   : $1 | alias | Saved alias name
# ==============================================================================
function get_cmd_alias_devices {
    local alias="$1"

    # Without a database or an alias there is nothing to list
    [[ -f "$FILE_CMDS_DB" && -n "$alias" ]] || return 0

    # Double single quotes so an alias containing ' cannot break the SQL
    sqlite3 "$FILE_CMDS_DB" \
        "SELECT devices FROM ${TABLE_CMDS} WHERE alias='${alias//\'/\'\'}';" 2>/dev/null | tr ' ' '\n'
}

# --- cmd_db_init ---
# @desc_short  : Creates the shortcut table if it does not exist yet.
# @usage       : cmd_db_init
# ==============================================================================
function cmd_db_init {
    # alias is UNIQUE: one shortcut = one command for one or more devices
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --create-table \
        --cols "id INTEGER PRIMARY KEY, alias TEXT NOT NULL UNIQUE, cmd TEXT NOT NULL, devices TEXT NOT NULL, description TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP"
}

# --- cmd_validate_alias ---
# @desc_short  : Checks an alias name for allowed characters.
# @usage       : cmd_validate_alias <alias>
# @parameter   : $1 | alias | Alias name to check
# @notes       : No whitespace — the alias is a positional CLI argument.
# ==============================================================================
function cmd_validate_alias {
    local alias="$1"

    # Letters, digits, dot, underscore and dash only
    if [[ ! "$alias" =~ ^[A-Za-z0-9._-]+$ ]]; then
        ERROR "Invalid alias '${alias}' — use letters, digits, '.', '_' or '-' (no spaces)."
        return 1
    fi
}

# --- cmd_validate_devices ---
# @desc_short  : Checks device names against the cmd naming scheme.
# @usage       : cmd_validate_devices <device...>
# @parameter   : $@ | devices | Device names to check
# @notes       : Only the scheme is checked, not reachability — a saved shortcut
#                may target a device that is offline right now.
# ==============================================================================
function cmd_validate_devices {
    local device

    # At least one device is required for a shortcut
    if (( $# == 0 )); then
        ERROR "No device specified."
        return 1
    fi

    # Every name must match one of the four prefixes
    for device in "$@"; do
        if [[ ! "$device" =~ ^(host|observer|ct|vm)_[0-9]+$ ]]; then
            ERROR "Invalid device '${device}' — expected host_N, observer_N, ct_<id> or vm_<id>."
            return 1
        fi
    done
}

# --- cmd_read_alias ---
# @desc_short  : Loads one shortcut into CMD_ID, CMD_CMD, CMD_DEVICES, CMD_DESCRIPTION.
# @usage       : cmd_read_alias <alias> || return 1
# @parameter   : $1 | alias | Alias name to load
# ==============================================================================
function cmd_read_alias {
    local alias="$1"
    local where="alias='${alias//\'/\'\'}'"     # SQL literal, single quotes doubled

    CMD_ID="" CMD_CMD="" CMD_DEVICES="" CMD_DESCRIPTION=""

    # One select per column — a command may contain any separator character
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @CMD_ID          --cols "id"          --where "$where" --limit 1
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @CMD_CMD         --cols "cmd"         --where "$where" --limit 1
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @CMD_DEVICES     --cols "devices"     --where "$where" --limit 1
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @CMD_DESCRIPTION --cols "description" --where "$where" --limit 1

    # No id means no such alias
    if [[ -z "$CMD_ID" ]]; then
        ERROR "No saved command '${alias}' — see 'lpex homelab cmd list'."
        return 1
    fi
}

# --- cmd_save_alias ---
# @desc_short  : Validates and inserts a new shortcut.
# @usage       : cmd_save_alias <alias> <cmd> <description> <device...>
# @parameter   : $1 | alias       | New alias name (must not exist yet)
# @parameter   : $2 | cmd         | Command to store
# @parameter   : $3 | description | Optional description (may be empty)
# @parameter   : $@ | devices     | Remaining arguments: target devices
# ==============================================================================
function cmd_save_alias {
    local alias="$1"
    local cmd="$2"
    local description="$3"
    shift 3
    local devices=("$@")
    local id_existing

    # Reject malformed names before touching the database
    cmd_validate_alias "$alias"           || return 1
    cmd_validate_devices "${devices[@]}"  || return 1

    # An empty command would turn the shortcut into a no-op
    if [[ -z "$cmd" ]]; then
        ERROR "No command specified."
        return 1
    fi

    # First save on a fresh system — the table may not exist yet
    cmd_db_init

    # Aliases are unique — changing an existing one is 'cmd edit'
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @id_existing \
        --cols "id" --where "alias='${alias//\'/\'\'}'" --limit 1
    if [[ -n "$id_existing" ]]; then
        ERROR "Alias '${alias}' already exists — use 'lpex homelab cmd edit ${alias}'."
        return 1
    fi

    # Devices are stored space-separated in one column
    if ! lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --insert \
            --data "alias" "$alias" "cmd" "$cmd" "devices" "${devices[*]}" "description" "$description"; then
        ERROR "Saving '${alias}' failed."
        return 1
    fi

    OK "Saved '${alias}' for ${devices[*]}."
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
# @notes       : The command is passed as ONE %q-quoted word. lx cmd runs its
#                string through `bash -c`; the former '${cmd}' wrapping broke on
#                every command that contained a single quote itself — the quote
#                closed the wrapper and the rest was parsed locally (globs, JSON).
# ==============================================================================
function execute_on_device {
    local device="$1"
    local cmd="$2"
    local ip user

    # Resolve device to IP and SSH user
    ip=$(get_device_ip "$device")     || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Quote once for the local bash -c — the remote shell then sees cmd verbatim
    lx cmd --run "ssh ${user}@${ip} $(printf '%q' "$cmd")"
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

# --- client_running_host ---
# @desc_short  : Prints the host on which a container/VM is currently running.
# @usage       : client_running_host <type> <client_id>
# @parameter   : $1 | type      | Client type: container | vm
# @parameter   : $2 | client_id | Proxmox container/VM ID
# @notes       : Unlike find_container_host/find_vm_host this looks at the run state,
#                not at existence — HA clones exist on both hosts but run on one.
#                Prints nothing when the client runs nowhere (or all hosts are down).
# ==============================================================================
function client_running_host {
    local type="$1" client_id="$2"
    local host ip user cmd_status

    # pct and qm share the 'status: running' output format
    cmd_status="pct status ${client_id}"
    [[ "$type" == "vm" ]] && cmd_status="qm status ${client_id}"

    # First host reporting the client as running wins — there is only one by design
    for host in "${HOSTS[@]}"; do
        ip=$(get_device_ip "$host" 2>/dev/null)         || continue
        user=$(get_device_ssh_user "$host" 2>/dev/null) || continue

        # -n: never let ssh consume the caller's stdin (read loops)
        if ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                "${user}@${ip}" "${cmd_status} 2>/dev/null | grep -q running" 2>/dev/null; then
            echo "$host"
            return 0
        fi
    done
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
# @notes       : Runs on the host where the container RUNS — HA clones exist on
#                both hosts, the stopped copy would only answer "not running".
#                The command goes through 'sh -c' inside the container: without
#                it, '&&', pipes and redirects were executed on the HOST.
#                sh, not bash — Alpine containers (vaultwarden) have no bash.
# ==============================================================================
function execute_on_container {
    local container_id="$1"
    local cmd="$2"
    local host ip user cmd_host

    # Locate the host that currently runs this container
    host=$(client_running_host container "$container_id")
    if [[ -z "$host" ]]; then
        ERROR "Container '${container_id}' is not running on any host."
        return 1
    fi
    ip=$(get_device_ip "$host")                  || return 1
    user=$(get_device_ssh_user "$host")          || return 1

    # Two quoting levels: %q for sh -c inside the container, %q for the local bash -c
    cmd_host="pct exec ${container_id} -- sh -c $(printf '%q' "$cmd")"
    INFO "ct_${container_id} (${host}): ${cmd}"
    lx cmd --run "ssh ${user}@${ip} $(printf '%q' "$cmd_host")"
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
#                Same quoting and running-host rules as execute_on_container.
#                qm guest exec answers with JSON (exitcode, out-data).
# ==============================================================================
function execute_on_vm {
    local vm_id="$1"
    local cmd="$2"
    local host ip user cmd_host

    # Locate the host that currently runs this VM
    host=$(client_running_host vm "$vm_id")
    if [[ -z "$host" ]]; then
        ERROR "VM '${vm_id}' is not running on any host."
        return 1
    fi
    ip=$(get_device_ip "$host")           || return 1
    user=$(get_device_ssh_user "$host")   || return 1

    # Two quoting levels: %q for sh -c inside the VM, %q for the local bash -c
    cmd_host="qm guest exec ${vm_id} -- sh -c $(printf '%q' "$cmd")"
    INFO "vm_${vm_id} (${host}): ${cmd}"
    lx cmd --run "ssh ${user}@${ip} $(printf '%q' "$cmd_host")"
}

# --- execute_on_target ---
# @desc_short  : Runs a command on any device given in the cmd naming scheme.
# @usage       : execute_on_target <device> <cmd>
# @parameter   : $1 | device | host_N, observer_N, ct_<id> or vm_<id>
# @parameter   : $2 | cmd    | Command to execute
# @notes       : Observers log in as fadmin — commands needing root need sudo.
# ==============================================================================
function execute_on_target {
    local device="$1"
    local cmd="$2"

    # Route by name prefix — the same scheme collect_targets and 'files' use
    case "$device" in
        host_*|observer_*) execute_on_device    "$device"       "$cmd" ;;
        ct_*)              execute_on_container "${device#ct_}" "$cmd" ;;
        vm_*)              execute_on_vm        "${device#vm_}" "$cmd" ;;
        *)
            ERROR "Unknown device '${device}' — expected host_N, observer_N, ct_<id> or vm_<id>."
            return 1
            ;;
    esac
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
# @usage       : wake_target [@ref] <type> <device>
# @parameter   : @ref    | nameref | optional: receives 1 when this call actually
#                                    started the target, 0 when it was already up.
#                                    Hosts are probed by ping, containers/VMs by
#                                    their pct/qm status on every reachable host.
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function wake_target {
    local ref_was_offline=""

    # Optional @ref in first position — lets the caller restore the previous power
    # state afterwards instead of leaving a woken device running
    if [[ "$1" == @* ]]; then
        ref_was_offline="${1#@}"
        printf -v "$ref_was_offline" '%s' "0"  # default: target was already up
        shift
    fi

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

    # Probe before waking — obs-wake.sh reports success either way, so only a target
    # that is down right now is one this call actually powers on
    if [[ -n "$ref_was_offline" && "$type" == "host" ]]; then
        local ip_target
        ip_target=$(get_device_ip "$device") || return 1
        ping -c 1 -W 2 "$ip_target" >/dev/null 2>&1 || printf -v "$ref_was_offline" '%s' "1"
    fi

    # Clients: running on no host at all means this call is the one starting it
    if [[ -n "$ref_was_offline" && ( "$type" == "container" || "$type" == "vm" ) ]]; then
        [[ -z "$(client_running_host "$type" "$device")" ]] && printf -v "$ref_was_offline" '%s' "1"
    fi

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
# --- Target Expansion ---
# Resolves group keywords (all, hosts, observers, clients) and single device
# names into "type:device" pairs. Shared by 'update' and 'state refresh' — both
# accept the same --devices grammar.
# ==============================================================================
SSH_OPTS_LIST="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"    # non-interactive SSH for list queries

# --- collect_targets ---
# @desc_short  : Expands groups and device names into deduplicated "type:device"
#                pairs. Group 'all' expands to observers → hosts → clients so
#                the update order matches the deployment order.
# @usage       : collect_targets @nameref_targets <input...>
# @parameter   : $1 | nameref_targets | Array variable to receive the target pairs
# @parameter   : $@ | inputs          | Groups and/or device names from --devices
# ==============================================================================
function collect_targets {
    local -n return_collect_targets="${1#@}"
    shift
    local inputs=("$@")
    local input

    return_collect_targets=()

    # Map each input to its target pairs — groups expand via list helpers.
    for input in "${inputs[@]}"; do
        case "$input" in
            all)        _targets_append @return_collect_targets "$(_list_observers; _list_hosts; _list_clients)" ;;
            hosts)      _targets_append @return_collect_targets "$(_list_hosts)" ;;
            observers)  _targets_append @return_collect_targets "$(_list_observers)" ;;
            clients)    _targets_append @return_collect_targets "$(_list_clients)" ;;
            host_*)     return_collect_targets+=("host:${input}") ;;
            observer_*) return_collect_targets+=("observer:${input}") ;;
            ct_*)       return_collect_targets+=("container:${input#ct_}") ;;
            vm_*)       return_collect_targets+=("vm:${input#vm_}") ;;
            *)  ERROR "Unknown device or group: '${input}' — expected all, hosts, observers, clients, host_*, observer_*, ct_*, or vm_*"
                return 1 ;;
        esac
    done

    # Mixed input like "hosts host_1" may produce duplicates — keep first occurrence.
    _targets_dedupe @return_collect_targets

    # Abort when nothing was resolved — e.g. 'clients' with all hosts offline.
    if (( ${#return_collect_targets[@]} == 0 )); then
        ERROR "No targets resolved from: ${inputs[*]}"
        return 1
    fi
}

# --- _targets_append ---
# @desc_short  : Appends newline-separated target pairs to the nameref array.
# @parameter   : $1 | nameref_list | Array variable to append to
# @parameter   : $2 | lines        | Newline-separated "type:device" pairs
# ==============================================================================
function _targets_append {
    local -n _ta_list="${1#@}"
    local lines="$2"
    local line

    # Append each non-empty line as one target pair.
    while IFS= read -r line; do
        [[ -n "$line" ]] && _ta_list+=("$line")
    done <<< "$lines"
}

# --- _targets_dedupe ---
# @desc_short  : Removes duplicate entries from the nameref array, keeping order.
# @parameter   : $1 | nameref_list | Array variable to deduplicate in place
# ==============================================================================
function _targets_dedupe {
    local -n _td_list="${1#@}"
    local -a unique=()
    local entry

    # Keep the first occurrence of every entry — preserves the update order.
    for entry in "${_td_list[@]}"; do
        [[ " ${unique[*]} " == *" ${entry} "* ]] || unique+=("$entry")
    done
    _td_list=("${unique[@]}")
}

# --- _list_hosts ---
# @desc_short  : Prints all configured hosts as "host:<name>", one per line.
# ==============================================================================
function _list_hosts {
    # Names come from config — first column of get_hosts ("name # ip").
    get_hosts | awk '{print "host:"$1}'
}

# --- _list_observers ---
# @desc_short  : Prints all configured observers as "observer:<name>", one per line.
# ==============================================================================
function _list_observers {
    # Names come from config — first column of get_observers ("name # ip (role)").
    get_observers | awk '{print "observer:"$1}'
}

# --- _list_clients ---
# @desc_short  : Prints all containers and VMs as "container:<id>" / "vm:<id>".
# @notes       : Queried live via pct/qm on every reachable host — authoritative
#                and independent of the NFS live lists (includes stopped clients).
#                Offline hosts are skipped silently (BatchMode SSH fails fast).
#                Runs inside $(...) — must not print anything except target pairs.
# ==============================================================================
function _list_clients {
    local host ip user

    # Query each configured host for its containers and VMs.
    while IFS= read -r host; do
        # Resolve connection details — skip host on config errors.
        ip=$(get_device_ip "$host" 2>/dev/null)         || continue
        user=$(get_device_ssh_user "$host" 2>/dev/null) || continue

        # pct/qm list all clients regardless of state — NR>1 skips the header line.
        # -n keeps ssh off the loop's stdin, which would swallow the host list.
        ssh -n ${SSH_OPTS_LIST} "${user}@${ip}" \
            "pct list 2>/dev/null | awk 'NR>1{print \"container:\"\$1}';
             qm  list 2>/dev/null | awk 'NR>1{print \"vm:\"\$1}'" 2>/dev/null
    done < <(get_hosts | awk '{print $1}')
}

# ==============================================================================
# --- Status Collectors ---
# Triggers the health collectors that write status.json to the NFS share, so the
# share reflects the current state immediately instead of waiting for the daily
# health timer (06:05 hosts / 06:10 clients). Shared by 'update' (post-update
# refresh) and 'state refresh' (standalone).
# ==============================================================================
CMD_STATUS_HOST="/opt/homelab/bin/hosts/get-host-status.sh"             # host metrics + lxc-status.json
CMD_STATUS_CLIENTS="/opt/homelab/bin/hosts/get-clients-status.sh"       # per-client status.json, skips stopped clients
CMD_STATUS_OBSERVER="/opt/homelab/bin/observer/obs-health.sh"           # observer status.json

# --- device_is_online ---
# @desc_short  : Reports whether a device answers a ping right now.
# @desc_detailed: Deliberately does NOT use wake_target — that delegates to
#                 obs-wake.sh and would send a WOL packet. Collecting status must
#                 never power a device on; an offline host stays offline and keeps
#                 its last known status on the share.
# @usage       : device_is_online <device>
# @parameter   : $1 | device | Logical device name (host_1, observer_2, ...)
# ==============================================================================
function device_is_online {
    local device="$1"
    local ip

    # A device without a configured IP cannot be probed at all.
    ip=$(get_device_ip "$device" 2>/dev/null) || return 1

    # Single probe with a short deadline — a sweep must not stall on dead hosts.
    ping -c 1 -W 2 "$ip" >/dev/null 2>&1
}

# --- refresh_device_status ---
# @desc_short  : Re-runs the status collector(s) responsible for one device so the
#                NFS share reflects its current state immediately.
# @desc_detailed: Clients have no collector of their own — get-clients-status.sh
#                 runs on their host and injects a payload via pct exec / qm guest
#                 exec. A container therefore refreshes through its host, which
#                 picks up every other running client there in the same run.
# @notes       : Best-effort — a failed refresh must never fail the caller.
#                Observers run their collector as fadmin (no sudo!) to keep the
#                share file ownership identical to the daily timer runs.
#                The host collector self-heals its NFS mounts (ensure_share_mounted),
#                so no observer-side mount trigger is needed here.
# @usage       : refresh_device_status <type> <device>
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function refresh_device_status {
    local type="$1" device="$2"
    local host_client

    case "$type" in
        host)
            INFO "[${device}] Refreshing host and client status on the share..."
            execute_on_device "$device" "$CMD_STATUS_HOST" \
                || WARN "[${device}] Host status refresh failed — next health timer run will catch up."
            # Same host, second collector — covers every running client on it at once.
            execute_on_device "$device" "$CMD_STATUS_CLIENTS" \
                || WARN "[${device}] Client status refresh failed — next health timer run will catch up."
            ;;
        observer)
            INFO "[${device}] Refreshing status.json on the share..."
            execute_on_device "$device" "$CMD_STATUS_OBSERVER" \
                || WARN "[${device}] Status refresh failed — next health timer run will catch up."
            ;;
        container|vm)
            # Locate the host running this client — the collector lives there, not in the client.
            if [[ "$type" == "container" ]]; then
                host_client=$(find_container_host "$device")
            else
                host_client=$(find_vm_host "$device")
            fi

            # Without a host there is nothing to trigger — stay best-effort and move on.
            if [[ -z "$host_client" ]]; then
                WARN "[${type}_${device}] Host not found — status refresh skipped."
                return 0
            fi

            INFO "[${type}_${device}] Refreshing client status via ${host_client}..."
            execute_on_device "$host_client" "$CMD_STATUS_CLIENTS" \
                || WARN "[${type}_${device}] Client status refresh failed — next health timer run will catch up."
            ;;
        # Unknown type indicates a bug in the caller — surface it immediately.
        *)  ERROR "Unknown device type: '${type}'"
            return 1 ;;
    esac
}

# --- refresh_all_status ---
# @desc_short  : Refreshes host, client and observer status for every device that
#                is reachable right now.
# @desc_detailed: Offline devices are skipped, never woken — a status refresh must
#                 not power on a host just to read it. Stopped containers and VMs
#                 need no handling here: get-clients-status.sh skips them by design,
#                 so a stopped HA clone on the standby can never overwrite the
#                 status of the running instance.
# @usage       : refresh_all_status [<device>...]
# @parameter   : $@ | skip | Devices already refreshed completely by the caller
# ==============================================================================
function refresh_all_status {
    local -a skip=("$@")
    local -a hosts=() observers=()
    local device

    # Read both device lists up front — the collectors below run ssh, which would
    # otherwise consume a while-read loop's stdin and cut the iteration short.
    mapfile -t hosts     < <(get_hosts     | awk '{print $1}')
    mapfile -t observers < <(get_observers | awk '{print $1}')

    # Hosts first — their collector also writes lxc-status.json, which the state
    # views need to show stopped clients.
    for device in "${hosts[@]}"; do
        _refresh_if_online "host" "$device" "${skip[@]}"
    done

    # Observers last — obs-health.sh scans the share for HA overrides and profits
    # from the host data written above.
    for device in "${observers[@]}"; do
        _refresh_if_online "observer" "$device" "${skip[@]}"
    done
}

# --- _refresh_if_online ---
# @desc_short  : Refreshes one device unless it was already done or is offline.
# @usage       : _refresh_if_online <type> <device> [<skip>...]
# @parameter   : $1 | type   | Device type: observer | host
# @parameter   : $2 | device | Logical device name
# @parameter   : $@ | skip   | Devices the caller already refreshed
# ==============================================================================
function _refresh_if_online {
    local type="$1" device="$2"
    shift 2
    local skip=" $* "

    # Already refreshed in this run — a second collector call would only cost SSH time.
    if [[ "$skip" == *" ${device} "* ]]; then
        return 0
    fi

    # Offline devices keep their last known status — never wake them for a refresh.
    if ! device_is_online "$device"; then
        INFO "[${device}] Offline — skipped, status on the share stays as it is."
        return 0
    fi

    refresh_device_status "$type" "$device"
}

# ==============================================================================
# --- shutdown_woken_host ---
# @desc_short  : Powers a host down again that this run woke up for the update.
# @desc_detailed: Restores the pre-update power state — a host that was off before
#                 must not be left running afterwards. Delegates to host-shutdown.sh
#                 on the primary observer, the same path 'control host power' uses,
#                 so the observer stays the single power authority and logs the event.
# @parameter   : $1 | device | Logical host name
# ==============================================================================
function shutdown_woken_host {
    local device="$1"

    INFO "[${device}] Was offline before the update — powering down again via ${OBSERVER_PRIMARY}..."

    # Best-effort: a failed power-down only leaves the host running, which is harmless
    if ! execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-shutdown.sh ${device}"; then
        WARN "[${device}] Power-down failed — host stays online."
        return 1
    fi

    OK "[${device}] Powered down again."
}

# ==============================================================================
# --- HA List Management ---
# The ha_clients list lives on the observers under /opt/homelab/state/ha_clients
# (source of truth — the HA watcher must stay decision-capable without NFS). The
# active watcher mirrors it to ${PATH_SHARE_STATE}/ha_clients; LPEX reads
# NFS-first and writes observers + share on changes. Used by 'setup ha'
# (add/remove/move/edit), 'state ha' (display) and 'setup container --delete'
# (silent removal on deletion, no marker — see _ha_remove_from_list).
# Every explicit removal additionally leaves a permanent marker at
# ${PATH_SHARE_STATE}/clients/<id>/ha_removed.json — see the Removal Markers
# section below.
# ==============================================================================
FILE_REMOTE_HA_CLIENTS="/opt/homelab/state/ha_clients"      # ha_clients path on the observers (source of truth)
PATH_REMOTE_CT_STATES="/opt/homelab/state/ct_states"        # per-CT watcher state files on the observers
FILENAME_HA_REMOVED="ha_removed.json"                       # per-CT removal marker in state/clients/<id>/

SSH_OPTS_HA=(-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes)

# --- _ha_read_list ---
# @desc_short  : Reads the ha_clients boot order into an array — NFS-first, SSH fallback.
# @usage       : _ha_read_list @return_var
# @parameter   : $1 | @return_var | Name of the array variable to fill (one CT ID per element).
# ==============================================================================
function _ha_read_list {
    local -n return_ha_read_list="${1#@}"
    return_ha_read_list=()
    local raw="" id ip user
    local file_share_ha="${PATH_SHARE_STATE}/ha_clients"    # runtime-derived — see Script Internals note

    # NFS-first: the share mirror avoids SSH in the common read path
    if [[ -n "$PATH_SHARE_STATE" && -f "$file_share_ha" ]]; then
        raw=$(<"$file_share_ha")
    else
        # Share unavailable — fall back to the primary observer via SSH
        ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
        user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1
        raw=$(ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" "cat ${FILE_REMOTE_HA_CLIENTS}" 2>/dev/null) || {
            ERROR "ha_clients not readable — share unmounted and ${OBSERVER_PRIMARY} unreachable."
            return 1
        }
    fi

    # Normalize each line: strip comments/whitespace, keep only non-empty IDs
    while IFS= read -r id || [[ -n "$id" ]]; do
        id="${id%%#*}"                      # strip optional '# comment' suffix
        id="${id//[[:space:]]/}"            # trim all whitespace around the ID
        [[ -n "$id" ]] && return_ha_read_list+=("$id")
    done <<< "$raw"
}

# --- _ha_write_list ---
# @desc_short  : Writes the boot order to both observers and the NFS share.
# @desc_detailed: Primary observer is mandatory (the active watcher reads locally);
#                 standby observer is best effort (may sleep — warn only); the share
#                 copy is written directly so displays are consistent immediately
#                 instead of waiting for the watcher's next sync cycle.
# @usage       : _ha_write_list <list_content> <change_description>
# @parameter   : $1 | list_content       | Full new list, newline separated CT IDs.
# @parameter   : $2 | change_description | Short text for the observer event log.
# ==============================================================================
function _ha_write_list {
    local list_content="$1"
    local change_description="$2"
    local observer ip user
    local file_share_ha="${PATH_SHARE_STATE}/ha_clients"    # runtime-derived — see Script Internals note

    for observer in "${OBSERVERS[@]}"; do
        ip=$(get_device_ip "$observer")         || return 1
        user=$(get_device_ssh_user "$observer") || return 1

        # Atomic remote write: tmp file + mv prevents the watcher reading a partial list;
        # ssh stderr suppressed — the WARN/ERROR below reports the failure cleanly
        if printf '%s\n' "$list_content" | ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" \
                "cat > ${FILE_REMOTE_HA_CLIENTS}.tmp && mv ${FILE_REMOTE_HA_CLIENTS}.tmp ${FILE_REMOTE_HA_CLIENTS}" 2>/dev/null; then
            OK "ha_clients written → ${observer}"
        else
            # Only the primary is mandatory — its watcher acts on the list every 60s
            if [[ "$observer" == "$OBSERVER_PRIMARY" ]]; then
                ERROR "Write to ${observer} failed — aborting (primary is the source of truth)."
                return 1
            fi
            WARN "Write to ${observer} failed (offline?) — sync it manually when it is back."
        fi
    done

    # Direct share update for immediate display consistency (watcher would sync within 60s)
    if [[ -n "$PATH_SHARE_STATE" ]] && share_mounted; then
        printf '%s\n' "$list_content" > "$file_share_ha"
    else
        WARN "NFS share not mounted — share copy will be synced by the watcher."
    fi

    # Make the change visible in the observer's event history (fire-and-forget)
    observer_log_event "LPEX: ha_clients updated (${change_description})" "OK"
}

# --- _ha_remove_from_list ---
# @desc_short  : Rewrites the boot order without one CT and clears its watcher state.
# @desc_detailed: Shared by 'setup ha --remove' (which additionally writes the
#                 permanent ha_removed.json marker) and 'setup container --delete'
#                 (which does not — the container itself is gone, a marker on a
#                 client dir that is about to be deleted too would be pointless).
# @usage       : _ha_remove_from_list <container_id> <change_description>
# @parameter   : $1 | container_id       | CT ID (numeric).
# @parameter   : $2 | change_description | Short text for the observer event log.
# @exit_codes  : 0 | Removed.
# @exit_codes  : 1 | Read/write failure — nothing changed.
# @exit_codes  : 2 | CT was not HA-managed — not an error, caller decides how to report it.
# ==============================================================================
function _ha_remove_from_list {
    local container_id="$1"
    local change_description="$2"
    local -a ha_list new_list=()
    local found=0 id observer ip user

    _ha_read_list @ha_list || return 1

    # Rebuild the list without the target ID — order of the rest stays untouched
    for id in "${ha_list[@]}"; do
        if [[ "$id" == "$container_id" ]]; then
            found=1
        else
            new_list+=("$id")
        fi
    done

    (( found )) || return 2

    _ha_write_list "$(printf '%s\n' "${new_list[@]}")" "$change_description" || return 1

    # Clear the watcher's per-CT state file on both observers — best effort, a leftover
    # file is harmless (the watcher only reads states for listed IDs)
    for observer in "${OBSERVERS[@]}"; do
        ip=$(get_device_ip "$observer")         || continue
        user=$(get_device_ssh_user "$observer") || continue
        ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" "rm -f ${PATH_REMOTE_CT_STATES}/${container_id}" 2>/dev/null
    done
}

# --- _ha_set_maintenance ---
# @desc_short  : Writes ha_override.json so HA pauses restarts for one container.
# @desc_detailed: Shared by 'control container --maintenance' and 'setup container
#                 --delete' (written before shutdown so the watcher cannot restart
#                 the container mid-deletion — it reconciles every 60s).
# @usage       : _ha_set_maintenance <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function _ha_set_maintenance {
    local container_id="$1"
    local state_dir="${PATH_SHARE_STATE}/clients/${container_id}"

    mkdir -p "$state_dir"                                                            # ensure state directory exists
    echo '{"mode":"maintenance","set_by":"lpex"}' > "${state_dir}/ha_override.json"   # no expiry = permanent, until cleared
}

# --- _ha_clear_maintenance ---
# @desc_short  : Removes the maintenance override, restoring normal HA behavior.
# @usage       : _ha_clear_maintenance <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function _ha_clear_maintenance {
    local container_id="$1"

    rm -f "${PATH_SHARE_STATE}/clients/${container_id}/ha_override.json"
}

# ==============================================================================
# --- Removal Markers ---
# A container that leaves the HA list would otherwise vanish without a trace —
# it simply stops appearing in ha_clients. These helpers keep a permanent record
# next to the container's status.json on the share, so the status views can flag
# an unprotected container without parsing observer logs.
# ==============================================================================

# --- _ha_actor ---
# @desc_short  : Prints who triggered the change, e.g. "florian@desktop".
# @usage       : actor=$(_ha_actor)
# ==============================================================================
function _ha_actor {
    local host_short="${HOSTNAME:-$(uname -n)}"     # bash sets HOSTNAME; uname covers non-bash shells

    printf '%s@%s' "${USER:-unknown}" "${host_short%%.*}"
}

# --- _ha_mark_removed ---
# @desc_short  : Writes the permanent "removed from HA" marker for one container.
# @desc_detailed: Lives at ${PATH_SHARE_STATE}/clients/<id>/ha_removed.json and
#                 stays until the container is added back (--add / --edit), which
#                 deletes it. Share-only — the observers keep no per-client state.
# @usage       : _ha_mark_removed <container_id> <boot_position> [reason]
# @parameter   : $1 | container_id  | CT ID (numeric).
# @parameter   : $2 | boot_position | Boot position the CT held before removal (0 = unknown).
# @parameter   : $3 | reason        | Optional free text shown in the HA views.
# ==============================================================================
function _ha_mark_removed {
    local container_id="$1"
    local boot_position="$2"
    local reason="${3:-}"
    local path_client="${PATH_SHARE_STATE}/clients/${container_id}"
    local file_removed="${path_client}/${FILENAME_HA_REMOVED}"

    # Golden rule: never touch a share path while the share is down
    if [[ -z "$PATH_SHARE_STATE" ]] || ! share_mounted; then
        WARN "NFS share not mounted — removal of CT ${container_id} not recorded."
        return 1
    fi

    # A container that never reported a status has no client dir yet
    mkdir -p "$path_client" 2>/dev/null || { WARN "Cannot create ${path_client} — removal not recorded."; return 1; }

    # jq builds the JSON so a reason with quotes or newlines cannot break the file
    jq -n \
        --argjson removed_unix  "$(date +%s)" \
        --arg     removed_iso   "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg     actor         "$(_ha_actor)" \
        --arg     reason        "$reason" \
        --argjson last_boot_pos "$boot_position" \
        '{removed_unix: $removed_unix, removed_iso: $removed_iso, actor: $actor, reason: $reason, last_boot_pos: $last_boot_pos}' \
        > "${file_removed}.tmp" 2>/dev/null || { WARN "Cannot write ${file_removed} — removal not recorded."; return 1; }

    # Atomic swap — a status run must never read a half-written marker
    mv "${file_removed}.tmp" "$file_removed"
}

# --- _ha_clear_removed ---
# @desc_short  : Deletes the removal marker of a container that is back in HA.
# @usage       : _ha_clear_removed <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function _ha_clear_removed {
    local container_id="$1"
    local file_removed="${PATH_SHARE_STATE}/clients/${container_id}/${FILENAME_HA_REMOVED}"

    # Silent skip when the share is down — nothing to clean up that we could reach
    [[ -n "$PATH_SHARE_STATE" ]] && share_mounted || return 0

    # Absent marker is the normal case for a CT that was never removed — -f stays quiet
    rm -f "$file_removed"
}

# --- _ha_read_removed ---
# @desc_short  : Collects all removal markers as "<id>|<iso>|<actor>|<reason>" lines.
# @usage       : _ha_read_removed @return_var
# @parameter   : $1 | @return_var | Name of the array variable to fill.
# ==============================================================================
function _ha_read_removed {
    local -n return_ha_read_removed="${1#@}"
    return_ha_read_removed=()
    local file_removed container_id fields

    # Silent skip when the share is down — the caller treats this as "none known"
    [[ -n "$PATH_SHARE_STATE" ]] && share_mounted || return 0

    # Glob over all client dirs — only those with a marker are unprotected on purpose
    for file_removed in "${PATH_SHARE_STATE}"/clients/*/"${FILENAME_HA_REMOVED}"; do
        # An unmatched glob stays literal — skip it instead of parsing the pattern
        [[ -f "$file_removed" ]] || continue

        # The client dir is named after the CT ID — no field in the file carries it
        container_id=$(basename "$(dirname "$file_removed")")

        # Skip a marker that is not valid JSON rather than emitting a broken row
        fields=$(jq -r '[.removed_iso, .actor, .reason] | join("|")' "$file_removed" 2>/dev/null) || continue

        return_ha_read_removed+=("${container_id}|${fields}")
    done
}

# ==============================================================================
# --- Export block ---
# argument_completions.sh runs --option-cmd via `bash -c`, which spawns a new process.
# Bash functions and arrays are NOT inherited — only exported scalars and functions survive.
# This block runs once on source and makes all device-list helpers subshell-safe.
# ==============================================================================
export -f get_hosts get_observers get_nodes get_containers get_vms get_ha_clients share_mounted _fetch_list_dir
export -f get_cmd_devices get_cmd_aliases get_cmd_alias_devices
export FILE_CMDS_DB TABLE_CMDS
# PORT_/TIMEOUT_/THRESHOLD_ cover share_reachable's config (homelab_functions.sh) — extend
# this list whenever a new --option-cmd needs another config.conf variable in its subshell.
for _v in $(compgen -v | grep -E '^(IP_|MAC_|DEVICENAME_|OBSERVER_|MOUNT_|FILE_CONTAINER_|FILE_VM_|PATH_SHARE_|PORT_|TIMEOUT_|THRESHOLD_)'); do
    export "$_v"
done; unset _v

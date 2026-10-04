#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power-state handling for 'homelab update' — records the
#                     client power state before the run, awaits requested reboots,
#                     checks devices after a reboot and restores the pre-update
#                     client power state at the end. Sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- User Configuration ---
# Adjust these to match your environment.
# ==============================================================================
TIMEOUT_REBOOT_WAIT=900             # max seconds until a rebooting device must be back (host WOL boot ~3 min)
TIMEOUT_BOOT_SETTLE=120             # max seconds for systemd to finish booting before the post-reboot check
INTERVAL_REBOOT_POLL=10             # seconds between two probes while waiting for a reboot
COUNT_BOOT_ERRORS_SHOWN=10          # newest error lines of the current boot printed by the post-reboot check

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS_POWER=(-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes)  # non-interactive, fail-fast SSH
FILE_SHUTDOWN_SCHEDULED="/run/systemd/shutdown/scheduled"                           # written by systemd while a delayed shutdown/reboot is pending

# ==============================================================================
# --- snapshot_client_power ---
# @desc_short  : Records the power state of every container and VM on every
#                reachable host.
# @usage       : snapshot_client_power @return_var
# @parameter   : $1 | return_var | Associative array receiving "host|type|id" → running|stopped
# @notes       : Offline hosts are skipped by ping first — a dead host must not
#                stall the run with SSH timeouts, and its clients are not ours to restore.
# ==============================================================================
function snapshot_client_power {
    local -n return_snapshot_client_power="${1#@}"
    local host ip user line type id status

    return_snapshot_client_power=()

    # One SSH call per online host lists all its containers and VMs with their state
    for host in "${HOSTS[@]}"; do
        # Skip hosts that are down right now — nothing runs there
        device_is_online "$host" || continue
        ip=$(get_device_ip "$host")         || continue
        user=$(get_device_ssh_user "$host") || continue

        # pct list: VMID STATUS ...; qm list: VMID NAME STATUS ... — normalise to "type id status"
        while read -r type id status; do
            [[ -n "$id" ]] && return_snapshot_client_power["${host}|${type}|${id}"]="$status"
        done < <(ssh -n "${SSH_OPTS_POWER[@]}" "${user}@${ip}" \
            "pct list 2>/dev/null | awk 'NR>1{print \"container\", \$1, \$2}';
             qm  list 2>/dev/null | awk 'NR>1{print \"vm\", \$1, \$3}'" 2>/dev/null)
    done
}

# --- client_power_label ---
# @desc_short  : Prints "running (host_x)" or "stopped" for one client of a snapshot.
# @usage       : client_power_label @snapshot <type> <id>
# @parameter   : $1 | snapshot | Associative array from snapshot_client_power
# @parameter   : $2 | type     | container | vm
# @parameter   : $3 | id       | Client ID
# ==============================================================================
function client_power_label {
    local -n snapshot_client_power_label="${1#@}"
    local type="$2" id="$3"
    local key found=0

    # HA clones exist on several hosts — the client counts as running if one instance runs
    for key in "${!snapshot_client_power_label[@]}"; do
        # Only entries of this client are relevant
        [[ "$key" == *"|${type}|${id}" ]] || continue
        found=1
        # Report the host of the running instance
        if [[ "${snapshot_client_power_label[$key]}" == "running" ]]; then
            echo "running (${key%%|*})"
            return 0
        fi
    done

    # Known but not running anywhere vs. not visible at all (its host is offline)
    (( found )) && echo "stopped" || echo "unknown"
}

# ==============================================================================
# --- run_script_on_target ---
# @desc_short  : Runs a POSIX shell script on a device and prints its stdout.
# @usage       : run_script_on_target <type> <device> <script>
# @parameter   : $1 | type   | observer | host | container
# @parameter   : $2 | device | Device name or container ID
# @parameter   : $3 | script | POSIX sh script, fed via stdin (no quoting through SSH/pct)
# @notes       : Observers run it via sudo — journalctl needs it to see system errors.
#                Alpine containers have no bash, hence plain sh.
# ==============================================================================
function run_script_on_target {
    local type="$1" device="$2" script="$3"
    local host ip user

    case "$type" in
        observer|host)
            ip=$(get_device_ip "$device" 2>/dev/null)         || return 1
            user=$(get_device_ssh_user "$device" 2>/dev/null) || return 1
            # Observers log in as fadmin — sudo for full system journal access
            if [[ "$type" == "observer" ]]; then
                ssh "${SSH_OPTS_POWER[@]}" "${user}@${ip}" "sudo -n sh -s" <<< "$script" 2>/dev/null
            else
                ssh "${SSH_OPTS_POWER[@]}" "${user}@${ip}" "sh -s" <<< "$script" 2>/dev/null
            fi
            ;;
        container)
            # Only a running instance can execute anything — HA clones exist on both hosts
            host=$(client_running_host "container" "$device")
            [[ -z "$host" ]] && return 1
            ip=$(get_device_ip "$host")         || return 1
            user=$(get_device_ssh_user "$host") || return 1
            ssh "${SSH_OPTS_POWER[@]}" "${user}@${ip}" "pct exec ${device} -- sh -s" <<< "$script" 2>/dev/null
            ;;
        # VMs would need qm guest exec with JSON output — not supported here
        *)  return 1 ;;
    esac
}

# --- get_boot_token ---
# @desc_short  : Prints a value that changes with every boot of the device.
# @usage       : get_boot_token <type> <device>
# @notes       : Containers share the host kernel and therefore its boot_id — their
#                /proc is mounted fresh per container start, so its ctime is used.
# ==============================================================================
function get_boot_token {
    local type="$1" device="$2"

    run_script_on_target "$type" "$device" "$(_boot_token_cmd "$type")"
}

# --- _boot_token_cmd ---
# @desc_short  : Prints the shell command that reads the boot token for a device type.
# @usage       : _boot_token_cmd <type>
# ==============================================================================
function _boot_token_cmd {
    local type="$1"

    # Containers: per-start procfs; hosts/observers: kernel boot_id
    if [[ "$type" == "container" ]]; then
        echo "stat -c %Z /proc/1"
    else
        echo "cat /proc/sys/kernel/random/boot_id"
    fi
}

# --- reboot_scheduled ---
# @desc_short  : Returns 0 when update-os.sh scheduled a reboot on the device.
# @usage       : reboot_scheduled <type> <device> <boot_token_before>
# @notes       : A device that no longer answers, or already answers with a new boot
#                token, is past the scheduling point — both count as scheduled.
# ==============================================================================
function reboot_scheduled {
    local type="$1" device="$2" token_before="$3"
    local answer

    # One probe returns the pending-shutdown marker plus the current boot token
    answer=$(run_script_on_target "$type" "$device" \
        "test -e ${FILE_SHUTDOWN_SCHEDULED} && echo scheduled; $(_boot_token_cmd "$type")")

    # Unreachable right now — the reboot is already under way
    [[ -z "$answer" ]] && return 0
    # Marker present — shutdown -r +N is pending
    [[ "$answer" == *scheduled* ]] && return 0
    # Different token — the reboot already happened
    [[ "$(tail -n 1 <<< "$answer")" != "$token_before" ]] && return 0
    return 1
}

# --- await_reboot ---
# @desc_short  : Blocks until the device is back with a new boot token.
# @usage       : await_reboot @return_var <type> <device> <boot_token_before>
# @parameter   : $1 | return_var | Receives the elapsed seconds (or empty on timeout)
# ==============================================================================
function await_reboot {
    local -n return_await_reboot="${1#@}"
    local type="$2" device="$3" token_before="$4"
    local token_now waited=0

    return_await_reboot=""
    INFO "[$(target_label "$type" "$device")] Waiting for the reboot to complete (max ${TIMEOUT_REBOOT_WAIT}s)..."

    # Poll until the device answers with a boot token different from the one before
    while (( waited < TIMEOUT_REBOOT_WAIT )); do
        sleep "$INTERVAL_REBOOT_POLL"
        waited=$(( waited + INTERVAL_REBOOT_POLL ))
        token_now=$(get_boot_token "$type" "$device")
        # Empty = still down; same token = reboot not yet executed
        if [[ -n "$token_now" && "$token_now" != "$token_before" ]]; then
            return_await_reboot="$waited"
            OK "[$(target_label "$type" "$device")] Back online after ${waited}s."
            return 0
        fi
    done

    ERROR "[$(target_label "$type" "$device")] Not back after ${TIMEOUT_REBOOT_WAIT}s — check the device manually."
    return 1
}

# --- post_reboot_check ---
# @desc_short  : Waits for systemd to settle and reports failed units plus the
#                error messages of the current boot.
# @usage       : post_reboot_check @return_var <type> <device>
# @parameter   : $1 | return_var | Receives a short verdict for the summary table
# ==============================================================================
function post_reboot_check {
    local -n return_post_reboot_check="${1#@}"
    local type="$2" device="$3"
    local label report line state="" count_errors=0
    local -a units_failed=() lines_error=()

    label=$(target_label "$type" "$device")

    # POSIX script: boot settle, failed units and boot errors in one round trip;
    # every output line carries a KEY= prefix for parsing below
    report=$(run_script_on_target "$type" "$device" "
        command -v systemctl >/dev/null 2>&1 || { echo STATE=no-systemd; exit 0; }
        echo STATE=\$(timeout ${TIMEOUT_BOOT_SETTLE} systemctl is-system-running --wait 2>/dev/null)
        systemctl --failed --no-legend --plain 2>/dev/null | while read -r unit rest; do echo FAILED=\$unit; done
        echo ERRCOUNT=\$(journalctl -b -p err -q --no-pager 2>/dev/null | wc -l)
        journalctl -b -p err -q --no-pager -o short 2>/dev/null | tail -n ${COUNT_BOOT_ERRORS_SHOWN} | while read -r msg; do echo ERR=\$msg; done
    ")

    # Split the prefixed lines into state, failed units and error messages
    while IFS= read -r line; do
        case "$line" in
            STATE=*)    state="${line#STATE=}" ;;
            FAILED=*)   units_failed+=("${line#FAILED=}") ;;
            ERRCOUNT=*) count_errors="${line#ERRCOUNT=}" ;;
            ERR=*)      lines_error+=("${line#ERR=}") ;;
        esac
    done <<< "$report"

    # No answer at all — the device went away again right after booting
    if [[ -z "$state" ]]; then
        return_post_reboot_check="no answer"
        WARN "[${label}] Post-reboot check got no answer."
        return 1
    fi

    # Alpine & co. have no systemd — nothing further to check
    if [[ "$state" == "no-systemd" ]]; then
        return_post_reboot_check="n/a (no systemd)"
        return 0
    fi

    # Report failed units individually — they are the actionable part
    if (( ${#units_failed[@]} > 0 )); then
        WARN "[${label}] System state '${state}' — failed units: ${units_failed[*]}"
    else
        OK "[${label}] System state '${state}' — no failed units."
    fi

    # Show the newest error messages of this boot so nothing hides in the journal
    if (( count_errors > 0 )); then
        INFO "[${label}] ${count_errors} error message(s) since boot (newest ${#lines_error[@]}):"
        # Dimmed and indented — context for the verdict, not a verdict itself
        for line in "${lines_error[@]}"; do
            printf '    %b%s%b\n' "${FONT_DIM}" "$line" "${FONT_RESET}"
        done
    fi

    return_post_reboot_check="${state}, ${#units_failed[@]} failed, ${count_errors} err"
}

# ==============================================================================
# --- restore_client_power ---
# @desc_short  : Restores the pre-update power state of containers and VMs.
# @desc_detailed: Two directions:
#                 - stop:  clients this run woke that were stopped before
#                 - start: clients that ran before but run nowhere now — a host
#                          reboot takes down every client without onboot/HA restart
# @usage       : restore_client_power @snapshot_before [<type:id>...]
# @parameter   : $1 | snapshot_before | Associative array from snapshot_client_power
# @parameter   : $@ | woken           | "type:id" pairs this run started via --wake-up
# @notes       : Stopping is restricted to clients this run woke — a client the user
#                started by hand during a long run is left alone.
#                Starts go to the host of the snapshot (HA clones exist on both hosts),
#                and only when the client runs nowhere — never a second instance.
# ==============================================================================
function restore_client_power {
    local -n snapshot_restore_client_power="${1#@}"
    shift
    local -a woken=("$@")
    local pair type id host key before_label any_error=0

    # 1. --- Stop clients woken for this run ---------------
    for pair in "${woken[@]}"; do
        type="${pair%%:*}"
        id="${pair#*:}"
        before_label=$(client_power_label @snapshot_restore_client_power "$type" "$id")

        # It ran before (lost only by a host reboot) — must stay up
        [[ "$before_label" == running* ]] && continue

        # Nothing to do when it already stopped on its own
        host=$(client_running_host "$type" "$id")
        [[ -z "$host" ]] && continue

        INFO "[$(target_label "$type" "$id")] Was stopped before the update — shutting down again on ${host}..."
        # pct/qm shutdown is graceful and force-stops after its default timeout
        if _client_power_action "$host" "$type" "$id" "shutdown"; then
            OK "[$(target_label "$type" "$id")] Stopped again."
            observer_log_event "LPEX update: $(target_label "$type" "$id") stopped on ${host} (pre-update state restored)" "OK"
        else
            WARN "[$(target_label "$type" "$id")] Shutdown failed — client stays running."
            any_error=1
        fi
    done

    # 2. --- Restart clients lost by a host reboot ---------------
    for key in "${!snapshot_restore_client_power[@]}"; do
        # Only clients that were running before the update
        [[ "${snapshot_restore_client_power[$key]}" == "running" ]] || continue
        IFS='|' read -r host type id <<< "$key"

        # Running somewhere (incl. HA restart by the observer) — leave it alone
        [[ -n "$(client_running_host "$type" "$id")" ]] && continue

        INFO "[$(target_label "$type" "$id")] Was running before the update — starting again on ${host}..."
        # Start on the snapshot host — obs-wake.sh would pick the first host holding a clone
        if _client_power_action "$host" "$type" "$id" "start"; then
            OK "[$(target_label "$type" "$id")] Running again."
            observer_log_event "LPEX update: $(target_label "$type" "$id") started on ${host} (pre-update state restored)" "OK"
        else
            WARN "[$(target_label "$type" "$id")] Start failed — client stays stopped."
            any_error=1
        fi
    done

    (( any_error )) && return 1
    return 0
}

# --- _client_power_action ---
# @desc_short  : Runs pct/qm start|shutdown for one client on a given host.
# @usage       : _client_power_action <host> <type> <id> <start|shutdown>
# ==============================================================================
function _client_power_action {
    local host="$1" type="$2" id="$3" action="$4"
    local ip user tool="pct"

    # VMs are controlled by qm, containers by pct — same sub-commands
    [[ "$type" == "vm" ]] && tool="qm"
    ip=$(get_device_ip "$host")         || return 1
    user=$(get_device_ssh_user "$host") || return 1

    # Direct SSH — lx cmd does not reliably propagate exit codes
    ssh -n "${SSH_OPTS_POWER[@]}" "${user}@${ip}" "${tool} ${action} ${id}" 2>/dev/null
}

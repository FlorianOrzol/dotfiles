#!/bin/bash
# ==============================================================================
# @meta_module      : server observer logs
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Streams or displays systemd journal logs from an Observer Pi.
# @desc_detailed    : By default, follows the journal in real-time (-f). Use --no-follow
# @desc_detailed    : for a snapshot of the last N lines. Use --since to narrow the
# @desc_detailed    : time range (accepts journalctl time strings like "1h ago" or
# @desc_detailed    : "2026-04-11 03:00:00").
#
# @arg_values       : --node      | Target Observer node (pi1, pi2)
# @arg_values       : --name      | Name of the systemd unit to inspect
# @arg_values       : --lines     | Number of recent lines to show (default: 50 in --no-follow mode)
# @arg_values       : --since     | Show entries since this time (journalctl time string)
# @arg_flags        : --no-follow | Show a snapshot instead of following in real-time
#
# @exit_codes       : 0 | Logs displayed successfully
# @exit_codes       : 1 | Missing argument or SSH failure
#
# @notes            : Follow mode (-f) requires a pseudo-TTY (-t) to stream cleanly.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local service_name="${ARG_NAME[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$node" || -z "$service_name" ]]; then
        output --error "Usage: lpex server observer logs --node <pi> --name <service> [--no-follow] [--lines <n>] [--since <time>]"
        return 1
    fi

    local ip=$(get_observer_ip "$node")

    # Build the journalctl command from the provided options
    local jctl_cmd="journalctl -u $service_name"

    if (( ARG_NO_FOLLOW )); then
        # Snapshot mode: show the last N lines and exit
        local lines="${ARG_LINES[0]:-50}"
        jctl_cmd="$jctl_cmd -n $lines --no-pager"
    else
        # Follow mode: stream live output — requires -t on the SSH side for a clean TTY
        jctl_cmd="$jctl_cmd -f"
    fi

    # [LOGIC] Append --since if provided. journalctl accepts strings like "1 hour ago",
    # "yesterday", or ISO timestamps — pass through verbatim to the remote journalctl.
    if [[ -n "${ARG_SINCE[0]}" ]]; then
        jctl_cmd="$jctl_cmd --since '${ARG_SINCE[0]}'"
    fi

    output --section "Logs: $service_name on $node"
    output --info "$jctl_cmd"

    # [LOGIC] -t is required for follow mode so the remote shell gets a proper TTY,
    # allowing journalctl -f to detect terminal width and stream cleanly. For --no-follow
    # it is harmless but kept for consistency.
    ssh -t "$USER_OBSERVER@$ip" "$jctl_cmd"
}

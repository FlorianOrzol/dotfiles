#!/bin/bash
# ==============================================================================
# @meta_module      : server observer control
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Manages the power state of an Observer Pi via SSH ACPI signals.
# @desc_detailed    : Sends graceful shutdown or reboot commands to an Observer Pi
# @desc_detailed    : using 'sudo shutdown' over SSH. The -t flag ensures sudo
# @desc_detailed    : password prompts are interactive.
# @desc_detailed    : Note: Wake-On-LAN is not applicable for Raspberry Pi hardware.
# @desc_detailed    : To recover an offline Pi, physical access or an external power
# @desc_detailed    : cycle is required.
#
# @arg_values       : --node    | Target Observer node (pi1, pi2)
# @arg_flags        : --stop    | Graceful shutdown (sudo shutdown -h now)
# @arg_flags        : --restart | Graceful reboot (sudo shutdown -r now)
#
# @exit_codes       : 0 | Shutdown/reboot signal dispatched successfully
# @exit_codes       : 1 | Missing argument, IP resolution failure, or SSH error
#
# @notes            : A shutdown will make the Pi unreachable until powered back on.
# @notes            : Prefer --restart for recoverable maintenance operations.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_OBSERVER"

    local node="${ARG_NODE[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    if [[ -z "$node" ]]; then
        output --error "Observer node required (--node)."
        return 1
    fi

    local ip=$(get_observer_ip "$node")

    # ==========================================================================
    # --- Feature: Power State Dispatcher ---
    # ==========================================================================
    if (( ARG_STOP )); then
        output --section "Graceful Shutdown: $node"
        output --warn "This will power off '$node'. It will be unreachable until physically restarted."

        if ! question "Are you sure you want to shut down '$node'?" --default-no; then
            output --info "Shutdown cancelled."
            return 0
        fi

        # [LOGIC] -t allocates a pseudo-TTY for interactive sudo password prompt.
        if lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo shutdown -h now'" --log --log-tags "observer,stop"; then
            output --ok "Shutdown signal dispatched to $node ($ip)."
        else
            output --error "Failed to send shutdown signal."
        fi

    elif (( ARG_RESTART )); then
        output --section "Graceful Reboot: $node"

        if lx cmd --run "ssh -t $USER_OBSERVER@$ip 'sudo shutdown -r now'" --log --log-tags "observer,restart"; then
            output --ok "Reboot signal dispatched to $node ($ip)."
        else
            output --error "Failed to send reboot signal."
        fi

    else
        output --error "No action specified. Use --stop or --restart."
        output --warn  "Note: Wake-On-LAN is not supported for Raspberry Pi hardware."
    fi
}

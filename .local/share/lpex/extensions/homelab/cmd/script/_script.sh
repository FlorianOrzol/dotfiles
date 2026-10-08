#!/bin/bash
# ==============================================================================
# @meta_name        : _script.sh
# @desc_short       : Actions for 'cmd script' — help preview, argument passing, run.
# ==============================================================================

# Own options of 'cmd script' — never passed on to the device script
# (value options consume the following token as well)
declare -ga CMD_SCRIPT_OWN_FLAGS=(--all --sudo --help)
declare -ga CMD_SCRIPT_OWN_VALUES=(--save --description)

# --- _script_show_help ---
# @desc_short  : Prints the script's help from its mirror header — offline, nothing runs.
# @usage       : _script_show_help <mirror_file>
# @notes       : Uses the same renderer as the device (script_helpers.sh → script_help),
#                so the preview equals 'script.sh --help' on the server — also for older
#                scripts that do not source the helpers themselves.
# ==============================================================================
function _script_show_help {
    local file_script="$1"
    local path_mirror file_helpers

    # Mirror root of the device — main.sh already proved it exists
    resolve_device_to_mirror_path "$ARG_DEVICE" @path_mirror || return 1

    # Prefer the device's own copy, any client copy otherwise (hosts/observers have none)
    file_helpers="${path_mirror}/opt/homelab/bin/script_helpers.sh"
    if [[ ! -f "$file_helpers" ]]; then
        file_helpers=$(find "${PATH_EXTENSION_DATA}/mirror" -path '*/opt/homelab/bin/script_helpers.sh' 2>/dev/null | head -1)
    fi

    # Without any renderer the raw header is still better than nothing
    if [[ -z "$file_helpers" ]]; then
        WARN "No script_helpers.sh in any mirror — showing the raw header."
        awk 'NR > 1 && !/^#/ { exit } { print }' "$file_script"
        return 0
    fi

    # script_help reads "$0": bash -c sets $0 to the first argument after the code
    bash -c 'source "$1"; script_help' "$file_script" "$file_helpers"
}

# --- _script_collect_args ---
# @desc_short  : Prints the arguments meant for the device script, %q-quoted.
# @usage       : args=$(_script_collect_args)
# @desc_detailed: Takes ARGS_EXTENSION_ARRAY as typed — order kept, options the
#                 header does not describe are passed on too. Removed: the device
#                 and script tokens (first occurrence) and our own options.
# ==============================================================================
function _script_collect_args {
    local token flag_skip_next=0 flag_device_done=0 flag_script_done=0
    local args_out=""

    # Walk the typed arguments in their original order
    for token in "${ARGS_EXTENSION_ARRAY[@]}"; do
        # Value of one of our own options — consumed together with the option
        if (( flag_skip_next )); then
            flag_skip_next=0
            continue
        fi

        # Device and script are positionals of 'cmd script', not of the script
        if (( ! flag_device_done )) && [[ "$token" == "$ARG_DEVICE" ]]; then
            flag_device_done=1
            continue
        fi
        if (( ! flag_script_done )) && [[ "$token" == "$ARG_SCRIPT" ]]; then
            flag_script_done=1
            continue
        fi

        # Our own flags and value options stay here
        if [[ " ${CMD_SCRIPT_OWN_FLAGS[*]} " == *" ${token} "* ]]; then
            continue
        fi
        if [[ " ${CMD_SCRIPT_OWN_VALUES[*]} " == *" ${token} "* ]]; then
            flag_skip_next=1
            continue
        fi

        # One quoted word per argument — spaces and quotes survive the remote shell
        args_out+=" $(printf '%q' "$token")"
    done

    printf '%s' "$args_out"
}

# --- _script_run ---
# @desc_short  : Builds the call, runs it on the device and saves it on request.
# ==============================================================================
function _script_run {
    local path_remote="/opt/homelab/bin/${ARG_SCRIPT}"
    local prefix="" args cmd_call cmd_remote exit_code

    # sudo only makes sense where we log in unprivileged
    if [[ -n "$ARG_SUDO" ]]; then
        if [[ "$ARG_DEVICE" == observer_* ]]; then
            prefix="sudo "
        else
            WARN "--sudo ignored — ${ARG_DEVICE} runs commands as root already."
        fi
    fi

    args=$(_script_collect_args)
    cmd_call="${prefix}${path_remote}${args}"

    # A script missing on the device means the mirror was not pushed — say how to fix it
    cmd_remote="if [ ! -f ${path_remote} ]; then echo 'ERROR: ${path_remote} not on ${ARG_DEVICE} — run: lpex homelab files --push ${ARG_DEVICE}' >&2; exit 127; fi; ${cmd_call}"

    # Show the real call, not the existence check around it
    INFO "${ARG_DEVICE}: ${cmd_call}"
    EXECUTE_INFO=0

    # Manual runs get a remote terminal — guided scripts can ask
    EXECUTE_INTERACTIVE=1
    execute_on_target "$ARG_DEVICE" "$cmd_remote"
    exit_code=$?

    # Save only what worked — a failing call is no shortcut
    if [[ -n "$ARG_SAVE" ]]; then
        if (( exit_code == 0 )); then
            cmd_save_alias "$ARG_SAVE" "$cmd_call" "${ARG_DESCRIPTION:-}" "$ARG_DEVICE"
        else
            WARN "Script failed (exit ${exit_code}) — not saved as '${ARG_SAVE}'."
        fi
    fi

    return "$exit_code"
}

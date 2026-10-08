#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Runs a saved shortcut on its device(s).
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Resolves the target devices and runs the stored command on each.
# ==============================================================================
function extension_start {
    # Manual runs get a remote terminal — scripts may prompt (e.g. passwords)
    EXECUTE_INTERACTIVE=1

    local -a devices_stored devices_target devices_failed
    local device

    # Alias is required — fzf already offered the list
    if [[ -z "$ARG_ALIAS" ]]; then
        ERROR "No alias specified."
        return 1
    fi

    # Sets ALIAS_RESOLVED and DEVICES_GIVEN — fixes 'cmd alias --device ct_3090 <alias>'
    _resolve_alias_order
    local alias="$ALIAS_RESOLVED"

    # Loads CMD_CMD and CMD_DEVICES
    cmd_read_alias "$alias" || return 1

    # Replace {name} placeholders — from --set or asked
    _fill_placeholders || return 1

    # Devices are stored space-separated — split into an array
    read -ra devices_stored <<< "$CMD_DEVICES"

    # --device narrows the run; without it every stored device is a target
    if (( ${#DEVICES_GIVEN[@]} > 0 )); then
        devices_target=("${DEVICES_GIVEN[@]}")
    else
        devices_target=("${devices_stored[@]}")
    fi

    # A shortcut only runs where it was saved for — anything else is a typo
    for device in "${devices_target[@]}"; do
        if [[ " ${devices_stored[*]} " != *" ${device} "* ]]; then
            ERROR "'${alias}' is not saved for '${device}' (saved for: ${CMD_DEVICES})."
            return 1
        fi
    done

    INFO "${alias}: ${CMD_CMD}"

    # Several devices at once deserve one look before anything runs
    if (( ${#devices_target[@]} > 1 )); then
        question "Run on ${devices_target[*]}?" || return 1
    fi

    # Run device by device and remember failures instead of stopping at the first
    for device in "${devices_target[@]}"; do
        execute_on_target "$device" "$CMD_CMD" || devices_failed+=("$device")
    done

    # Summary only matters when something went wrong
    if (( ${#devices_failed[@]} > 0 )); then
        ERROR "'${alias}' failed on: ${devices_failed[*]}"
        return 1
    fi

    OK "'${alias}' done on ${devices_target[*]}."
}

# --- _resolve_alias_order ---
# @desc_short  : Untangles alias and devices when the alias was typed after --device.
# @notes       : LPEX gives the alias (arg_direct) the FIRST free word, and --device
#                collects EVERY word up to the next flag. 'cmd alias --device ct_3090
#                setup-nodered' therefore arrives as ARG_ALIAS=ct_3090 and
#                ARG_DEVICE=(ct_3090 setup-nodered). When the alias is not saved but
#                one of the device values is, the two are swapped.
#                Results: ALIAS_RESOLVED (scalar), DEVICES_GIVEN (array).
# ==============================================================================
function _resolve_alias_order {
    local value
    local -a devices_rest

    ALIAS_RESOLVED="$ARG_ALIAS"
    DEVICES_GIVEN=("${ARG_DEVICE[@]}")

    # Normal order (alias first) — nothing to untangle
    cmd_alias_exists "$ARG_ALIAS" && return 0

    # Look for the real alias among the device values
    for value in "${ARG_DEVICE[@]}"; do
        # The first value that is a saved alias wins
        if [[ "$ALIAS_RESOLVED" == "$ARG_ALIAS" ]] && cmd_alias_exists "$value"; then
            ALIAS_RESOLVED="$value"
            continue
        fi

        # Every other value stays a device — skip the duplicate of the misread alias
        [[ "$value" != "$ARG_ALIAS" ]] && devices_rest+=("$value")
    done

    # No saved alias among the values — keep the input, cmd_read_alias reports it
    [[ "$ALIAS_RESOLVED" == "$ARG_ALIAS" ]] && return 0

    # The word taken as alias was really a device
    DEVICES_GIVEN=("$ARG_ALIAS" "${devices_rest[@]}")
}

# --- _fill_placeholders ---
# @desc_short  : Replaces every {name} in CMD_CMD with a shell-quoted value.
# @notes       : Values come from --set name=value, missing ones are asked.
#                Each value is inserted %q-quoted, so spaces and quotes in a value
#                cannot change the command. ${VAR} (shell syntax) stays untouched.
# ==============================================================================
function _fill_placeholders {
    local -a names
    local name value entry value_quoted token_shell

    # {name} not preceded by $ — same rule as get_cmd_alias_placeholders
    mapfile -t names < <(grep -oE '(^|[^$])\{[a-z][a-z0-9_]*\}' <<< "$CMD_CMD" \
                         | grep -oE '\{[a-z][a-z0-9_]*\}' | tr -d '{}' | sort -u)

    # A command without placeholders runs as stored
    (( ${#names[@]} == 0 )) && return 0

    for name in "${names[@]}"; do
        value=""

        # --set name=value wins; the last occurrence counts
        for entry in "${ARG_SET[@]}"; do
            [[ "$entry" == "${name}="* ]] && value="${entry#*=}"
        done

        # Not given — ask; an empty answer would leave a broken command
        if [[ -z "$value" ]]; then
            lx input @value --prompt "Value for {${name}}" || return 1
        fi
        if [[ -z "$value" ]]; then
            ERROR "No value for {${name}} — nothing run."
            return 1
        fi

        # Protect ${name} (shell syntax) while {name} is replaced, then restore it.
        # Replacements are quoted: since bash 5.2 an unquoted '&' in the replacement
        # means "the matched text" — the \& from %q would turn into a bare &.
        value_quoted=$(printf '%q' "$value")
        token_shell="__LPEX_SHELL_VAR_${name}__"
        CMD_CMD="${CMD_CMD//\$\{${name}\}/"${token_shell}"}"
        CMD_CMD="${CMD_CMD//\{${name}\}/"${value_quoted}"}"
        CMD_CMD="${CMD_CMD//${token_shell}/\$\{${name}\}}"
    done
}

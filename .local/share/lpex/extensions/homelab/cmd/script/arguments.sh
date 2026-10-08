#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd script'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the fixed arguments and, once the script is known, its options.
# @usage       : lpex homelab cmd script <device> <script> [script options…]
#                                       [--sudo] [--save <alias> [--description <text>]]
#                                       [--all] [--help]
#
# @devices     : <device>      | host_N, observer_N, ct_<id>, vm_<id> (positional)
# @options     : <script>      | Script path below /opt/homelab/bin (positional, from the mirror)
#                --sudo        | Prefix sudo (observers only — they log in as fadmin)
#                --save        | Also save the full call as shortcut (only after success)
#                --description | Description for the saved shortcut (only with --save)
#                --all         | Also list service scripts in the fzf selection (no script given)
#                --help        | Show the script's help from the mirror — nothing runs
# @notes       : The script's own options are registered dynamically from its header
#                (@param_opt / @param_fixed) — completion offers them like built-in ones.
#                Options named like one of ours are skipped (ours win).
# ==============================================================================
function arguments {
    local device_selected script_selected file_script flag_all=""
    local kind name choices desc choice count_pos=0
    local -a options_pos

    # --all decides the script list, which is built before arg_flag @all runs —
    # read it from the raw tokens (runtime) or the typed tokens (completion)
    [[ " ${ARGS_EXTENSION_ARRAY[*]} ${ARGS_ENTERED[*]} " == *" --all "* ]] && flag_all="--all"

    arg_direct @device --description "Target device" --fzf --option-cmd "get_cmd_devices"

    # ARG_DEVICE is not set during completion — the first typed token is the device then
    device_selected="${ARG_DEVICE:-${ARGS_ENTERED[0]}}"
    [[ "$device_selected" == --* ]] && device_selected=""

    # Scripts of this device from its mirror; the device is baked into the command
    # string because --option-cmd runs in a subshell without ARG_*
    arg_direct @script --description "Script below /opt/homelab/bin" --fzf \
        --option-cmd "get_cmd_device_scripts $(printf '%q' "$device_selected") ${flag_all}"

    # Own options after the positionals: completion hides flags while the line
    # still looks like a wrap call, i.e. until the positionals are consumed
    # --all only matters while the script is still to be chosen
    if [[ -z "${ARG_SCRIPT:-}" && ( -z "${ARGS_ENTERED[1]:-}" || "${ARGS_ENTERED[1]}" == --* ) ]]; then
        arg_flag @all --description "Also list service scripts in the fzf selection"
    fi
    arg_flag  @sudo --description "Prefix sudo (observers only)"
    arg_flag  @help --description "Show the script's help from the mirror — nothing runs"
    arg_value @save --description "Save the full call as shortcut (only if it succeeds)"
    arg_value @description --description "Description of the shortcut" --depends-on "ARG_SAVE"

    # The second typed token is the script during completion
    script_selected="${ARG_SCRIPT:-${ARGS_ENTERED[1]}}"
    [[ "$script_selected" == --* ]] && script_selected=""

    # Without a known script there are no script options to offer
    [[ -n "$device_selected" && -n "$script_selected" ]] || return 0
    file_script=$(cmd_script_file "$device_selected" "$script_selected") || return 0

    # One argument per header line: flag, option with value, or positional
    while IFS=$'\x1f' read -r kind name choices desc; do
        # Our own names win — a script option with the same name is not offered
        [[ " all sudo help save description device script " == *" ${name} "* ]] && continue

        # Fixed choices become fzf/completion options
        options_pos=()
        for choice in $choices; do
            options_pos+=(--option "${choice} # ${desc}")
        done

        # Register by kind — names with dashes map to underscores (--restart-test → ARG_RESTART_TEST)
        case "$kind" in
            FLAG)  arg_flag  "@${name//-/_}" --description "$desc" ;;
            VALUE) arg_value "@${name//-/_}" --description "$desc" "${options_pos[@]}" ;;
            POS)
                (( count_pos++ ))
                arg_direct "@script_arg_${count_pos}" --description "$desc" "${options_pos[@]}"
                ;;
        esac
    done < <(cmd_script_header_args "$file_script")
}

#!/bin/bash
# ==============================================================================
# @meta_name        : _summary.sh
# @desc_short       : Result table for 'homelab update' — collects per-target
#                     results during the run and prints them as one table at the
#                     end, so failed or skipped targets cannot drown in the output.
#                     Sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# -g is required: LPEX sources this file inside a function, where a plain declare
# would create locals that vanish before extension_start runs.
# ==============================================================================
declare -ga SUMMARY_ORDER=()        # target labels in processing order
declare -gA SUMMARY_BEFORE=()       # label → power state before the run
declare -gA SUMMARY_UPDATE=()       # label → update result
declare -gA SUMMARY_REBOOT=()       # label → reboot result
declare -gA SUMMARY_CHECK=()        # label → post-reboot check verdict
declare -gA SUMMARY_AFTER=()        # label → power state after the run

# ==============================================================================
# --- target_label ---
# @desc_short  : Prints the user-facing name of a target (host_1, ct_3040, vm_101).
# @usage       : target_label <type> <device>
# ==============================================================================
function target_label {
    local type="$1" device="$2"

    # Clients are addressed by prefixed ID, nodes by their plain name
    case "$type" in
        container) echo "ct_${device}" ;;
        vm)        echo "vm_${device}" ;;
        *)         echo "$device" ;;
    esac
}

# --- summary_add ---
# @desc_short  : Registers a target with its pre-update power state.
# @usage       : summary_add <label> <before>
# ==============================================================================
function summary_add {
    local label="$1" before="$2"

    SUMMARY_ORDER+=("$label")
    SUMMARY_BEFORE["$label"]="$before"
    # Defaults — overwritten as soon as the step for this target has run
    SUMMARY_UPDATE["$label"]="not run"
    SUMMARY_REBOOT["$label"]="-"
    SUMMARY_CHECK["$label"]="-"
    SUMMARY_AFTER["$label"]="-"
}

# --- summary_fill_after ---
# @desc_short  : Records the power state of every target after the run.
# @usage       : summary_fill_after <type:device>...
# @notes       : One fresh client snapshot instead of per-client lookups — offline
#                hosts would otherwise cost an SSH timeout per client.
# ==============================================================================
function summary_fill_after {
    local -a targets=("$@")
    local -A snapshot_after=()
    local target type device label

    snapshot_client_power @snapshot_after

    # Nodes are probed by ping, clients looked up in the snapshot
    for target in "${targets[@]}"; do
        type="${target%%:*}"
        device="${target#*:}"
        label=$(target_label "$type" "$device")
        case "$type" in
            host|observer) device_is_online "$device" && SUMMARY_AFTER["$label"]="online" || SUMMARY_AFTER["$label"]="offline" ;;
            *)             SUMMARY_AFTER["$label"]=$(client_power_label @snapshot_after "$type" "$device") ;;
        esac
    done
}

# --- summary_print ---
# @desc_short  : Prints the collected results as a colored table.
# @usage       : summary_print
# ==============================================================================
function summary_print {
    local label

    lx output --section "Update Summary"
    # Header line — same column widths as the rows below
    printf '%b  %-12s %-18s %-20s %-16s %-30s %s%b\n' "${FONT_BOLD}" \
        "DEVICE" "BEFORE" "UPDATE" "REBOOT" "POST-REBOOT CHECK" "AFTER" "${FONT_RESET}"

    # One row per target — color is applied per cell after padding so widths stay intact
    for label in "${SUMMARY_ORDER[@]}"; do
        printf "  %-12s %s %s %s %s %s\n" "$label" \
            "$(_summary_cell 18 "${SUMMARY_BEFORE[$label]}")" \
            "$(_summary_cell 20 "${SUMMARY_UPDATE[$label]}")" \
            "$(_summary_cell 16 "${SUMMARY_REBOOT[$label]}")" \
            "$(_summary_cell 30 "${SUMMARY_CHECK[$label]}")" \
            "$(_summary_cell 0  "${SUMMARY_AFTER[$label]}")"
    done
}

# --- _summary_cell ---
# @desc_short  : Pads a value to a width and colors it by its meaning.
# @usage       : _summary_cell <width> <value>
# ==============================================================================
function _summary_cell {
    local width="$1" value="$2"
    local color=""

    # Red: something needs attention; yellow: deviation worth a look; green: fine
    case "$value" in
        FAILED*|TIMEOUT*|"no answer"|*degraded*|unknown) color="$FONT_RED" ;;
        skipped*|"no script"|"not run"|*starting*)         color="$FONT_YELLOW" ;;
        ok|done*|online|running*)                          color="$FONT_GREEN" ;;
        -|stopped|offline|"not needed"|dry-run)            color="$FONT_DIM" ;;
    esac

    printf '%b%-*s%b' "$color" "$width" "$value" "$FONT_RESET"
}

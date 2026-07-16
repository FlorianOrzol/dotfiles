#!/bin/bash
# ==============================================================================
# @meta_name        : _list.sh
# @desc_short       : Boot order display for the 'ha' submodule.
#                     Sourced by ha/main.sh.
# ==============================================================================

# --- action_list ---
# @desc_short  : Prints the HA client list in boot order with live status and override info.
# @desc_detailed: Position = start order after a host reboot (watcher starts top to bottom).
#                 Name/status come from the leader's lxc-live.txt; the HA column shows
#                 'override' when an ha_override.json pauses the container's HA.
# @usage       : action_list
# ==============================================================================
function action_list {
    local -a ha_list
    _ha_read_list @ha_list || return 1

    # Empty list is a valid state — nothing is HA-managed yet
    if (( ${#ha_list[@]} == 0 )); then
        WARN "No HA clients configured — add one with: lpex homelab ha --add <id>"
        return 0
    fi

    lx output --section "HA Boot Order"

    # Header row — POS is the boot position the watcher starts containers in
    printf '%b\n' "${FONT_BOLD}  POS  CT-ID      NAME                 STATUS     HA${FONT_RESET}"

    local pos=1 id name status ha_state color_status color_ha file_override expires
    for id in "${ha_list[@]}"; do
        name="-"; status="unknown"

        # Resolve name/status from the leader's live file ("<id> # <name> - <status>")
        if [[ -f "$FILE_CONTAINER_LIVE" ]]; then
            read -r name status < <(awk -v id="$id" '$1==id {print $3, $5}' "$FILE_CONTAINER_LIVE")
            name="${name:--}"; status="${status:-unknown}"
        fi

        # Determine HA override state from the share (same file the watcher checks)
        ha_state="on"
        file_override="${PATH_SHARE_STATE}/clients/${id}/ha_override.json"
        if [[ -f "$file_override" ]]; then
            expires=$(jq -r '.expires_unix // empty' "$file_override" 2>/dev/null)
            # Permanent override without expiry vs. temporary one with timestamp
            if [[ -z "$expires" ]]; then
                ha_state="override (manual)"
            else
                ha_state="override (until $(date -d "@${expires}" '+%d.%m. %H:%M'))"
            fi
        fi

        # Color coding: running=green, stopped=red, override=yellow
        color_status="$FONT_RED"
        [[ "$status" == "running" ]] && color_status="$FONT_GREEN"
        color_ha=""
        [[ "$ha_state" != "on" ]] && color_ha="$FONT_YELLOW"

        printf '  %-4s %-10s %-20s %b%-10s%b %b%s%b\n' \
            "$pos" "$id" "$name" \
            "$color_status" "$status" "$FONT_RESET" \
            "$color_ha" "$ha_state" "$FONT_RESET"
        (( pos++ ))
    done

    # Hint at the data source so stale info is explainable
    if [[ ! -f "$FILE_CONTAINER_LIVE" ]]; then
        WARN "lxc-live.txt not readable — names/statuses unavailable (share unmounted?)."
    fi
}

#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/conf_push.sh
# @desc_short       : Add or remove a container from the conf_targets list of a host.
#                     Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_conf_push ---
# @desc_short   : Updates CONF_TARGETS_HOST_X in the settings table and
#                 regenerates + pushes homelab.conf automatically on change.
# ==============================================================================
function action_conf_push {
    local ctid="$ARG_ID"
    local mode="$ARG_CONF_PUSH"

    # Validate that only "on" or "off" was passed as the mode value
    if [[ "$mode" != "on" && "$mode" != "off" ]]; then
        ERROR "Invalid value for --conf-push: '${mode}'. Allowed: on | off."
        return 1
    fi

    # Resolve host — use ARG_HOST if given (e.g. during --create), else auto-detect
    local host_id="${ARG_HOST:-}"
    # If no host was explicitly provided, look up which host currently runs the container
    if [[ -z "$host_id" ]]; then
        host_id=$(host_for_container "$ctid") || {
            ERROR "Host for container ${ctid} not found. Use --host to specify it."
            return 1
        }
    fi

    # Ensure the settings table exists before any read or write
    lx db --file "homelab_conf.db" --table "settings" --create-table \
        --cols "key TEXT PRIMARY KEY, value TEXT NOT NULL"

    local ct_key="CONF_TARGETS_HOST_${host_id}"
    local esc_key="${ct_key//\'/\'\'}"   # escape key for SQL

    # Read the current space-separated container ID list for this host
    local -a current_row=()
    lx db --file "homelab_conf.db" --table "settings" --select @current_row \
        --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
    local current_val="${current_row[0]:-}"

    # Split the current value string into an array of individual container IDs
    read -ra current_ids <<< "$current_val"

    if [[ "$mode" == "on" ]]; then
        # Check if the container is already registered to avoid duplicates
        local already_present=0
        for id in "${current_ids[@]}"; do
            [[ "$id" == "$ctid" ]] && already_present=1 && break
        done
        (( already_present == 0 )) && current_ids+=("$ctid")   # append only if not already present
        local new_val="${current_ids[*]}"
        local esc_val="${new_val//\'/\'\'}"
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR REPLACE INTO settings(key,value) VALUES('${esc_key}','${esc_val}');"
        OK "Container ${ctid} added to conf_targets of host_${host_id}."
    else
        # Remove the container id from the list by rebuilding without it
        local -a new_ids=()
        for id in "${current_ids[@]}"; do
            [[ "$id" != "$ctid" ]] && new_ids+=("$id")   # keep all IDs except the removed one
        done
        local new_val="${new_ids[*]}"
        local esc_val="${new_val//\'/\'\'}"
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR REPLACE INTO settings(key,value) VALUES('${esc_key}','${esc_val}');"
        OK "Container ${ctid} removed from conf_targets of host_${host_id}."
    fi

    # Regenerate and push homelab.conf to reflect the updated conf_targets
    INFO "Regenerating and deploying homelab.conf..."
    lx homelab config push
}

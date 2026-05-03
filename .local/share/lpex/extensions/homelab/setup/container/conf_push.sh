#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/conf_push.sh
# @desc_short       : Container in conf_targets des Hosts ein-/austragen.
#                     Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_conf_push ---
# @desc_short   : Adds or removes the container from conf_targets in the DB.
#                 Regenerates and pushes homelab.conf automatically on change.
# ==============================================================================
function action_conf_push {
    local ctid="$ARG_ID"
    local mode="$ARG_CONF_PUSH"

    if [[ "$mode" != "on" && "$mode" != "off" ]]; then
        ERROR "Ungültiger Wert für --conf-push: '${mode}'. Erlaubt: on | off."
        return 1
    fi

    # Resolve host — use ARG_HOST if given (e.g. during --create), else auto-detect
    local host_id="${ARG_HOST:-}"
    if [[ -z "$host_id" ]]; then
        host_id=$(host_for_container "$ctid") || {
            ERROR "Host für Container ${ctid} nicht gefunden. Ggf. --host angeben."
            return 1
        }
    fi

    # Ensure conf_targets table exists
    lx db --file "homelab_conf.db" --exec \
        "CREATE TABLE IF NOT EXISTS conf_targets (id INTEGER PRIMARY KEY AUTOINCREMENT, host_id INTEGER NOT NULL, container_id INTEGER NOT NULL, UNIQUE(host_id, container_id));"

    if [[ "$mode" == "on" ]]; then
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR IGNORE INTO conf_targets (host_id, container_id) VALUES (${host_id}, ${ctid});"
        OK "Container ${ctid} in conf_targets von host_${host_id} aufgenommen."
    else
        lx db --file "homelab_conf.db" --exec \
            "DELETE FROM conf_targets WHERE host_id=${host_id} AND container_id=${ctid};"
        OK "Container ${ctid} aus conf_targets von host_${host_id} entfernt."
    fi

    # Regenerate and push homelab.conf via config submodule
    INFO "Generiere und deploye homelab.conf..."
    lx homelab config push
}

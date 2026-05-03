#!/bin/bash
# ==============================================================================
# @meta_name        : config/fetch/main.sh
# @desc_short       : homelab.conf von observer_1 zurückholen (Recovery).
# ==============================================================================

function extension_start {
    local obs_ip
    obs_ip=$(device_ip "observer" "1") || return 1
    local mirror_conf="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"

    INFO "Hole homelab.conf von observer_1 (${obs_ip})..."

    mkdir -p "$(dirname "$mirror_conf")"
    scp "${_SSH_OPTS[@]}" \
        "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" \
        "$mirror_conf" || return 1

    # Lokale config.conf ebenfalls aktualisieren
    cp "$mirror_conf" "${PATH_HOMELAB_DATA}/config.conf"

    OK "homelab.conf zurückgeholt → ${mirror_conf}"
    WARN "DB wurde NICHT aktualisiert — nur die Datei wurde wiederhergestellt."
}

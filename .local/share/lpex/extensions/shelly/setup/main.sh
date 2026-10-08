#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Sets up a new Shelly that runs its own access point.
# @desc_detailed    : wlan0 joins the Shelly AP (192.168.33.1), the device gets name,
#                     profile (cloud, MQTT incl. broker account, login) and finally the
#                     home WLAN with static IP or DHCP. wlan0 leaves the AP, the device
#                     is awaited in the LAN and added to the inventory.
#                     Order matters: everything else first, WLAN last — afterwards the
#                     device is gone from 192.168.33.1.
# ==============================================================================

# Action file — LPEX does not auto-load _*.sh, always via $PATH_EXTENSION
source "${PATH_EXTENSION}/_setup.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Runs the setup steps; wlan0 is restored on every exit path.
# @notes       : No 'trap RETURN' — it would fire after every called function.
# ==============================================================================
function extension_start {
    local exit_code

    shelly_db_init

    # Values that do not need the device are checked before any network change
    _setup_validate || return 1

    # Ctrl-C mid-setup must not leave wlan0 on the Shelly access point
    trap '_setup_wifi_down; exit 130' INT

    _setup_access_point_part
    exit_code=$?
    _setup_wifi_down
    trap - INT
    (( exit_code == 0 )) || return 1

    _setup_await_lan || return 1
    _setup_finish
}

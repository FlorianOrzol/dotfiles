#!/bin/bash
# ==============================================================================
# @meta_name        : variables.sh
# @desc_short       : Loads config.conf and exposes shared path variables.
#                     Sourced automatically by LPEX before arguments() and
#                     extension_start() for every homelab submodule.
# ==============================================================================

# Load extension config — defines MOUNT_POOL_FAST, PATH_SHARE_STATE, IPs, etc.
_CONFIG_FILE="${PATH_EXTENSION_DATA}/config.conf"
if [[ -f "$_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$_CONFIG_FILE"
fi

# Path to the extension data directory (convenience alias)
PATH_HOMELAB_DATA="${PATH_EXTENSION_DATA}"

# Source lib/devices.sh — SSH routing helpers used by all submodules
_LIB_DEVICES="${PATH_EXTENSION_SOURCE}/homelab/lib/devices.sh"
if [[ -f "$_LIB_DEVICES" ]]; then
    # shellcheck source=/dev/null
    source "$_LIB_DEVICES"
fi

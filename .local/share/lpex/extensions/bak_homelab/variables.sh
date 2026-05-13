#!/bin/bash
# ==============================================================================
# @meta_name        : variables.sh
# @desc_short       : Sourced in Phase 3 (path traversal). PATH_EXTENSION_DATA is
#                     not yet available here — config.conf is loaded by LPEX in
#                     Phase 4. PATH_HOMELAB_DATA is set in extension_global.sh.
# ==============================================================================

# Load homelab.conf — defines all IPs, paths, SSH users, and helper functions
_CONFIG_FILE="${PATH_EXTENSION_DATA}/config.conf"
if [[ -f "$_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$_CONFIG_FILE"
fi

# PATH_HOMELAB_DATA is set in extension_global.sh (Phase 4, after PATH_EXTENSION_DATA is available)

#!/bin/bash
# ==============================================================================
# @meta_name        : _common.sh
# @desc_short       : Mirror-path parsing for all files actions.
# @notes            : resolve_device_to_mirror_path, get_client_mirror_dir and
#                     _is_unified_mirror_type live in extension_global.sh (shared with cmd script).
#                     Sourced unconditionally by files/main.sh.
# ==============================================================================

# ==============================================================================
# --- parse_mirror_path ---
# @desc_short  : Extracts device type, device name, and remote path from a local
#                mirror path. Used by all action functions in this submodule.
# @usage       : parse_mirror_path <local_path> <nameref_type> <nameref_device> <nameref_remote>
# @parameter   : $1 | local_path     | Full local mirror path
# @parameter   : $2 | nameref_type   | Variable name to receive the device type
# @parameter   : $3 | nameref_device | Variable name to receive the device name (empty for unified types)
# @parameter   : $4 | nameref_remote | Variable name to receive the remote path
# @notes       : Unified types (host, observer): mirror/<type>/remote/path — no device subdir.
#                Per-device types (ct, vm):       mirror/client/<type>/<id>/remote/path.
#                Returns remote="/" when the path points to the mirror base directory.
# ==============================================================================
function parse_mirror_path {
    local full_path="$1"
    local -n _pmp_type="$2"
    local -n _pmp_device="$3"
    local -n _pmp_remote="$4"
    local mirror_root="${PATH_EXTENSION_DATA}/mirror/"

    # Strip the mirror root prefix to obtain the relative path.
    local rel="${full_path#"$mirror_root"}"

    # First path component is the device type (e.g. "host", "container").
    _pmp_type="${rel%%/*}"
    rel="${rel#"${_pmp_type}"}"
    rel="${rel#/}"  # strip separator between type and next component

    # "client" is a grouping prefix — extract the subtype (ct/vm) as the effective type.
    if [[ "$_pmp_type" == "client" ]]; then
        _pmp_type="${rel%%/*}"  # subtype: "ct" or "vm"
        rel="${rel#"${_pmp_type}"}"
        rel="${rel#/}"
    fi

    # Unified types have no device subdirectory — the rest of the path IS the remote path.
    if _is_unified_mirror_type "$_pmp_type"; then
        _pmp_device=""  # device is not encoded in path; caller must supply it externally
        if [[ -n "$rel" ]]; then
            _pmp_remote="/${rel}"
        else
            _pmp_remote="/"
        fi
        return
    fi

    # Per-device types: second path component is the device name or ID.
    _pmp_device="${rel%%/*}"
    rel="${rel#"${_pmp_device}"}"
    rel="${rel#/}"  # strip separator between device and remote path

    # Remaining string is the remote path — prepend slash, or use "/" if empty.
    if [[ -n "$rel" ]]; then
        _pmp_remote="/${rel}"
    else
        # Path points to the mirror base directory itself — remote root.
        _pmp_remote="/"
    fi
}


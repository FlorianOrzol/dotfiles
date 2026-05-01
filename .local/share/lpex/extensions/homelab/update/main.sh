#!/bin/bash
# ==============================================================================
# @meta_name        : update/main.sh
# @desc_short       : Entry point for the update submodule — validates and routes.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/_run.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short   : Validates arguments, then routes to single or bulk update.
# ==============================================================================
function extension_start {
    local dry_run=0 patches=0
    (( ARG_DRY_RUN )) && dry_run=1
    (( ARG_PATCHES )) && patches=1

    # Determine whether a single device or a bulk flag was provided
    local has_device=0 has_bulk=0

    _validate_device 2>/dev/null && has_device=1

    [[ -n "$ARG_ALL" || -n "$ARG_ALL_OBSERVERS" || \
       -n "$ARG_ALL_HOSTS" || -n "$ARG_ALL_CLIENTS" ]] && has_bulk=1

    # Require exactly one mode: specific device OR bulk flag
    if (( !has_device && !has_bulk )); then
        ERROR "Specify a device (--host, --observer, --container, --vm) or a bulk flag (--all, --all-hosts, ...)."
        return 1
    fi

    if (( has_device && has_bulk )); then
        ERROR "Cannot combine a specific device with a bulk flag."
        return 1
    fi

    # --- Single device --------------------------------------------------------
    if (( has_device )); then
        _update_device "$_DEVICE_TYPE" "$_DEVICE_ID" "$dry_run" "$patches"
        return $?
    fi

    # --- Bulk update ----------------------------------------------------------
    local any_error=0

    # --all: observers first, then hosts (sequentially to avoid split-brain risk)
    if [[ -n "$ARG_ALL" ]]; then
        _update_all_observers "$dry_run" "$patches" || any_error=1
        _update_all_hosts     "$dry_run" "$patches" || any_error=1
        (( any_error )) && return 1
        return 0
    fi

    # --all-observers
    if [[ -n "$ARG_ALL_OBSERVERS" ]]; then
        _update_all_observers "$dry_run" "$patches"
        return $?
    fi

    # --all-hosts
    if [[ -n "$ARG_ALL_HOSTS" ]]; then
        _update_all_hosts "$dry_run" "$patches"
        return $?
    fi

    # --all-clients
    if [[ -n "$ARG_ALL_CLIENTS" ]]; then
        _update_all_clients "$dry_run" "$patches"
        return $?
    fi
}

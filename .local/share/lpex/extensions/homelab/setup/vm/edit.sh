#!/bin/bash
# ==============================================================================
# @meta_name        : setup/vm/edit.sh
# @desc_short       : VM-Konfiguration ändern und anzeigen.
#                     Sourced by setup/vm/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_edit ---
# @desc_short   : Edits the configuration of an existing VM.
#                 Disk size can only be increased. ID cannot be changed.
# ==============================================================================
function action_edit {
    local host_id
    host_id=$(host_for_vm "$ARG_ID") || return 1

    local qm_args=()
    [[ -n "$ARG_NAME" ]]     && qm_args+=( --name     "$ARG_NAME" )
    [[ -n "$ARG_RAM" ]]      && qm_args+=( --memory   "$ARG_RAM" )
    [[ -n "$ARG_CPU" ]]      && qm_args+=( --cores    "$ARG_CPU" )
    [[ -n "$ARG_MAX_CPU" ]]  && qm_args+=( --cpulimit "$ARG_MAX_CPU" )
    [[ -n "$ARG_MACHINE" ]]  && qm_args+=( --machine  "$ARG_MACHINE" )
    [[ -n "$ARG_BIOS" ]]     && qm_args+=( --bios     "$ARG_BIOS" )
    [[ -n "$ARG_OS_TYPE" ]]  && qm_args+=( --ostype   "$ARG_OS_TYPE" )
    [[ -n "$ARG_BRIDGE" ]]   && qm_args+=( --net0     "virtio,bridge=$ARG_BRIDGE" )
    [[ -n "$ARG_AUTOSTART" ]] && qm_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )
    [[ -n "$ARG_BALLOON" ]]  && qm_args+=( --balloon "$([[ $ARG_BALLOON == yes ]] && echo 1 || echo 0)" )
    [[ -n "$ARG_AGENT" ]]    && qm_args+=( --agent   "$([[ $ARG_AGENT   == yes ]] && echo 1 || echo 0)" )

    if (( ${#qm_args[@]} == 0 )) && [[ -z "$ARG_DISK" ]]; then
        WARN "No options provided — nothing to edit."
        return 1
    fi

    INFO "Editing VM vm-${ARG_ID} on host ${host_id}..."

    if (( ${#qm_args[@]} > 0 )); then
        run_on_host "$host_id" "qm set ${ARG_ID} ${qm_args[*]}" || return 1
    fi

    # Resize disk separately — qm resize only allows increasing disk size
    if [[ -n "$ARG_DISK" ]]; then
        INFO "Resizing disk to ${ARG_DISK}G..."
        run_on_host "$host_id" "qm resize ${ARG_ID} scsi0 ${ARG_DISK}G" || return 1
    fi

    OK "VM vm-${ARG_ID} updated."
}

# ==============================================================================
# --- action_show_config ---
# @desc_short   : Displays the current qm configuration of a VM.
# ==============================================================================
function action_show_config {
    local host_id
    host_id=$(host_for_vm "$ARG_ID") || return 1

    INFO "Fetching config for VM vm-${ARG_ID}..."
    run_on_host "$host_id" "qm config ${ARG_ID}"
}

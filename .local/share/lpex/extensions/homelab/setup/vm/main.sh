#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Main execution logic for the setup vm submodule.
# ==============================================================================

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# ==============================================================================
function extension_start {
    # 1. --- Validate ID ---------------
    if [[ -z "$ARG_ID" ]]; then
        ERROR "No VM ID specified."
        return 1
    fi

    # 2. --- Validate Action ---------------
    local action_count=0
    [[ -n "$ARG_CREATE" ]]      && (( action_count++ ))
    [[ -n "$ARG_DELETE" ]]      && (( action_count++ ))
    [[ -n "$ARG_EDIT" ]]        && (( action_count++ ))
    [[ -n "$ARG_SHOW_CONFIG" ]] && (( action_count++ ))

    if (( action_count == 0 )); then
        ERROR "No action specified. Provide --create, --delete, --edit, or --show-config."
        return 1
    fi

    if (( action_count > 1 )); then
        ERROR "Only one action allowed at a time."
        return 1
    fi

    # 3. --- Action Routing ---------------
    if [[ -n "$ARG_CREATE" ]];      then _action_create;      fi
    if [[ -n "$ARG_DELETE" ]];      then _action_delete;      fi
    if [[ -n "$ARG_EDIT" ]];        then _action_edit;        fi
    if [[ -n "$ARG_SHOW_CONFIG" ]]; then _action_show_config; fi
}

# ==============================================================================
# --- function _action_create ---
# @desc_short       : Creates a new VM on the target host.
# ==============================================================================
function _action_create {
    # Required fields
    local missing=()
    [[ -z "$ARG_HOST" ]] && missing+=("--host")
    [[ -z "$ARG_ISO" ]]  && missing+=("--iso")
    [[ -z "$ARG_RAM" ]]  && missing+=("--ram")
    [[ -z "$ARG_DISK" ]] && missing+=("--disk")

    if (( ${#missing[@]} > 0 )); then
        ERROR "Missing required options: ${missing[*]}"
        return 1
    fi

    INFO "Creating VM $ARG_ID on host $ARG_HOST..."

    local qm_args=()
    qm_args+=( "$ARG_ID" )
    qm_args+=( --name    "${ARG_NAME:-vm-$ARG_ID}" )
    qm_args+=( --memory  "$ARG_RAM" )
    qm_args+=( --cores   "${ARG_CPU:-2}" )
    qm_args+=( --cpulimit "${ARG_MAX_CPU:-100}" )
    qm_args+=( --cdrom   "$ARG_ISO" )
    qm_args+=( --machine "${ARG_MACHINE:-q35}" )
    qm_args+=( --bios    "${ARG_BIOS:-ovmf}" )
    qm_args+=( --ostype  "${ARG_OS_TYPE:-l26}" )
    qm_args+=( --net0    "virtio,bridge=${ARG_BRIDGE:-vmbr0}" )
    qm_args+=( --agent   "$([[ "${ARG_AGENT:-yes}" == "yes" ]] && echo 1 || echo 0)" )
    qm_args+=( --balloon "$([[ "${ARG_BALLOON:-yes}" == "yes" ]] && echo 1 || echo 0)" )

    [[ -n "$ARG_AUTOSTART" ]] && qm_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    # Placeholder: create disk separately after VM creation
    # ssh observer "ssh host_X 'qm create ${qm_args[*]} && qm set $ARG_ID --scsi0 ${ARG_STORAGE:-fastpool}:${ARG_DISK}'"

    INFO "qm create ${qm_args[*]}"

    # Cloud-init network config (if IP provided)
    if [[ -n "$ARG_IP_ADDRESS" ]]; then
        INFO "Setting cloud-init network: ip=$ARG_IP_ADDRESS${ARG_GATEWAY:+,gw=$ARG_GATEWAY}..."
        # Placeholder: ssh observer "ssh host_X 'qm set $ARG_ID --ipconfig0 ip=$ARG_IP_ADDRESS,gw=$ARG_GATEWAY'"
    fi

    # HA enrollment after creation
    if [[ "$ARG_HA" == "yes" ]]; then
        INFO "Adding vm-$ARG_ID to HA..."
        # Placeholder: ssh observer "ssh host_X 'ha-manager add vm:$ARG_ID'"
    fi

    # Backup job assignment
    if [[ -n "$ARG_AUTO_BACKUP" ]]; then
        INFO "Assigning backup job $ARG_AUTO_BACKUP to vm-$ARG_ID..."
        # Placeholder: assign backup job via pvesh
    fi

    OK "VM vm-$ARG_ID created."
}

# ==============================================================================
# --- function _action_delete ---
# @desc_short       : Deletes a VM on the target host.
# ==============================================================================
function _action_delete {
    WARN "This will permanently delete VM vm-$ARG_ID."

    # Placeholder: ssh observer "ssh host_X 'qm stop $ARG_ID; qm destroy $ARG_ID'"

    OK "VM vm-$ARG_ID deleted."
}

# ==============================================================================
# --- function _action_edit ---
# @desc_short       : Edits the configuration of an existing VM.
#                     Disk size can only be increased. ID cannot be changed.
# ==============================================================================
function _action_edit {
    INFO "Editing VM vm-$ARG_ID..."

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

    [[ -n "$ARG_BALLOON" ]] && qm_args+=( --balloon "$([[ $ARG_BALLOON == yes ]] && echo 1 || echo 0)" )
    [[ -n "$ARG_AGENT" ]]   && qm_args+=( --agent   "$([[ $ARG_AGENT   == yes ]] && echo 1 || echo 0)" )

    # Disk resize (only increase — validated at execution time by qm)
    if [[ -n "$ARG_DISK" ]]; then
        INFO "Resizing disk to ${ARG_DISK}G..."
        # Placeholder: ssh observer "ssh host_X 'qm resize $ARG_ID scsi0 ${ARG_DISK}G'"
    fi

    if (( ${#qm_args[@]} > 0 )); then
        # Placeholder: ssh observer "ssh host_X 'qm set $ARG_ID ${qm_args[*]}'"
        INFO "qm set $ARG_ID ${qm_args[*]}"
    else
        WARN "No options provided — nothing to edit."
        return 1
    fi

    OK "VM vm-$ARG_ID updated."
}

# ==============================================================================
# --- function _action_show_config ---
# @desc_short       : Displays the current configuration of a VM.
# ==============================================================================
function _action_show_config {
    INFO "Fetching config for VM vm-$ARG_ID..."

    # Placeholder: ssh observer "ssh host_X 'qm config $ARG_ID'"

    OK "Config displayed."
}

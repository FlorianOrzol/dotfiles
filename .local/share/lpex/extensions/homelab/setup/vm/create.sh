#!/bin/bash
# ==============================================================================
# @meta_name        : setup/vm/create.sh
# @desc_short       : VM-Erstellung via qm. Sourced by setup/vm/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_create ---
# @desc_short   : Creates a new VM on the target host via qm.
# ==============================================================================
function action_create {
    local missing=()
    [[ -z "$ARG_HOST" ]] && missing+=("--host")
    [[ -z "$ARG_ISO" ]]  && missing+=("--iso")
    [[ -z "$ARG_RAM" ]]  && missing+=("--ram")
    [[ -z "$ARG_DISK" ]] && missing+=("--disk")

    if (( ${#missing[@]} > 0 )); then
        ERROR "Missing required options: ${missing[*]}"
        return 1
    fi

    local qm_args=()
    qm_args+=( "$ARG_ID" )
    qm_args+=( --name     "${ARG_NAME:-vm-$ARG_ID}" )
    qm_args+=( --memory   "$ARG_RAM" )
    qm_args+=( --cores    "${ARG_CPU:-2}" )
    qm_args+=( --cpulimit "${ARG_MAX_CPU:-100}" )
    qm_args+=( --cdrom    "$ARG_ISO" )
    qm_args+=( --machine  "${ARG_MACHINE:-q35}" )
    qm_args+=( --bios     "${ARG_BIOS:-ovmf}" )
    qm_args+=( --ostype   "${ARG_OS_TYPE:-l26}" )
    qm_args+=( --net0     "virtio,bridge=${ARG_BRIDGE:-vmbr0}" )
    qm_args+=( --agent    "$([[ "${ARG_AGENT:-yes}" == "yes" ]] && echo 1 || echo 0)" )
    qm_args+=( --balloon  "$([[ "${ARG_BALLOON:-yes}" == "yes" ]] && echo 1 || echo 0)" )
    [[ -n "$ARG_AUTOSTART" ]] && qm_args+=( --onboot "$([[ $ARG_AUTOSTART == on ]] && echo 1 || echo 0)" )

    INFO "Creating VM ${ARG_ID} on host ${ARG_HOST}..."

    # Create the VM, then attach the disk separately
    run_on_host "$ARG_HOST" \
        "qm create ${qm_args[*]} && \
         qm set ${ARG_ID} --scsi0 ${ARG_STORAGE:-fastpool}:${ARG_DISK}" || return 1

    if [[ -n "$ARG_IP_ADDRESS" ]]; then
        INFO "Setting cloud-init network: ip=${ARG_IP_ADDRESS}${ARG_GATEWAY:+,gw=$ARG_GATEWAY}..."
        run_on_host "$ARG_HOST" \
            "qm set ${ARG_ID} --ipconfig0 ip=${ARG_IP_ADDRESS}${ARG_GATEWAY:+,gw=$ARG_GATEWAY}" || true
    fi

    if [[ "$ARG_HA" == "yes" ]]; then
        INFO "Adding vm-${ARG_ID} to HA..."
        run_on_host "$ARG_HOST" "ha-manager add vm:${ARG_ID}" || true
    fi

    if [[ -n "$ARG_AUTO_BACKUP" ]]; then
        INFO "Assigning backup job ${ARG_AUTO_BACKUP} to vm-${ARG_ID}..."
        run_on_host "$ARG_HOST" "pvesh set /cluster/backup/${ARG_AUTO_BACKUP} --vmid ${ARG_ID}" || true
    fi

    OK "VM vm-${ARG_ID} created."
}

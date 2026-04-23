#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines the CLI arguments for the control submodule.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for device power control and HA-Override.
# @usage            : lpex homelab control <device> <id> [actions] [ha-override]
#
# @devices          : --host | --container | --vm | --pi
# @actions          : --start | --stop | --restart
# @ha-override      : --mode  (maintenance | testing | disabled | safe-restart)
#                     --time  (only with --mode, e.g. 2h, 30m, 1d)
#                     --clear (cancel active override)
# ==============================================================================
function arguments {
    # 1. --- Devices ---------------
    # ------ Mutually exclusive options for target selection.

    arg_value @host --description "Target host (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @container --description "Target container (e.g., 1111)" \
        --option-cmd "cat '$FILE_CONTAINER_LIVE' 2>/dev/null"

    arg_value @vm --description "Target VM (e.g., 1111)" \
        --option-cmd "cat '$FILE_VM_LIVE' 2>/dev/null"

    arg_value @observer --description "Target Observer / Raspberry Pi (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    # 2. --- Actions ---------------
    # ------ Power control flags (mutually exclusive by nature).

    arg_flag @start   --description "Start the device"
    arg_flag @stop    --description "Stop the device"
    arg_flag @restart --description "Restart the device"

    # 3. --- HA-Override ---------------
    # ------ Combinable with actions OR usable standalone.

    arg_value @mode --description "Activate HA-Override mode" --fzf \
        --option "maintenance # Wartungsmodus, HA pausiert" \
        --option "testing # Testmodus, HA pausiert" \
        --option "disabled # HA dauerhaft deaktiviert (kein Timer)" \
        --option "safe-restart # Einmaliger Neustart ohne HA-Alarm"

    arg_value @time --description "Duration of the override (e.g. 2h, 30m, 1d) — without --time: manual clear required" \
        --depends-on "ARG_MODE"

    arg_flag @clear --description "Cancel active HA-Override immediately, restore HA"
}

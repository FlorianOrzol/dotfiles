#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the state refresh submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab state refresh [--devices <target...>] [--wake-up]
#
# @devices          : --devices | Groups and/or single devices, freely mixed:
#                       all       → observers → hosts → clients
#                       hosts     → all configured hosts
#                       observers → all configured observers
#                       clients   → all containers and VMs (live via pct/qm on the hosts)
#                       host_1, observer_1, ct_3040, vm_101 → single devices
#                     Omitted → every device that answers a ping.
#
# @options          : --wake-up | Start offline targets before collecting, then
#                                 restore their previous power state. Without it
#                                 an offline device is skipped, never started.
# ==============================================================================
function arguments {
    # 1. --- Device Selection --------------------------------------------------
    # Optional — without it extension_start sweeps every reachable device.
    # Completion mirrors the update submodule: groups, configured nodes, mirrored clients.
    arg_value @devices \
        --description "Target group(s) and/or device(s) — omit for every reachable device" \
        --multi \
        --option "all # observers → hosts → clients (everything)" \
        --option "hosts # all configured hosts" \
        --option "observers # all configured observers" \
        --option "clients # all containers and VMs (live from hosts)" \
        --option-cmd "
            { get_hosts    | awk '{print \$1}';
              get_observers | awk '{print \$1}';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"

    # 2. --- Modifiers -----------------------------------------------------------
    # Waking is opt-in and explicit — a plain refresh must never power a device on.
    arg_flag @wake_up --description "Start offline targets first, then restore their power state" \
        --depends-on "ARG_DEVICES"
}

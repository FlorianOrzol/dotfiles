#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the update submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab update --devices <target...> [options]
#
# @devices          : --devices | Groups and/or single devices, freely mixed:
#                       all       → observers → hosts → clients (sequential)
#                       hosts     → all configured hosts
#                       observers → all configured observers
#                       clients   → all containers and VMs (live via pct/qm on the hosts)
#                       host_1, observer_1, ct_3040, vm_101 → single devices
#
# @options          : --dry-run      | Show upgradable packages only — no actual update
#                     --wake-up      | Wake/start offline targets before updating
#                     --reboot       | Reboot each target after its update when apt
#                                      demands it (delayed on the device, see
#                                      REBOOT_DELAY_MINUTES in update-os.sh)
#                     --reboot-force | Reboot each target after its update
#                                      unconditionally (wins over --reboot)
#                     --status-refresh     | Refresh the status of the updated
#                                            devices on the share. This is the
#                                            default already — passing it also
#                                            refreshes during a --dry-run.
#                     --status-refresh-all | Widen the refresh to every device
#                                            that answers a ping. Offline devices
#                                            are skipped, never woken — use
#                                            --wake-up when they should come up.
#
# @notes            : Patches (apply-patches.sh) sind hier bewusst NICHT mehr
#                     angebunden — sie gehören zum geplanten Submodul 'setup patches'.
# ==============================================================================
function arguments {
    # 1. --- Device Selection --------------------------------------------------
    # Groups are expanded in extension_start. Completion lists groups, configured
    # nodes and mirrored clients — no --fzf, values come from fish completion.
    arg_value @devices \
        --description "Target group(s) and/or device(s) (all, hosts, ct_3040, ...)" \
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
    # Modifiers apply to all selected targets; completion shows them after --devices.
    arg_flag @dry_run --description "Show upgradable packages only — no actual update" \
        --depends-on "ARG_DEVICES"
    arg_flag @wake_up --description "Wake/start offline targets before updating" \
        --depends-on "ARG_DEVICES"
    arg_flag @reboot --description "Reboot targets after the update when apt demands it" \
        --depends-on "ARG_DEVICES"
    arg_flag @reboot_force --description "Reboot targets after the update unconditionally" \
        --depends-on "ARG_DEVICES"

    # 3. --- Status Refresh ------------------------------------------------------
    # Scope of the post-update status refresh. Neither flag ever wakes a device —
    # that stays the sole job of --wake-up.
    arg_flag @status_refresh --description "Refresh status of the updated devices (default; also during --dry-run)" \
        --depends-on "ARG_DEVICES"
    arg_flag @status_refresh_all --description "Refresh status of every reachable device, not just the updated ones" \
        --depends-on "ARG_DEVICES"
}

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
# @options          : --dry-run  | Show upgradable packages only — no actual update
#                     --wake-up  | Wake/start offline targets before updating
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
}

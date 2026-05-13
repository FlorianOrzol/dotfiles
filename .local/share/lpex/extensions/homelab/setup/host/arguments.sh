#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the setup/host submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab setup host --host <name(s)> <action> [--force]
#
# @devices          : --host (multi)
# @actions          : --init | --ssh-keys | --dirs | --scripts | --node-name | --homelab-conf | --units
# @options          : --force
#
# @notes            : --init runs all steps in sequence (1–6).
#                     Individual flags run only that single step — useful for re-applying
#                     a specific step without touching the rest.
#                     --force skips idempotency checks — re-applies the selected step(s).
#                     --multi allows running the same action on several hosts in sequence.
# ==============================================================================
function arguments {
    # 1. --- Device Selection -----------------------------------------------
    # --multi allows running the same action on several hosts in one call.
    # No --fzf — selection from completion list is sufficient.
    arg_value @host --multi \
        --description "Host(s) to act on" \
        --option-cmd "get_hosts"

    # 2. --- Actions --------------------------------------------------------

    # --init runs all six steps in order — the standard first-time setup.
    arg_flag @init \
        --description "Run full host initialization (all 6 steps in sequence)"

    # Individual step flags — each runs exactly one init step.
    arg_flag @ssh-keys \
        --description "Step 1: deploy SSH keys (desktop + observer keys)"
    arg_flag @dirs \
        --description "Step 2: create /opt/homelab directory structure"
    arg_flag @scripts \
        --description "Step 3: push scripts from local mirror to host via tar stream"
    arg_flag @node-name \
        --description "Step 4: write logical device name to state file"
    arg_flag @homelab-conf \
        --description "Step 5: trigger observer to distribute homelab.conf to host"
    arg_flag @units \
        --description "Step 6: generate systemd units from templates on host"

    # 3. --- Options --------------------------------------------------------
    arg_flag @force \
        --description "Skip idempotency checks and re-apply the selected step(s)"
}

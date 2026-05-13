#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the setup/ssh-keys submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab setup ssh-keys [--host | --observer] <action> [--force]
#
# @devices          : --host | --observer  (both: --multi)
# @actions          : --deploy | --known-hosts
# @options          : --force
#
# @notes            : Physical nodes only (hosts + observers).
#                     Clients (container/vm) self-initialize SSH via ct-ssh-init.sh
#                     on first start — no manual key setup needed for them.
#
#                     --deploy      : Observer deploys private key + sets up
#                                     authorized_keys_homelab + sshd_config.d snippet.
#                                     First run requires one-time password auth.
#
#                     --known-hosts : Observer populates known_hosts on device with
#                                     fingerprints of all physical nodes.
#
#                     --force       : Skip idempotency checks — re-apply unconditionally.
# ==============================================================================
function arguments {
    # 1. --- Device Selection -----------------------------------------------
    # Physical nodes only — clients self-initialize SSH via init script.
    # --multi allows acting on several devices in one call. No --fzf needed.

    arg_value @host --multi \
        --description "Host(s) to act on" \
        --option-cmd "get_hosts"

    arg_value @observer --multi \
        --description "Observer(s) to act on" \
        --option-cmd "get_observers"

    # 2. --- Actions --------------------------------------------------------

    # --deploy: full key setup via observer (key pair + authorized_keys + sshd).
    arg_flag @deploy \
        --description "Deploy SSH keys for device via observer (key pair + authorized_keys)"

    # --known-hosts: populate known_hosts with fingerprints of all physical nodes.
    arg_flag @known-hosts \
        --description "Populate known_hosts on device(s) with all physical node fingerprints"

    # 3. --- Options --------------------------------------------------------

    # --force: re-apply unconditionally, e.g. after key rotation or hardware replacement.
    arg_flag @force \
        --description "Skip idempotency checks — re-apply unconditionally"
}

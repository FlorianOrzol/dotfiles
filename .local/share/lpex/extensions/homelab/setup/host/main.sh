#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates arguments and routes to host setup actions.
# ==============================================================================

source "${PATH_EXTENSION}/_init.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates host and action arguments, then runs the requested
#                action on each selected host.
# @notes       : Exactly one action flag must be given. --init runs all steps;
#                individual flags (--ssh-keys … --units) run a single step only.
# ==============================================================================
function extension_start {
    local any_error=0

    # Require at least one host — nothing to act on otherwise.
    if (( ${#ARG_HOST[@]} == 0 )); then
        ERROR "No host specified. Use --host <name>."
        return 1
    fi

    # Require at least one action flag — concatenate all to check in one step.
    if [[ -z "${ARG_INIT}${ARG_SSH_KEYS}${ARG_DIRS}${ARG_SCRIPTS}${ARG_NODE_NAME}${ARG_HOMELAB_CONF}${ARG_UNITS}" ]]; then
        ERROR "No action specified. Use --init or any step flag (--ssh-keys, --dirs, --scripts, --node-name, --homelab-conf, --units)."
        return 1
    fi

    # Iterate all selected hosts and run the flagged action(s) on each.
    # Multiple flags are allowed — steps run in logical order (1 → 6).
    for host in "${ARG_HOST[@]}"; do
        # --init runs all six steps — individual flags run only their step.
        [[ -n "$ARG_INIT" ]]         && { action_init         "$host" "$ARG_FORCE" || any_error=1; }
        [[ -n "$ARG_SSH_KEYS" ]]     && { action_ssh_keys     "$host" "$ARG_FORCE" || any_error=1; }
        [[ -n "$ARG_DIRS" ]]         && { action_dirs         "$host"              || any_error=1; }
        [[ -n "$ARG_SCRIPTS" ]]      && { action_scripts      "$host"              || any_error=1; }
        [[ -n "$ARG_NODE_NAME" ]]    && { action_node_name    "$host"              || any_error=1; }
        [[ -n "$ARG_HOMELAB_CONF" ]] && { action_homelab_conf "$host" "$ARG_FORCE" || any_error=1; }
        [[ -n "$ARG_UNITS" ]]        && { action_units        "$host"              || any_error=1; }
    done

    # Propagate failure if any action on any host failed.
    (( any_error )) && return 1
    return 0
}

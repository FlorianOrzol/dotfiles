#!/bin/bash
# ==============================================================================
# @meta_name        : _targets.sh
# @desc_short       : Target expansion for the update submodule — resolves groups
#                     (all, hosts, observers, clients) and single device names
#                     into "type:device" pairs. Sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS_LIST="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"    # non-interactive SSH for list queries

# ==============================================================================
# --- collect_targets ---
# @desc_short  : Expands groups and device names into deduplicated "type:device"
#                pairs. Group 'all' expands to observers → hosts → clients so
#                the update order matches the deployment order.
# @usage       : collect_targets @nameref_targets <input...>
# @parameter   : $1 | nameref_targets | Array variable to receive the target pairs
# @parameter   : $@ | inputs          | Groups and/or device names from --devices
# ==============================================================================
function collect_targets {
    local -n return_collect_targets="${1#@}"
    shift
    local inputs=("$@")
    local input

    return_collect_targets=()

    # Map each input to its target pairs — groups expand via list helpers.
    for input in "${inputs[@]}"; do
        case "$input" in
            all)        _targets_append @return_collect_targets "$(_list_observers; _list_hosts; _list_clients)" ;;
            hosts)      _targets_append @return_collect_targets "$(_list_hosts)" ;;
            observers)  _targets_append @return_collect_targets "$(_list_observers)" ;;
            clients)    _targets_append @return_collect_targets "$(_list_clients)" ;;
            host_*)     return_collect_targets+=("host:${input}") ;;
            observer_*) return_collect_targets+=("observer:${input}") ;;
            ct_*)       return_collect_targets+=("container:${input#ct_}") ;;
            vm_*)       return_collect_targets+=("vm:${input#vm_}") ;;
            *)  ERROR "Unknown device or group: '${input}' — expected all, hosts, observers, clients, host_*, observer_*, ct_*, or vm_*"
                return 1 ;;
        esac
    done

    # Mixed input like "hosts host_1" may produce duplicates — keep first occurrence.
    _targets_dedupe @return_collect_targets

    # Abort when nothing was resolved — e.g. 'clients' with all hosts offline.
    if (( ${#return_collect_targets[@]} == 0 )); then
        ERROR "No targets resolved from: ${inputs[*]}"
        return 1
    fi
}

# --- _targets_append ---
# @desc_short  : Appends newline-separated target pairs to the nameref array.
# @parameter   : $1 | nameref_list | Array variable to append to
# @parameter   : $2 | lines        | Newline-separated "type:device" pairs
# ==============================================================================
function _targets_append {
    local -n _ta_list="${1#@}"
    local lines="$2"
    local line

    # Append each non-empty line as one target pair.
    while IFS= read -r line; do
        [[ -n "$line" ]] && _ta_list+=("$line")
    done <<< "$lines"
}

# --- _targets_dedupe ---
# @desc_short  : Removes duplicate entries from the nameref array, keeping order.
# @parameter   : $1 | nameref_list | Array variable to deduplicate in place
# ==============================================================================
function _targets_dedupe {
    local -n _td_list="${1#@}"
    local -a unique=()
    local entry

    # Keep the first occurrence of every entry — preserves the update order.
    for entry in "${_td_list[@]}"; do
        [[ " ${unique[*]} " == *" ${entry} "* ]] || unique+=("$entry")
    done
    _td_list=("${unique[@]}")
}

# --- _list_hosts ---
# @desc_short  : Prints all configured hosts as "host:<name>", one per line.
# ==============================================================================
function _list_hosts {
    # Names come from config — first column of get_hosts ("name # ip").
    get_hosts | awk '{print "host:"$1}'
}

# --- _list_observers ---
# @desc_short  : Prints all configured observers as "observer:<name>", one per line.
# ==============================================================================
function _list_observers {
    # Names come from config — first column of get_observers ("name # ip (role)").
    get_observers | awk '{print "observer:"$1}'
}

# --- _list_clients ---
# @desc_short  : Prints all containers and VMs as "container:<id>" / "vm:<id>".
# @notes       : Queried live via pct/qm on every reachable host — authoritative
#                and independent of the NFS live lists (includes stopped clients).
#                Offline hosts are skipped silently (BatchMode SSH fails fast).
#                Runs inside $(...) — must not print anything except target pairs.
# ==============================================================================
function _list_clients {
    local host ip user

    # Query each configured host for its containers and VMs.
    while IFS= read -r host; do
        # Resolve connection details — skip host on config errors.
        ip=$(get_device_ip "$host" 2>/dev/null)         || continue
        user=$(get_device_ssh_user "$host" 2>/dev/null) || continue

        # pct/qm list all clients regardless of state — NR>1 skips the header line.
        ssh ${SSH_OPTS_LIST} "${user}@${ip}" \
            "pct list 2>/dev/null | awk 'NR>1{print \"container:\"\$1}';
             qm  list 2>/dev/null | awk 'NR>1{print \"vm:\"\$1}'" 2>/dev/null
    done < <(get_hosts | awk '{print $1}')
}

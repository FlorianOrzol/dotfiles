function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local active_host
    active_host=$(get_active_host)
    
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"

    # Fallback to interactive selection if no ID was provided
    if [[ -z "$ctid" ]]; then
        local fzf_list
        fzf_list=$(eval "$(get_lxc_completion_cmd)")
        lx fzf @ctid --list "$fzf_list" --prompt "Select Container > " --return-first-word || return 1
    fi

    output --info "Attaching to Container $ctid on $active_host..."
    
    # Execute raw SSH to allocate a TTY (-t) and hand over control to the user.
    ssh -t root@"$active_host" "pct enter $ctid"
}

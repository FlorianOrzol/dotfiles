function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local remote_file="${ARG_REMOTE_FILE[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$ctid" || -z "$remote_file" ]]; then
        output --error "Usage: lpex server container fetch --ctid <ID> --remote-file <path>"
        return 1
    fi

    local payload_dir=$(ensure_payload_dir "configs" "container" "$ctid")
    local file_name=$(basename "$remote_file")
    local local_dest="$payload_dir/$file_name"
    local tmp_host_path="/tmp/lpex_fetch_${ctid}_${file_name}"

    output --section "Fetching $remote_file from CT $ctid"
    output --info "1. Extracting from Container (pct pull)..."
    if ! lx cmd --run "ssh root@$active_host 'pct pull $ctid \"$remote_file\" \"$tmp_host_path\"'" --quiet --error-msg "pct pull failed (File might not exist)"; then
        return 1
    fi

    output --info "2. Downloading to Desktop..."
    if ! lx cmd --run "rsync -avz root@$active_host:\"$tmp_host_path\" \"$local_dest\"" --quiet --error-msg "Rsync download failed"; then
        return 1
    fi

    lx cmd --run "ssh root@$active_host 'rm -f \"$tmp_host_path\"'" --quiet
    output --ok "File saved to: $local_dest"
}

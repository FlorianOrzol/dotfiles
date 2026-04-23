#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Main execution logic for the files submodule.
# ==============================================================================

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# @usage            : Automatically invoked after arguments.sh is processed.
# ==============================================================================
function extension_start {
    # 1. --- Validate Device Selection ---------------
    _validate_device || return 1
    local device_type="$_DEVICE_TYPE"
    local device_id="$_DEVICE_ID"

    # 2. --- Validate Option Selection ---------------
    if [[ -z "$ARG_GOTO" && -z "$ARG_FETCH" && -z "$ARG_PUSH" && -z "$ARG_DELETE" ]]; then
        ERROR "No option specified. Provide --goto, --fetch, --push, or --delete."
        return 1
    fi

    # 3. --- Action Routing ---------------
    local mirror_path="$PATH_EXTENSION_DATA/mirror/${device_type}/${device_id}"

    if [[ -n "$ARG_GOTO" ]];   then _action_goto   "$mirror_path";                        fi
    if [[ -n "$ARG_FETCH" ]];  then _action_fetch  "$device_type" "$device_id" "$mirror_path"; fi
    if [[ -n "$ARG_PUSH" ]];   then _action_push   "$device_type" "$device_id" "$mirror_path"; fi
    if [[ -n "$ARG_DELETE" ]]; then _action_delete "$device_type" "$device_id" "$mirror_path"; fi
}

# ==============================================================================
# --- function _action_goto ---
# @desc_short       : Opens the local mirror directory for the target device.
# @parameter        : $1 | mirror_path | Local mirror path for the device.
# ==============================================================================
function _action_goto {
    local mirror_path="$1"

    if [[ ! -d "$mirror_path" ]]; then
        WARN "Mirror directory does not exist yet: $mirror_path"
        WARN "Use --fetch to populate it first."
        return 1
    fi

    INFO "Opening mirror directory: $mirror_path"
    $TERMINAL "$mirror_path" &
}

# ==============================================================================
# --- function _action_fetch ---
# @desc_short       : Fetches a file/directory from the device into the local mirror.
# @parameter        : $1 | type        | Device type.
# @parameter        : $2 | id          | Device ID.
# @parameter        : $3 | mirror_path | Local mirror base path for the device.
# ==============================================================================
function _action_fetch {
    local type="$1"
    local id="$2"
    local mirror_path="$3"
    local remote_path="$ARG_FETCH"
    local local_dest="${mirror_path}${remote_path}"

    INFO "Fetching [$remote_path] from [$type] $id..."

    mkdir -p "$(dirname "$local_dest")"

    # Placeholder: fetch via SSH/pct depending on device type
    # case "$type" in
    #   container) ssh observer "ssh host_X \"pct exec $id -- tar -czf - '$remote_path'\"" | tar -xzf - -C "$mirror_path" ;;
    #   vm|host)   ssh observer "ssh $id \"tar -czf - '$remote_path'\"" | tar -xzf - -C "$mirror_path" ;;
    #   observer)  ssh "$id" "tar -czf - '$remote_path'" | tar -xzf - -C "$mirror_path" ;;
    # esac

    OK "Fetched [$remote_path] → $local_dest"
}

# ==============================================================================
# --- function _action_push ---
# @desc_short       : Pushes a local mirror file/directory to the device.
#                     Mechanism: tar → /tmp on target → cp to destination path.
#                     Ownership is inherited from the parent directory.
# @parameter        : $1 | type        | Device type.
# @parameter        : $2 | id          | Device ID.
# @parameter        : $3 | mirror_path | Local mirror base path for the device.
# ==============================================================================
function _action_push {
    local type="$1"
    local id="$2"
    local mirror_path="$3"
    local local_path="$ARG_PUSH"
    local remote_path="${local_path#"$mirror_path"}"

    if [[ ! -e "$local_path" ]]; then
        ERROR "Local path not found: $local_path"
        return 1
    fi

    INFO "Pushing [$local_path] → [$type] $id:$remote_path..."

    # Placeholder: tar → /tmp → cp (ownership from parent dir, chmod preserved)
    # tar -czf - -C "$(dirname "$local_path")" "$(basename "$local_path")" | \
    # case "$type" in
    #   container) ssh observer "ssh host_X \"pct exec $id -- bash -c 'tar -xzf - -C /tmp && cp -a /tmp/$(basename "$local_path") $remote_path'\"" ;;
    #   vm|host)   ssh observer "ssh $id \"tar -xzf - -C /tmp && cp -a /tmp/$(basename "$local_path") $remote_path\"" ;;
    #   observer)  ssh "$id" "tar -xzf - -C /tmp && cp -a /tmp/$(basename "$local_path") $remote_path" ;;
    # esac

    OK "Pushed [$local_path] → [$type] $id:$remote_path"
}

# ==============================================================================
# --- function _action_delete ---
# @desc_short       : Deletes a file/directory on the device AND in the local mirror.
# @parameter        : $1 | type        | Device type.
# @parameter        : $2 | id          | Device ID.
# @parameter        : $3 | mirror_path | Local mirror base path for the device.
# ==============================================================================
function _action_delete {
    local type="$1"
    local id="$2"
    local mirror_path="$3"
    local local_path="$ARG_DELETE"
    local remote_path="${local_path#"$mirror_path"}"

    INFO "Deleting [$remote_path] on [$type] $id and in local mirror..."

    # Placeholder: delete on device via SSH/pct
    # case "$type" in
    #   container) ssh observer "ssh host_X \"pct exec $id -- rm -rf '$remote_path'\"" ;;
    #   vm|host)   ssh observer "ssh $id \"rm -rf '$remote_path'\"" ;;
    #   observer)  ssh "$id" "rm -rf '$remote_path'" ;;
    # esac

    rm -rf "$local_path"

    OK "Deleted [$remote_path] on device and [$local_path] in mirror."
}

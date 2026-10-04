#!/bin/bash
# ==============================================================================
# @meta_name        : _edit.sh
# @desc_short       : Edit actions for 'cmd edit' — options, editor and store.
# @notes            : Works on the globals EDIT_ALIAS, EDIT_CMD, EDIT_DESCRIPTION
#                     and EDIT_DEVICES, filled from the stored row first.
# ==============================================================================

# --- _edit_load_current ---
# @desc_short  : Copies the stored values into the EDIT_* globals.
# ==============================================================================
function _edit_load_current {
    EDIT_ALIAS="$ARG_ALIAS"
    EDIT_CMD="$CMD_CMD"
    EDIT_DESCRIPTION="$CMD_DESCRIPTION"

    # Devices are stored space-separated — split into an array
    read -ra EDIT_DEVICES <<< "$CMD_DEVICES"
}

# --- _edit_apply_options ---
# @desc_short  : Applies --new-alias, --cmd, --description, --add/--remove-device.
# ==============================================================================
function _edit_apply_options {
    local device
    local -a devices_kept

    # Scalar fields: an option replaces the stored value
    [[ -n "$ARG_NEW_ALIAS" ]]   && EDIT_ALIAS="$ARG_NEW_ALIAS"
    [[ -n "${ARG_CMD[*]}" ]]    && EDIT_CMD="${ARG_CMD[*]}"
    [[ -n "$ARG_DESCRIPTION" ]] && EDIT_DESCRIPTION="$ARG_DESCRIPTION"

    # Add devices that are not stored yet — duplicates would run twice
    for device in "${ARG_ADD_DEVICE[@]}"; do
        if [[ " ${EDIT_DEVICES[*]} " != *" ${device} "* ]]; then
            EDIT_DEVICES+=("$device")
        fi
    done

    # Removing an unknown device is a typo, not a no-op
    for device in "${ARG_REMOVE_DEVICE[@]}"; do
        if [[ " ${EDIT_DEVICES[*]} " != *" ${device} "* ]]; then
            ERROR "'${EDIT_ALIAS}' is not saved for '${device}'."
            return 1
        fi
    done

    # Keep every device that is not on the remove list
    for device in "${EDIT_DEVICES[@]}"; do
        if [[ " ${ARG_REMOVE_DEVICE[*]} " != *" ${device} "* ]]; then
            devices_kept+=("$device")
        fi
    done
    EDIT_DEVICES=("${devices_kept[@]}")

    # A shortcut without device cannot run — deleting it is 'cmd delete'
    if (( ${#EDIT_DEVICES[@]} == 0 )); then
        ERROR "At least one device must remain — to remove '${ARG_ALIAS}' use 'lpex homelab cmd delete'."
        return 1
    fi
}

# --- _edit_in_editor ---
# @desc_short  : Opens the whole entry in $EDITOR and parses the result.
# @notes       : 'cmd:' comes last and takes every following line verbatim —
#                multi-line commands and lines starting with '#' stay intact.
# ==============================================================================
function _edit_in_editor {
    local file_tmp line key value flag_in_cmd=0
    local -a lines_cmd

    file_tmp=$(mktemp /tmp/lpex_cmd_edit.XXXXXX)

    # Template: header comments, then the fields, the command as last block
    cat > "$file_tmp" <<EOF
# lpex homelab cmd edit — save and close to apply.
# Lines starting with '#' above 'cmd:' are ignored.
# devices: space-separated — host_N, observer_N, ct_<id>, vm_<id>
# cmd: everything below the 'cmd:' line, multi-line allowed.
alias: ${EDIT_ALIAS}
devices: ${EDIT_DEVICES[*]}
description: ${EDIT_DESCRIPTION}
cmd:
${EDIT_CMD}
EOF

    # A failing editor (e.g. :cq in vim) means "do not apply"
    if ! "${EDITOR:-vi}" "$file_tmp"; then
        rm -f "$file_tmp"
        ERROR "Editor aborted — shortcut unchanged."
        return 1
    fi

    # Parse field lines until 'cmd:', then collect the command block
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Inside the command block every line belongs to the command
        if (( flag_in_cmd )); then
            lines_cmd+=("$line")
            continue
        fi

        # Comments and blank lines only exist above the command block
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue

        key="${line%%:*}"
        value="${line#*:}"
        value="${value# }"              # drop the single space after the colon

        # Map each key to its field — the command starts on the next line
        case "$key" in
            alias)       EDIT_ALIAS="$value" ;;
            devices)     read -ra EDIT_DEVICES <<< "$value" ;;
            description) EDIT_DESCRIPTION="$value" ;;
            cmd)         flag_in_cmd=1 ;;
            *)
                rm -f "$file_tmp"
                ERROR "Unknown line in editor: '${line}' — shortcut unchanged."
                return 1
                ;;
        esac
    done < "$file_tmp"
    rm -f "$file_tmp"

    # Join the block; trailing empty lines from the editor are dropped
    EDIT_CMD=$(printf '%s\n' "${lines_cmd[@]}")
    EDIT_CMD="${EDIT_CMD%"${EDIT_CMD##*[![:space:]]}"}"
}

# --- _edit_store ---
# @desc_short  : Validates the EDIT_* values and writes them in one update.
# ==============================================================================
function _edit_store {
    local id_other

    # Same checks as for a new shortcut
    cmd_validate_alias "$EDIT_ALIAS"          || return 1
    cmd_validate_devices "${EDIT_DEVICES[@]}" || return 1

    # An empty command would turn the shortcut into a no-op
    if [[ -z "$EDIT_CMD" ]]; then
        ERROR "Command must not be empty — shortcut unchanged."
        return 1
    fi

    # Nothing differs from the stored row — no write, no noise
    if [[ "$EDIT_ALIAS" == "$ARG_ALIAS" && "$EDIT_CMD" == "$CMD_CMD" \
          && "$EDIT_DESCRIPTION" == "$CMD_DESCRIPTION" && "${EDIT_DEVICES[*]}" == "$CMD_DEVICES" ]]; then
        INFO "No changes."
        return 0
    fi

    # A rename must not collide with another shortcut
    if [[ "$EDIT_ALIAS" != "$ARG_ALIAS" ]]; then
        lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select @id_other \
            --cols "id" --where "alias='${EDIT_ALIAS//\'/\'\'}'" --limit 1
        if [[ -n "$id_other" ]]; then
            ERROR "Alias '${EDIT_ALIAS}' already exists — shortcut unchanged."
            return 1
        fi
    fi

    # One update by id — the alias itself may be part of the change.
    # --where BEFORE --data: older lx db versions swallowed a flag following --data
    # and ran the UPDATE on every row.
    if ! lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --update \
            --where "id=${CMD_ID}" \
            --data "alias" "$EDIT_ALIAS" "cmd" "$EDIT_CMD" \
                   "devices" "${EDIT_DEVICES[*]}" "description" "$EDIT_DESCRIPTION"; then
        ERROR "Update of '${ARG_ALIAS}' failed — shortcut unchanged."
        return 1
    fi

    OK "Updated '${EDIT_ALIAS}': ${EDIT_DEVICES[*]} — ${EDIT_CMD}"
}

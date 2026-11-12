#!/bin/bash
# ==============================================================================
# @meta_name        : _service.sh
# @desc_short       : Service actions: status, logs, restart, update.
#                     Sourced by main.sh.
# ==============================================================================

# --- _claude_action_status ---
# @desc_short  : Runs claude-status.sh in the container.
# ==============================================================================
function _claude_action_status {
    # The script needs root for the service and disk checks
    claude_ssh sudo "$FILE_CLAUDE_STATUS_SCRIPT"
}

# --- _claude_action_logs ---
# @desc_short  : Shows the journal of both services, optionally following it.
# ==============================================================================
function _claude_action_logs {
    local unit
    local -a journal_args=(sudo journalctl --no-pager -o short-iso)

    # One -u per service — both journals interleaved by time
    for unit in $NAME_SERVICES_CLAUDE; do
        journal_args+=(-u "$unit")
    done

    # Follow needs a terminal so Ctrl+C reaches journalctl in the container
    if (( ${ARG_FOLLOW:-0} )); then
        claude_ssh -t "${journal_args[@]}" -n "$LINES_CLAUDE_LOG" -f
    else
        claude_ssh "${journal_args[@]}" -n "$LINES_CLAUDE_LOG"
    fi
}

# --- _claude_action_restart ---
# @desc_short  : Restarts both services after confirmation.
# ==============================================================================
function _claude_action_restart {
    # Changes something and ends sessions — always asked (lx cmd convention)
    lx cmd --run "ssh ${USER_CLAUDE}@${IP_CLAUDE} sudo systemctl restart ${NAME_SERVICES_CLAUDE}" \
        --title "Restart claude-tmux and claude-remote" \
        --note  "Open sessions end; the main session resumes the same conversation" \
        --note  "Sessions opened in the app (server mode) are gone" \
        --confirm --log --log-tags "claude,restart"
}

# --- _claude_action_update ---
# @desc_short  : Updates the claude binary, then restarts both services.
# @notes       : Running processes keep the old binary until restarted.
# ==============================================================================
function _claude_action_update {
    # Update and restart in one confirmed step — an update without restart has no effect
    lx cmd --run "ssh ${USER_CLAUDE}@${IP_CLAUDE} '${FILE_CLAUDE_BINARY} update && sudo systemctl restart ${NAME_SERVICES_CLAUDE}'" \
        --title "Update Claude Code in CT 30100 and restart both services" \
        --note  "Open sessions end; the main session resumes the same conversation" \
        --confirm --log --log-tags "claude,update"
}

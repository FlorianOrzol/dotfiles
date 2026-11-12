#!/bin/bash
# ==============================================================================
# @meta_name        : _session.sh
# @desc_short       : Interactive access: main session in tmux, plain shell.
#                     Sourced by main.sh.
# ==============================================================================

# --- _claude_action_attach ---
# @desc_short  : Attaches to the tmux session holding the main claude session.
# @notes       : Detach with Ctrl+b, d — claude keeps running. Never /exit:
#                systemd brings it back after 10 s, but detaching is the way.
# ==============================================================================
function _claude_action_attach {
    local -a tmux_args=(tmux attach-session -t "$NAME_TMUX_SESSION")

    # -r: read-only client — for watching an agent at work without interfering
    if (( ${ARG_READ_ONLY:-0} )); then
        tmux_args+=(-r)
    fi

    INFO "Main session on ${IP_CLAUDE} — detach: Ctrl+b, then d"
    # A missing session usually means the service is restarting or not signed in
    if ! claude_ssh -t "${tmux_args[@]}"; then
        ERROR "Attach failed — check with: lpex claude status"
        return 1
    fi
}

# --- _claude_action_shell ---
# @desc_short  : Opens a plain login shell in the container as claude.
# ==============================================================================
function _claude_action_shell {
    INFO "Shell on ${IP_CLAUDE} as ${USER_CLAUDE} (sudo without password)"
    claude_ssh -t
}

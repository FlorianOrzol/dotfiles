#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 0.1.0
# @meta_date        : 2026-11-09
#
# @desc_short       : Connection data of the claude container and the ssh helper.
# @desc_detailed    : All actions run over ssh as the user claude (key login,
# @desc_detailed    : sudo without password). Values mirror claude.conf in the
# @desc_detailed    : container mirror (ct/30100/opt/homelab/bin/claude/).
# ==============================================================================

# ==============================================================================
# --- User Configuration ---
# Wrapped in a function with declare -g: the completion engine sources this file
# inside a function, plain declarations would turn local there.
# ==============================================================================
function _claude_globals {
    declare -g IP_CLAUDE="10.0.30.100"                  # CT 30100 on host_1
    declare -g USER_CLAUDE="claude"                     # ssh user, sudo NOPASSWD
    declare -g NAME_TMUX_SESSION="claude"               # tmux session of claude-tmux.service
    declare -g NAME_SERVICES_CLAUDE="claude-tmux claude-remote"   # main session + server mode
    declare -g FILE_CLAUDE_BINARY="/home/claude/.local/bin/claude"         # native binary
    declare -g FILE_CLAUDE_STATUS_SCRIPT="/opt/homelab/bin/claude/claude-status.sh"
    declare -g LINES_CLAUDE_LOG=50                      # journal lines without --follow
}
_claude_globals

# ==============================================================================
# --- Helpers ---
# ==============================================================================

# --- claude_actions ---
# @desc_short       : Completion list of the first position.
# @usage            : claude_actions
# ================================================================================
function claude_actions {
    # Inline list — arrays cannot be exported into the --option-cmd subshell
    printf '%s\n' \
        "attach # Main session in tmux (default)" \
        "shell # Plain shell in the container" \
        "status # Binary, sign-in, services, repos, disk" \
        "logs # Journal of both services" \
        "restart # Restart both services (ends open sessions)" \
        "update # claude update + restart"
}

# --- claude_ssh ---
# @desc_short       : Runs a command in the container as the claude user.
# @usage            : claude_ssh [-t] [command...]
# @parameter        : $1 | -t | Optional: allocate a terminal (tmux, journal -f)
# ================================================================================
function claude_ssh {
    local -a ssh_opts=(-o ConnectTimeout=10)

    # Interactive programs need a pseudo terminal, plain commands must not get one
    if [[ "${1:-}" == "-t" ]]; then
        ssh_opts+=(-t)
        shift
    fi

    ssh "${ssh_opts[@]}" "${USER_CLAUDE}@${IP_CLAUDE}" "$@"
}

export -f claude_actions

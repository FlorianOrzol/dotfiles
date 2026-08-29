#!/bin/bash
# ==============================================================================
# --- Extension Global Library: Key ---
# Provides isolated rbw functions and robust initialization logic.
# ==============================================================================
TIMEOUT_AGENT_STARTUP=50    # Number of 0.1s steps to wait for the rbw-agent socket
# ==============================================================================

# ------------------------------------------------------------------------------
# Feature: Initialization Check
# ------------------------------------------------------------------------------
function _is_initialized() {
    _rbw config show &>/dev/null && return 0 || return 1
}



# ------------------------------------------------------------------------------
# Feature: RBW Wrapper
# ------------------------------------------------------------------------------
# RBW_PROFILE is deliberately NOT set: rbw 1.15.0 ignores it, so it never created
# the isolated profile it promises — every call lands in the default profile
# anyway. Setting it would become a trap the day rbw starts honouring it: the
# extension would silently switch to an empty, unauthenticated profile.
function _rbw() {
    rbw "$@"
}

# ------------------------------------------------------------------------------
# Feature: Master Password Retrieval
# ------------------------------------------------------------------------------
function _get_master_password() {
	local -n return_ref=$1
    
	return_ref=$(pass show "$PASS_NAME_VAULTWARDEN" 2>/dev/null) \
		|| { output --error "Pass entry '$PASS_NAME_VAULTWARDEN' not found."; exit 1; }
}
# ------------------------------------------------------------------------------
# Feature: RBW Agent Startup
# ------------------------------------------------------------------------------
# --- _ensure_rbw_agent ---
# @desc_short  : Starts the rbw-agent detached, if it is not already running.
# @returns     : 0 once the agent answers, 1 if it never came up
# @notes       : Every rbw subcommand spawns the agent as a daemon on demand.
#                That daemon inherits the file descriptors of its caller, so a
#                'result=$(rbw ...)' never returns: the agent keeps the write end
#                of the command substitution open for its whole lifetime, and it
#                outlives the shell. Ctrl-C does not help either, the daemon
#                detaches from the terminal and never sees the signal. Starting
#                the agent here — with setsid and /dev/null on all descriptors —
#                is what keeps it from ever inheriting anything of ours.
# ==============================================================================
function _ensure_rbw_agent() {
    local count_wait

    # 'rbw unlocked' is the one subcommand that never starts the agent itself,
    # so it can be used to probe for it without side effects.
    _rbw unlocked 2>&1 | grep -q "agent not running" || return 0

    setsid rbw-agent </dev/null >/dev/null 2>&1 &

    # The socket appears a moment after the fork — wait for it, otherwise the
    # next subcommand would start a second agent the unsafe way.
    for ((count_wait = 0; count_wait < TIMEOUT_AGENT_STARTUP; count_wait++)); do
        _rbw unlocked 2>&1 | grep -q "agent not running" || return 0
        sleep 0.1
    done

    output --error "rbw-agent did not come up."
    return 1
}

# ------------------------------------------------------------------------------
# Feature: RBW Unlocking (Bulletproof Version)
# ------------------------------------------------------------------------------
# --- _unlock_rbw ---
# @desc_short  : Unlocks the local vault, feeding the master password from pass.
# ==============================================================================
function _unlock_rbw() {
	# if unlocked, return success immediately
    _rbw unlocked &>/dev/null && return 0

    _ensure_rbw_agent || exit 1

    _answer_master_password_prompt unlock

	_rbw unlocked || { output --error "Failed to unlock rbw vault. Please check your credentials."; exit 1; }
}

# --- _answer_master_password_prompt ---
# @desc_short  : Runs an rbw subcommand and answers its master password prompt.
# @usage       : _answer_master_password_prompt <subcommand>
# @parameter   : $1 | subcommand | rbw subcommand asking for the master password
# @notes       : Requires a terminal-based pinentry (pinentry-curses/-tty). A
#                graphical pinentry opens its own window instead of prompting on
#                the pty, and expect would wait forever.
# @notes       : Two things must never be done here: capturing expect in a
#                command substitution, and waiting for 'expect eof'. rbw asks
#                for the password through a pinentry process of its own, which
#                keeps the pty open past the client's exit — so eof never
#                arrives. Writing to a file and waiting for the client process
#                itself ('wait') is what makes this terminate.
# ==============================================================================
function _answer_master_password_prompt() {
    local subcommand="$1"
    local vault_pass
    local file_output_expect
    local script_expect
    local status_expect

	_get_master_password vault_pass

    # Handed over through the environment — a command line would expose the
    # password in the process list.
    export VAULT_PASS="$vault_pass"
    export RBW_SUBCOMMAND="$subcommand"

    # mktemp creates the file with mode 0600 before anything is written to it.
    file_output_expect=$(mktemp)

    script_expect=$(cat <<'EXPECT_SCRIPT'
log_user 0
set timeout 30
spawn rbw $env(RBW_SUBCOMMAND)
expect {
    "Master Password" { send "$env(VAULT_PASS)\r" }
    timeout           { exit 91 }
    eof               { exit 92 }
}
set result_wait [wait]
exit [lindex $result_wait 3]
EXPECT_SCRIPT
)

    # stdin from /dev/null and stdout into a file: nothing the spawned processes
    # could inherit is able to block this shell.
    expect -c "$script_expect" </dev/null >"$file_output_expect" 2>&1
    status_expect=$?

    unset VAULT_PASS RBW_SUBCOMMAND # Clear sensitive variable

    case "$status_expect" in
        0)
            rm -f "$file_output_expect"
            return 0
            ;;
        # The pinentry dialog never showed up within the timeout.
        91)
            output --error "rbw '${subcommand}' did not ask for the master password in time."
            ;;
        # rbw exited before it ever asked — a broken login state, usually.
        92)
            output --error "rbw '${subcommand}' exited without asking for the master password."
            output --info  "Try manually in a terminal:  rbw stop-agent && rbw lock && rbw login"
            ;;
        # Any other code is rbw's own exit status, passed through by expect.
        *)
            output --error "rbw '${subcommand}' failed with exit code ${status_expect}."
            # With log_user off the file only ever holds real error output.
            [[ -s "$file_output_expect" ]] && output --info "$(< "$file_output_expect")"
            output --info  "Try manually in a terminal:  rbw stop-agent && rbw lock && rbw login"
            ;;
    esac

    rm -f "$file_output_expect"
    return 1
}

# ------------------------------------------------------------------------------
# Feature: sync RBW Vault
# ------------------------------------------------------------------------------
# --- _sync_rbw ---
# @desc_short  : Syncs the vault and re-logs in once when the session is dead.
# @desc_detailed: A sync failure is almost always an invalid refresh token:
#                 vaultwarden hands out a new one on every refresh, so a single
#                 lost response locks the client out permanently ('invalid_grant').
#                 Unlocking still works from the local cache — which is why this
#                 used to fail silently for months while serving stale entries.
# ==============================================================================
function _sync_rbw() {
    local result_sync

    # Never let 'rbw sync' be the call that spawns the agent: the daemon would
    # inherit the command substitution below and keep it open forever.
    _ensure_rbw_agent || return 1

	result_sync=$(_rbw sync 2>&1) && return 0

    # Only a dead session justifies the purge below. rbw reports it by failing to
    # parse the server's error reply ("missing field access_token" for
    # {"error":"invalid_grant"}). Any other failure — server down, no network —
    # must leave the cache alone: it is the only local copy of the vault.
    if [[ "$result_sync" != *"access_token"* ]]; then
        output --error "Failed to sync rbw vault: ${result_sync}"
        return 1
    fi

    output --info "Login session is no longer accepted — re-authenticating..."

    # rbw never re-logs in on its own: it keeps refreshing the rejected token,
    # and 'rbw login' returns 0 without asking as long as any local state exists.
    # Dropping that state is what turns the next login into a real one.
    _rbw purge &>/dev/null

    _answer_master_password_prompt login || return 1

	_rbw sync &>/dev/null || output --error "Failed to sync rbw vault."
}

# ------------------------------------------------------------------------------
# Feature: Initialization Logic
# ------------------------------------------------------------------------------
function _do_init() {

	# Validate url format and prepend https if missing
    if [[ -n "$ARG_URL" ]] && [[ "$ARG_URL" != http* ]]; then
        ARG_URL="https://$ARG_URL"
    fi

#    lx db --file "config.conf" --table "config" --insert --data "KEY_EMAIL" "$email" "KEY_BASE_URL" "$url" "KEY_PASS_ENTRY" "$pentry" 2>/dev/null || true
	output --info "Saving configuration to file"
	echo "" > $FILE_EXTENSION_CONFIG
	echo "PASS_NAME_VAULTWARDEN=\"$ARG_PASS_ENTRY\"" >> $FILE_EXTENSION_CONFIG
	echo "EMAIL_VAULTWARDEN=\"$ARG_EMAIL\"" >> $FILE_EXTENSION_CONFIG
	echo "URL_VAULTWARDEN=\"$ARG_URL\"" >> $FILE_EXTENSION_CONFIG
	source $FILE_EXTENSION_CONFIG

	output --info "Set rbw configuration for profile '$THIS_RBW_PROOFILE'..."
    _rbw config set email "$EMAIL_VAULTWARDEN"
    _rbw config set base_url "$URL_VAULTWARDEN"

	# search for existing pass entry
	if ! pass show "$PASS_NAME_VAULTWARDEN" &>/dev/null; then
		output --error "Pass entry '$PASS_NAME_VAULTWARDEN' not found. Please create it with the master password for your Vaultwarden account."
		if question "Do you want to create a new pass entry named '$PASS_NAME_VAULTWARDEN' now?"; then
			pass insert "$PASS_NAME_VAULTWARDEN" || output --error "Failed to create pass entry." || exit 1
			output --ok "Pass entry '$PASS_NAME_VAULTWARDEN' created successfully."
		else
			output --error "Initialization aborted. Please create the required pass entry and try again."
			exit 1
		fi
	fi

	# unlock to verify credentials and sync
	_unlock_rbw 

	
    output --ok "Initialization successful."
}

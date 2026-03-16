#!/bin/bash

# ==============================================================================
# --- Arguments Definition ---
# Module: dotfiles private
# Delegates all argument completion and handling natively to Git.
# ==============================================================================

function arguments() {
	# Tell the completion engine to wrap the system's "git" command.
	# Any arguments typed after "private" will trigger Git completions.
	arg_wrap "git"
}


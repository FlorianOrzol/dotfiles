# Disable existing completions for 'dotfiles' to prevent conflicts and ensure custom completions are used.
complete -c dotfiles -e # Erase all existing completions for 'dotfiles'.
complete -c dotfiles -f # Forbid fish from generating completions for 'dotfiles' automatically.

# ------------------------------------------------------------------
# Helper Function: The Git Simulator
# ------------------------------------------------------------------
# This function simulates Git command completions for 'dotfiles public' and 'dotfiles private'.
# It transforms the 'dotfiles' command with its submodule (public/private) into a 'git' command
# to leverage Git's native completion capabilities.
function __dotfiles_git_simulator
    # Retrieve the complete current command line up to the cursor position.
    set -l current_cmd (commandline -cp)
    
    # Replace "dotfiles public" or "dotfiles private" with "git" in the command string.
    # Example: "dotfiles public sta" becomes "git sta".
    set -l fake_git_cmd (string replace -r '^dotfiles\s+(public|private)' 'git' -- $current_cmd)
    
    # Execute completion for this faked Git command and return the result.
    complete -C"$fake_git_cmd"
end

# ------------------------------------------------------------------
# Level 1: Main Selection (public, private, push-all, etc.)
# ------------------------------------------------------------------
# Define the main subcommands available for 'dotfiles'.
set -l main_cmds public private public-add public-rm private-add private-rm push-all

# Provide completions for these main subcommands only if none of them have been selected yet.
complete -c dotfiles \
    -n "not __fish_seen_subcommand_from $main_cmds" \
    -a "$main_cmds"

# ------------------------------------------------------------------
# Level 2: Full Git Power Integration
# ------------------------------------------------------------------
# If 'public' or 'private' has already been typed, invoke the Git simulator.
# The '-a' (arguments) flag here receives the output of our helper function,
# effectively providing Git-like completions for the dotfiles subcommands.
complete -c dotfiles \
    -n "__fish_seen_subcommand_from public private" \
    -a "(__dotfiles_git_simulator)"

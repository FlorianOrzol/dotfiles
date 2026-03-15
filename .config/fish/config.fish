#  _____
# |~>   |     _
# |_____|   ('v') 
# /:::::\  /{w w}\ 
#
# My personal fish shell configuration
# Author: Florian Orzol
#
# This file sets up global variables, integrates external tools,
# defines aliases, abbreviations, and interactive shell behaviors,
# including tmux session management and key bindings.



# Set global environment variables
# Define the default editor for command-line tools and applications.
set -gx EDITOR nvim
# Define the default visual editor, often used for operations like 'git commit'.
set -gx VISUAL nvim

# Initialize external tools and their shell integrations
# zoxide: A smarter `cd` command that learns your habits and allows quick directory navigation.
zoxide init fish | source
# fnm: A fast and simple Node.js version manager.
fnm env --use-on-cd | source
# mcfly: A new and improved shell history search tool with AI-powered suggestions.
mcfly init fish | source
#alias my-testt='linux-mate my-testt'

# move backward in directory tree
abbr -a ... '../..'
abbr -a .... '../../..'
abbr -a ..... '../../../..'
abbr -a ...... '../../../../..'

# my personal abbreviations and aliases
abbr -a e 'lpex'

# Define common abbreviations and aliases for frequently used commands
# 'l' (list): Abbreviation for 'exa' with default options for listing files.
abbr -a l '_eza'
# 'la' (list all): Abbreviation for 'exa -la' to list all files, including hidden ones.
abbr -a la '_eza -la'
# 'll' (long list): Abbreviation for 'exa -l' to list files in long format.
abbr -a ll '_eza -l'
# 'lt' (tree list): Abbreviation for 'exa -T' to list files in a tree-like format.
abbr -a lt '_eza -T'
# 'llt' (long tree list): Abbreviation for 'exa -lT' to list files in long format in a tree-like structure.
abbr -a llt '_eza -lT'
# 'lr' (recursive list): Abbreviation for 'exa -lR' to list files recursively.
abbr -a lr '_eza -lR'
# Alias for 'exa': Configures 'exa' with icons, grouped directories, human-readable sizes, and Git status.
alias _eza='eza --icons --color always --group-directories-first -M -h --git'
# 'lf' is for finding files with 'fd', using a custom header and color settings.
alias lf='fd -H'
# Alias for 'vim': Redirects 'vim' command to 'nvim' (Neovim).
alias vim='nvim'
# Alias for 'google-chrome-stable': Launches Chrome with Wayland support.
alias google-chrome-stable='/usr/bin/google-chrome-stable --enable-features=UseOzonePlatform --ozone-platform=x11'
# 'x': Abbreviation for 'linux-helper -xd' (assuming -xd are specific flags for this helper).
abbr -a x 'linux-helper -xd'
# 'p': Abbreviation for 'keys get -c' to securely get a password from the password manager and copy to clipboard.
abbr -a p 'keys get -c'





# Custom function `ffzf`: Provides an interactive fuzzy finder for files.
# Uses 'fzf' to display a list of files with a custom header, key binding for opening,
# height, layout, margin, and color settings. The selected file(s) are then echoed.
function ffzf
	set -g fzf (command /usr/bin/fzf -m --header='(Ctrl-o) open file in editor' --bind='ctrl-o:execute(open ./{})' --height=20 --layout reverse --margin=0,3,0,3 --color 16 $argv)
	echo $fzf
end

# Conditional execution for interactive shells
if status is-interactive
    # Check if not running inside VS Code, as tmux integration can interfere.
    and not set -q VSCODE_INJECTION

    # TMUX Session Management Logic:
    # If the current shell is not already inside a tmux session ($TMUX is not set),
    # start a new, independent tmux session for this terminal.
    # The session name is dynamically generated using a timestamp to ensure uniqueness.
    tmux new -s "alacritty_"(date +%s%N) # Temporarily without exec for debugging

    # Initialize fish key bindings.
    # fish_vi_key_bindings sets up Vim-like key bindings.
    fish_vi_key_bindings
    # Source custom user key bindings from a separate file.
	source ~/.config/fish/functions/fish_user_key_bindings.fish
    # Apply the sourced user key bindings.
    fish_user_key_bindings
end



# Function `save_status`: Captures the exit status of the last executed command.
# This is triggered by the `fish_postexec` event, ensuring `last_status` always holds
# the exit code of the previously run command. Useful for prompt customization.
function save_status --on-event fish_postexec
    set -g last_status $status
end






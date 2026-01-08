# Function: update-all
# Description: Comprehensive script to update system packages and various programming language packages.
# It supports `--noconfirm` to automate prompts and checks for a required system reboot.

# Completions for the `update-all` function.
complete -c update-all -f -a '--noconfirm' -d 'Automatically confirm all prompts during updates'
complete -c update-all -f -a '--help' -d 'Show help information for the update-all command'


function update-all
	echo "Updating system packages..."
    # Parse arguments for the function.
	switch $argv
		case '--no-confirm'
            # If '--noconfirm' is passed, set the variable to be used with package managers.
			set -l noconfirm_pacman '-y' 
			set -l noconfirm_yay '--no-confirm'
		case '--help'
            # If '--help' is passed, display the help message and exit.
			__update_all_help
			return
		case '*'
            # Default case: no '--noconfirm' flag.
			set -l noconfirm ''
		end

	# Update for pacman (Arch Linux package manager).
	if type -q pacman
		echo "Updating pacman packages..."

		sudo pacman -Syu $noconfirm_pacman
	end

	# Update for yay (AUR helper for Arch Linux).
	if type -q yay
		echo "Updating yay packages..."
		yay -Syu $noconfirm_yay
	end

	# Update npm (Node.js package manager) global packages.
	if type -q npm
		echo "Updating npm packages..."
		npm update -g
	end
	
	# Update pipx (Python packages in isolated environments) packages.
	if type -q pipx
		echo "Updating pipx packages..."
		pipx upgrade-all
	end

	# Update Ruby gems (Ruby packages).
	if type -q gem
		echo "Updating Ruby gems..."
		sudo gem update
	end

	# Check for reboot requirement.
	# The presence of /var/run/reboot-required indicates that a system reboot is needed.
	if test -f /var/run/reboot-required
		echo ""
		echo "A system reboot is required to complete updates."
	end
end

# Helper function: `__update_all_help`
# Displays the usage and options for the `update-all` command.
function __update_all_help
	echo "Usage: update-all [--noconfirm]"
	echo ""
	echo "Updates all system and programming language packages."
	echo ""
	echo "Options:"
	echo "  --noconfirm    Automatically confirm all prompts during updates."
end

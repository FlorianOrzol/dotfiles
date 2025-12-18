complete -c update-all -f -a '--noconfirm' -d 'Automatically confirm all prompts during updates'
complete -c update-all -f -a '--help' -d 'Show help for update-all command'


function update-all
	echo "Updating system packages..."
	switch $argv
		case '--noconfirm'
			set -l noconfirm '--noconfirm'
		case '--help'
			__update_all_help
			return
		case '*'
			set -l noconfirm ''
		end

	# Update for pacman
	if type -q pacman
		echo "Updating pacman packages..."
		sudo pacman -Syu $noconfirm
	end

	# Update for yay
	if type -q yay
		echo "Updating yay packages..."
		yay -Syu $noconfirm
	end

	# Update npm packages
	if type -q npm
		echo "Updating npm packages..."
		npm update -g
	end
	
	# Update pipx packages
	if type -q pipx
		echo "Updating pipx packages..."
		pipx upgrade-all
	end


	# Update Ruby packages
	if type -q gem
		echo "Updating Ruby gems..."
		sudo gem update
	end


	# check for reboot requirement
	if test -f /var/run/reboot-required
		echo ""
		echo "A system reboot is required to complete updates."
	end
end









function __update_all_help
	echo "Usage: update-all [--noconfirm]"
	echo ""
	echo "Updates all system and programming language packages."
	echo ""
	echo "Options:"
	echo "  --noconfirm    Automatically confirm all prompts during updates."
end

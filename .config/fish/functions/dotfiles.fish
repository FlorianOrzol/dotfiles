# Function: dotfiles
# Description: Manager for bare Git repository dotfiles.
# This function simplifies common Git operations for managing dotfiles stored in
# separate bare repositories (public and private). It wraps standard Git commands
# and provides convenience functions for syncing and managing files.
function dotfiles --description 'Manager for Bare-Repo Dotfiles'
    # Configuration of the bare Git repository paths.
    # `public_git`: Path to the bare repository for publicly accessible dotfiles.
    set -l public_git "$HOME/.git-dotfiles/public"
    # `private_git`: Path to the bare repository for sensitive/private dotfiles.
    set -l private_git "$HOME/.git-dotfiles/private"

    # The first argument determines the subcommand to execute.
    set -l cmd $argv[1]

    switch $cmd
        # --- 1. Public Repo Wrapper ---
        case public
            # Executes Git commands in the context of the public dotfiles repository.
            # Example: `dotfiles public status` is equivalent to `git --git-dir=... --work-tree=... status`.
            /usr/bin/git --git-dir=$public_git --work-tree=$HOME $argv[2..-1]

        # --- 2. Private Repo Wrapper ---
        case private
            # Executes Git commands in the context of the private dotfiles repository.
            # Example: `dotfiles private add -f .ssh/config`
            /usr/bin/git --git-dir=$private_git --work-tree=$HOME $argv[2..-1]

        # --- 3. `push-all` (Convenience Function for Syncing Both Repos) ---
        case push-all
            # Generate a timestamp for commit messages.
            set -l timestamp (date "+%Y-%m-%d %H:%M")

            echo (set_color blue)"=== Syncing Public Repo ==="(set_color normal)
            # Public Repo: Adds all changes (tracked and untracked) allowed by its configuration.
            /usr/bin/git --git-dir=$public_git --work-tree=$HOME add .
            
            # Commit only if there are actual changes.
            if not /usr/bin/git --git-dir=$public_git --work-tree=$HOME diff-index --quiet HEAD --
				# If additional arguments are provided after 'push-all', use them as the commit message.
				if test (count $argv) -gt 1
					/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m "$argv[2..-1]"
				else
					/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m "Auto update $timestamp"
				end

                /usr/bin/git --git-dir=$public_git --work-tree=$HOME push
                echo (set_color green)"✔ Public Pushed"(set_color normal)
            else
                echo (set_color yellow)"- No changes in Public Repo"(set_color normal)
            end

            echo (set_color magenta)"=== Syncing Private Repo ==="(set_color normal)
            # Private Repo: Only updates existing tracked files (`add -u`), does not automatically add new secrets.
            /usr/bin/git --git-dir=$private_git --work-tree=$HOME add -u
            
            # Commit only if there are actual changes.
            if not /usr/bin/git --git-dir=$private_git --work-tree=$HOME diff-index --quiet HEAD --
                /usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m "Auto update $timestamp"
                /usr/bin/git --git-dir=$private_git --work-tree=$HOME push
                echo (set_color green)"✔ Private Pushed"(set_color normal)
            else
                echo (set_color yellow)"- No changes in Private Repo"(set_color normal)
            end
		
        # --- 4. `public-add` (Add file/directory to public dotfiles) ---
		case 'public-add'
			set -l path (realpath $argv[2..-1]) # Get the absolute path of the file/directory.
			echo "Do you really want to add '$path' to the public dotfiles repo? (y/N)"
			read -l response # Prompt for user confirmation.
			if test $response = 'y'
				# Force-add the file/directory to the public Git repository.
				/usr/bin/git --git-dir=$public_git --work-tree=$HOME add -f $argv[2..-1]
				echo (set_color green)"✔ Added to Public Repo"(set_color normal)
			end 

        # --- 5. `public-rm` (Remove file/directory from public dotfiles) ---
		case 'public-rm'
			# Remove the file/directory from the Git index (cached) in the public repository.
			/usr/bin/git --git-dir=$public_git --work-tree=$HOME rm --cached $argv[2..-1]
			echo (set_color green)"✔ Removed from Public Repo"(set_color normal)

        # --- 6. `private-add` (Add file/directory to private dotfiles) ---
		case 'private-add'
			# Force-add the file/directory to the private Git repository.
			/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f $argv[2..-1]
			echo (set_color green)"✔ Added to Private Repo"(set_color normal)

        # --- 7. `private-rm` (Remove file/directory from private dotfiles) ---
		case 'private-rm'
			# Remove the file/directory from the Git index (cached) in the private repository.
			/usr/bin/git --git-dir=$private_git --work-tree=$HOME rm --cached $argv[2..-1]
			echo (set_color green)"✔ Removed from Private Repo"(set_color normal)

        # --- Default Case (Unknown Subcommand) ---
        case '*'
            # Display usage instructions for unknown subcommands.
            echo "Usage: dotfiles [public | private | push-all | public-add | public-rm | private-add |private-rm] [git-args...]"
            return 1 # Indicate an error.
    end
end

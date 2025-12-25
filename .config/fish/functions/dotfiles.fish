function dotfiles --description 'Manager für Bare-Repo Dotfiles'
    # Konfiguration der Pfade
    set -l public_git "$HOME/.git-dotfiles/public"
    set -l private_git "$HOME/.git-dotfiles/private"

    # Erster Befehl (public, private oder push-all)
    set -l cmd $argv[1]

    switch $cmd
        # --- 1. Public Repo Wrapper ---
        case public
            # Führt einfach Git Befehle im Kontext des Public Repos aus
            # Beispiel: dotfiles public status
            /usr/bin/git --git-dir=$public_git --work-tree=$HOME $argv[2..-1]

        # --- 2. Private Repo Wrapper ---
        case private
            # Führt einfach Git Befehle im Kontext des Private Repos aus
            # Beispiel: dotfiles private add -f .ssh/config
            /usr/bin/git --git-dir=$private_git --work-tree=$HOME $argv[2..-1]

        # --- 3. Update All (Komfort-Funktion) ---
        case push-all
            set -l timestamp (date "+%Y-%m-%d %H:%M")

            echo (set_color blue)"=== Syncing Public Repo ==="(set_color normal)
            # Public: Nimmt alles, was die Whitelist erlaubt
            /usr/bin/git --git-dir=$public_git --work-tree=$HOME add .
            
            # Commit nur wenn Änderungen da sind
            if not /usr/bin/git --git-dir=$public_git --work-tree=$HOME diff-index --quiet HEAD --
				# if argvs [2] is not empty, pass them to commit
				if test (count $argv) -gt 1
					/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m "$argv[2..-1]"
				else
					/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m "Auto update $timestamp"
				end

                /usr/bin/git --git-dir=$public_git --work-tree=$HOME push
                echo (set_color green)"✔ Public Pushed"(set_color normal)
            else
                echo (set_color yellow)"- Keine Änderungen im Public Repo"(set_color normal)
            end

            echo (set_color magenta)"=== Syncing Private Repo ==="(set_color normal)
            # Private: Nur Updates (add -u), keine neuen Secrets automatisch
            /usr/bin/git --git-dir=$private_git --work-tree=$HOME add -u
            
            if not /usr/bin/git --git-dir=$private_git --work-tree=$HOME diff-index --quiet HEAD --
                /usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m "Auto update $timestamp"
                /usr/bin/git --git-dir=$private_git --work-tree=$HOME push
                echo (set_color green)"✔ Private Pushed"(set_color normal)
            else
                echo (set_color yellow)"- Keine Änderungen im Private Repo"(set_color normal)
            end

        case '*'
            echo "Verwendung: dotfiles [public | private | push-all] [git-args...]"
            return 1
    end
end

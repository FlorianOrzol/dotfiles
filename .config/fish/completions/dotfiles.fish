# 1. Alles Alte löschen und Standard-Files deaktivieren
complete -c dotfiles -e
complete -c dotfiles -f

# ------------------------------------------------------------------
# Hilfsfunktion: Der Git-Simulator
# ------------------------------------------------------------------
function __dotfiles_git_simulator
    # Hole die komplette aktuelle Befehlszeile bis zum Cursor
    set -l current_cmd (commandline -cp)
    
    # Ersetze "dotfiles public" oder "dotfiles private" durch "git"
    # Beispiel: "dotfiles public sta" wird zu "git sta"
    set -l fake_git_cmd (string replace -r '^dotfiles\s+(public|private)' 'git' -- $current_cmd)
    
    # Führe die Completion für diesen Fake-Befehl aus und gib das Ergebnis zurück
    complete -C"$fake_git_cmd"
end

# ------------------------------------------------------------------
# Level 1: Die Hauptauswahl (public, private, push-all)
# ------------------------------------------------------------------
set -l main_cmds public private push-all

# Zeige diese Befehle NUR, wenn wir noch keinen davon gewählt haben
complete -c dotfiles \
    -n "not __fish_seen_subcommand_from $main_cmds" \
    -a "$main_cmds"

# ------------------------------------------------------------------
# Level 2: Die volle Git Power
# ------------------------------------------------------------------
# Wenn 'public' oder 'private' schon da steht, rufen wir den Simulator.
# Das -a (Argumente) bekommt hier keinen festen Text, sondern den Output unserer Funktion.
complete -c dotfiles \
    -n "__fish_seen_subcommand_from public private" \
    -a "(__dotfiles_git_simulator)"

function __linux_helper_completions
    set -l base_path "/home/florian/.local/share/linux-helper/extension"
    
    # 1. Analyse (wie gehabt)
    set -l tokens (commandline -opc)
    set -e tokens[1]
    set -l current_word (commandline -ct)

	#printf "%s\t%s\n" "--server=Host 1" "description for server"
	#	printf "%s\t%s\n" "--server='client 1'" "description for server"
	
	printf "%s\t%s\n" --help Show help information
	printf "%s\t%s\n" "--version Show version information"
	#		printf "%s\t%s\n" "" "description for server"
	#	printf "%s\t%s\n" "-" ""
	return
    # 2. Pfad bereinigen
    set -l path_tokens
    for t in $tokens
        if string match -q -- "-*" "$t"
            continue
        end
        if test "$t" = "$current_word"
            continue
        end
        set path_tokens $path_tokens $t
    end

    # 3. Walker
    set -l search_path "$base_path"
    set -l valid_path 1 

    for t in $path_tokens
        if test -d "$search_path/$t"
            set search_path "$search_path/$t"
        else
            set valid_path 0
            break
        end
    end

    # 4. Ausgabe-Logik
    if test $valid_path -eq 1 && test -d "$search_path"
        
        # A) Prüfen: Gibt es hier Unterordner?
        # Wir nutzen einen Glob mit Slash am Ende, um nur Verzeichnisse zu matchen
        set -l subdirs $search_path/*/
        
        if test (count $subdirs) -gt 0
            # --- FALL 1: Es gibt weitere Unterbefehle ---
            for dir in $subdirs
                set -l name (basename "$dir")
                set -l info_file "$dir/info"
                set -l description "-"

                if test -r "$info_file"
                    set -l content (head -n 1 "$info_file" 2>/dev/null | string trim)
                    if test -n "$content"
                        set description "$content"
                    end
                end

                printf "%s\t%s\n" "$name" "$description"
            end

        else
            # --- FALL 2: Sackgasse (Endpunkt) -> Hilfetext anzeigen ---
            # Wir suchen nach einer 'usage' Datei in diesem Ordner
            set -l usage_file "$search_path/usage"
            
            if test -r "$usage_file"
                # Wir lesen die erste Zeile der Usage-Datei
                set -l usage_text (head -n 1 "$usage_file" 2>/dev/null | string trim)
                
                # TRICK: Wir geben keine Vervollständigung aus (leerer String vor dem \t),
                # sondern nur die Beschreibung. Fish zeigt das oft als Hinweis an.
                # Damit man es sicher sieht, geben wir einen generischen Platzhalter aus,
                # oder wir nutzen das aktuelle Wort, damit der Text daneben erscheint.
                
                if test -n "$usage_text"
                    # Hier geben wir einen Hinweis aus, der nicht stört
                    # Das Format ":\tText" sorgt dafür, dass Fish den Text anzeigt,
                    # aber nichts Falsches in die Befehlszeile einfügt.
                    printf "\t%s\n" "HINWEIS: $usage_text"
                end
            end
        end
    end
end

complete -c linux-helper -e 
complete -c linux-helper -f -k -a "(__linux_helper_completions)"

# ~/.config/fish/conf.d/pkg_addons.fish

set -l addon_base_dir ~/.local/share/pkg-addons/

if test -d $addon_base_dir
    for pkg_path in $addon_base_dir/*
        if test -d $pkg_path
            set -l pkg_name (basename $pkg_path)

            # --- TEIL 1: Wrapper Funktion (verbessert) ---
            function $pkg_name --inherit-variable pkg_name --inherit-variable pkg_path --wraps $pkg_name
                set -l func_script "$pkg_path/functions/addon.sh"
                set -l info_script "$pkg_path/infos/addon.sh"
                
                # Wir parsen die Argumente manuell, um auch --myfunc=backup abzufangen
                for arg in $argv
                    # Fall 1: --myinfo (als Flag oder mit =)
                    if string match -q -- "--myinfo*" $arg
                        # Argument extrahieren (falls vorhanden, z.B. --myinfo=version)
                        set -l val (string split -m1 = -- $arg)[2]
                        if test -f "$info_script"
                            # Falls wir ein Value aus dem Split haben, hängen wir es an, sonst $argv
                            if test -n "$val"
                                sh "$info_script" --myinfo $val
                            else
                                sh "$info_script" $argv
                            end
                            return 0
                        end
                    end

                    # Fall 2: --myfunc (als Flag oder mit =)
                    if string match -q -- "--myfunc*" $arg
                        set -l val (string split -m1 = -- $arg)[2]
                        if test -f "$func_script"
                            if test -n "$val"
                                sh "$func_script" --myfunc $val
                            else
                                sh "$func_script" $argv
                            end
                            return 0
                        end
                    end
                end

                # Wenn kein Addon-Flag gefunden wurde:
                command $pkg_name $argv
            end


            # --- TEIL 2: Completions ---
            
            # Zuerst prüfen: Gibt es eine eigene Completion-Datei?
            if test -f "$pkg_path/completions.fish"
                source "$pkg_path/completions.fish"
            else
                # Fallback: Nur wenn KEINE Datei da ist, definieren wir die einfachen Flags
                # Damit verhindern wir Konflikte.
                complete -c $pkg_name -l myinfo -d "Addon Info"
                complete -c $pkg_name -l myfunc -d "Addon Function"
            end
        end
    end
end

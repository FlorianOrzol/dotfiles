# This file (`~/.config/fish/conf.d/pkg_addons.fish`) is responsible for dynamically
# integrating "addons" for various commands. It scans a predefined directory for
# addon packages, creates wrapper functions for them, and sets up their completions.

# Define the base directory where addon packages are located.
set -l addon_base_dir ~/.local/share/pkg-addons/

# Check if the addon base directory exists before proceeding.
if test -d $addon_base_dir
    # Iterate through each subdirectory within the addon base directory.
    # Each subdirectory is considered an individual addon package.
    for pkg_path in $addon_base_dir/*
        if test -d $pkg_path
            # Extract the package name from the directory name (e.g., 'git', 'pacman').
            set -l pkg_name (basename $pkg_path)

            # --- PART 1: Wrapper Function ---
            # Dynamically define a wrapper function with the same name as the package (e.g., 'git').
            # This wrapper intercepts calls to the original command to inject addon-specific logic.
            # `--inherit-variable` ensures the function has access to `pkg_name` and `pkg_path`.
            # `--wraps $pkg_name` indicates this function wraps an existing command of the same name.
            function $pkg_name --inherit-variable pkg_name --inherit-variable pkg_path --wraps $pkg_name
                set -l func_script "$pkg_path/functions/addon.sh" # Path to the addon's function script.
                set -l info_script "$pkg_path/infos/addon.sh"     # Path to the addon's info script.
                
                # Manually parse arguments to detect addon-specific flags like `--myfunc` or `--myinfo`,
                # which might include values (e.g., `--myfunc=backup`).
                for arg in $argv
                    # Case 1: Detect `--myinfo` flag (with or without an assigned value).
                    if string match -q -- "--myinfo*" $arg
                        # Extract the value if present (e.g., from `--myinfo=version`).
                        set -l val (string split -m1 = -- $arg)[2]
                        if test -f "$info_script"
                            # Execute the info script. If a value was extracted, pass it; otherwise, pass all arguments.
                            if test -n "$val"
                                sh "$info_script" --myinfo $val
                            else
                                sh "$info_script" $argv
                            end
                            return 0 # Exit after handling the addon-specific flag.
                        end
                    end

                    # Case 2: Detect `--myfunc` flag (with or without an assigned value).
                    if string match -q -- "--myfunc*" $arg
                        # Extract the value if present.
                        set -l val (string split -m1 = -- $arg)[2]
                        if test -f "$func_script"
                            # Execute the function script.
                            if test -n "$val"
                                sh "$func_script" --myfunc $val
                            else
                                sh "$func_script" $argv
                            end
                            return 0 # Exit after handling the addon-specific flag.
                        end
                    end
                end

                # If no addon-specific flags were found, execute the original command.
                # `command $pkg_name $argv` ensures the original binary is called, avoiding infinite recursion.
                command $pkg_name $argv
            end

            # --- PART 2: Completions ---
            # First, check if the addon provides its own dedicated completion file.
            if test -f "$pkg_path/completions.fish"
                source "$pkg_path/completions.fish" # Source the custom completions if found.
            else
                # Fallback: If no custom completion file exists, define basic flags for the addon.
                # This prevents conflicts and provides minimal completion support.
                complete -c $pkg_name -l myinfo -d "Addon Info"     # Completion for --myinfo flag.
                complete -c $pkg_name -l myfunc -d "Addon Function" # Completion for --myfunc flag.
            end
        end
    end
end

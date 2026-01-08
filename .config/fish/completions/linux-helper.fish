# This file provides dynamic completions for the `linux-helper` command.
# It generates suggestions based on a file system structure defined in `~/.local/share/linux-helper/extension`.

function __linux_helper_completions
    set -l base_path "/home/florian/.local/share/linux-helper/extension"
    
    # 1. Command Line Analysis
    # Get all tokens from the current command line.
    set -l tokens (commandline -opc)
    # Remove the command itself ('linux-helper') from the tokens list.
    set -e tokens[1]
    # Get the current word being typed for context.
    set -l current_word (commandline -ct)

	printf "%s\t%s\n" ""
	printf "%s\t%s\n" "Meine Bunte Beschreibunt"
	return
    # Always provide completions for standard options like --help and --version.
	#printf "%s\t%s\n" --help "Show help information"
	#printf "%s\t%s\n" "--version" "Show version information"
    
    # The previous 'return' statement here was preventing dynamic completions.
    # It has been removed to allow the rest of the function to execute.

    # 2. Path Token Cleaning
    # Build a list of path tokens, excluding options (starting with -) and the current word.
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

    # 3. Path Traversal (Walker)
    # Determine the current path within the extension directory based on parsed tokens.
    set -l search_path "$base_path"
    set -l valid_path 1 # Flag to indicate if the path constructed so far is valid

    for t in $path_tokens
        if test -d "$search_path/$t"
            set search_path "$search_path/$t"
        else
            set valid_path 0
            break
        end
    end

    # 4. Completion Output Logic
    # If the constructed path is valid and points to an existing directory,
    # generate completions based on its contents.
    if test $valid_path -eq 1 && test -d "$search_path"
        
        # A) Check for subdirectories (further subcommands)
        # Use a glob with a trailing slash to match only directories.
        set -l subdirs $search_path/*/
        
        if test (count $subdirs) -gt 0
            # --- CASE 1: Further Subcommands Exist ---
            # Iterate through subdirectories and provide them as completions.
            for dir in $subdirs
                set -l name (basename "$dir")
                set -l info_file "$dir/info"
                set -l description "-" # Default description if no info file is found

                if test -r "$info_file"
                    # Read the first line of the 'info' file for the description.
                    set -l content (head -n 1 "$info_file" 2>/dev/null | string trim)
                    if test -n "$content"
                        set description "$content"
                    end
                end

                # Output the subcommand name and its description.
                printf "%s\t%s\n" "$name" "$description"
            end

        else
            # --- CASE 2: Endpoint Reached (No more subdirectories) -> Display Usage Help ---
            # Look for a 'usage' file in the current directory.
            set -l usage_file "$search_path/usage"
            
            if test -r "$usage_file"
                # Read the first line of the 'usage' file for a usage hint.
                set -l usage_text (head -n 1 "$usage_file" 2>/dev/null | string trim)
                
                # TRICK: Output a hint without providing an actual completion string.
                # Fish often displays such text as a suggestion or note.
                if test -n "$usage_text"
                    # The format ":\tText" tells Fish to display the text without
                    # inserting anything into the command line.
                    printf "\t%s\n" "HINT: $usage_text"
                end
            end
        end
    end
end

# Disable default completions for 'linux-helper' to use our custom logic.
complete -c linux-helper -e 
# Attach our custom completion function to 'linux-helper'.
# The '-f' flag forces fish to use this completion, '-k' preserves existing options,
# and '-a' specifies the function to call for completions.
complete -c linux-helper -f -k -a "(__linux_helper_completions)"

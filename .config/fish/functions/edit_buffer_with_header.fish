# Function: edit_buffer_with_header
# Description: Opens the current Fish command line buffer in a Neovim popup for multi-line editing.
# This function allows for more complex editing of the current command, similar to `Ctrl-X Ctrl-E` in Bash.
# It pre-fills the buffer with a header and the current command, and provides keybindings for saving or canceling.
function edit_buffer_with_header
    # Define a header string to mark the start of the user's input.
    set -l header "# --- Fish Header ---"
    # Capture the current command line content.
    set -l current_command (commandline)
    # Create a temporary file to hold the editable buffer content.
    set -l temp_file (mktemp)
    # Create another temporary file to store the exit status of Neovim.
    set -l status_file (mktemp)

    # 1. Preparation: Populate the temporary buffer file.
    # Write the header to the temporary file.
    echo "$header" > $temp_file
    # Append the current command to the temporary file, or an empty line if no command.
    if test -n "$current_command"
        echo $current_command >> $temp_file
    else
        echo "" >> $temp_file
    end

    # 2. Neovim Command for the Tmux Popup.
    # This command configures Neovim with specific key bindings for the popup.
    # - `normal! G`: Moves the cursor to the last line.
    # - `startinsert!`: Enters insert mode immediately.
    # - `inoremap <C-c> <Esc>:cquit<CR>`: Maps Ctrl+C in insert mode to quit without saving.
    # - `nnoremap <C-c> :cquit<CR>`: Maps Ctrl+C in normal mode to quit without saving.
    # - `inoremap <C-CR> <Esc>:wq<CR>`: Maps Ctrl+Enter in insert mode to save and quit.
    # - `inoremap <M-CR> <Esc>:wq<CR>`: Maps Alt+Enter in insert mode to save and quit.
    # - `nnoremap <CR> :wq<CR>`: Maps Enter in normal mode to save and quit.
    # - `nnoremap q :cquit<CR>`: Maps 'q' in normal mode to quit without saving.
    # The exit status of nvim is written to `$status_file`.
    set -l nvim_cmd "nvim '$temp_file' \
        -c 'normal! G' \
        -c 'startinsert!' \
        -c 'inoremap <C-c> <Esc>:cquit<CR>' \
        -c 'nnoremap <C-c> :cquit<CR>' \
        -c 'inoremap <C-CR> <Esc>:wq<CR>' \
        -c 'inoremap <M-CR> <Esc>:wq<CR>' \
        -c 'nnoremap <CR> :wq<CR>' \
        -c 'nnoremap q :cquit<CR>' \
    ; echo \$? > '$status_file'"

    # 3. Launch the Tmux Popup.
    # Opens a new tmux popup window with Neovim, sized at 40% height and 80% width.
    # The `-E` flag executes the command with the specified environment variables,
    # and `-h`/`-w` define height/width.
    tmux popup -E -h 40% -w 80% sh -c "$nvim_cmd"

    # 4. Wait for Neovim to finish.
    # The script pauses until the `$status_file` contains content, indicating Nvim has exited.
    while not test -s $status_file
        sleep 0.05
    end

    # 5. Check the exit status of Neovim.
    set -l exit_code (cat $status_file)

    if test "$exit_code" = "0"
        # --- SUCCESS (Saved and Quit) ---
        # If Neovim exited successfully (status 0), process the edited content.
        if test -f $temp_file
            # Remove the header line from the temporary file.
            grep -vF "$header" $temp_file > $temp_file.tmp
            mv $temp_file.tmp $temp_file
            
            # Read the cleaned content into a variable.
            read -z clean_data < $temp_file
            # Trim any leading/trailing whitespace from the edited command.
            set -l final_cmd (string trim --right -- "$clean_data")

            # If the final command is not empty, replace the current command line and execute it.
            if test -n "$final_cmd"
                commandline -r -- $final_cmd # Replace the current command line buffer.
                commandline -f execute      # Execute the command from the buffer.
            end
        end
    else
        # --- ABORT (Ctrl+C or 'q') ---
        # If Neovim was exited with an error code (e.g., via :cquit), do nothing.
        # The command line buffer remains untouched.
    end

    # Clean up: Remove the temporary files.
    rm $temp_file
    rm $status_file
end

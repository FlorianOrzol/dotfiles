# Function: fish_user_key_bindings
# Description: Defines custom key bindings for the Fish shell.
# This function is sourced to apply personalized keyboard shortcuts, enhancing shell interaction.
function fish_user_key_bindings
    # This line is usually present if you are using Vi-mode key bindings.
    # It ensures the basic Vi-mode bindings are loaded before custom ones.

    # Bind 'Alt+t' (Escape + t) to the `edit_buffer_with_header` function.
    # This allows multi-line editing of the current command in a Neovim popup.
    bind \et edit_buffer_with_header
    
    # Ensure 'Alt+t' also works in insert mode, especially when Vi-mode is active,
    # to provide consistent behavior across modes.
    bind -M insert \et edit_buffer_with_header

    # Bind 'Ctrl+o' in insert mode to the `cd-ranger` function,
    # followed by executing the command in the buffer.
    # This allows for interactive directory navigation and immediate execution.
	bind -M insert \co 'cd-ranger; commandline -f execute;'
    # Bind 'Ctrl+o' in normal mode to the `cd-ranger` function,
    # followed by executing the command in the buffer.
	bind \co 'cd-ranger; commandline -f execute;'
end

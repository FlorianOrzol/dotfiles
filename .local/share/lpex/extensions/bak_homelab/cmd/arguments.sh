#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines the CLI arguments for the cmd submodule.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for command execution and management.
# @usage            : lpex homelab cmd <devices> <actions> [options]
#
# @devices          : --host | --observer | --vm | --container
# @actions          : --cmd | --delete | --edit | --alias | --list
# @options          : --run          (only with --cmd)
#                     --save         (only with --cmd)
#                     --desc         (only with --save)
#                     --devices      (only with --save)
#                     --edit_alias   (only with --edit)
#                     --edit_cmd     (only with --edit)
#                     --edit_desc    (only with --edit)
#                     --edit_devices (only with --edit)
# ==============================================================================
function arguments {
    # 1. --- Devices ---------------
    # ------ Mutually exclusive options for target selection.
    
    arg_value @host --description "Target host (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"
        
    arg_value @observer --description "Target observer (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @vm --description "Target VM" \
        --option-cmd "cat '$FILE_VM_LIVE' 2>/dev/null"
        
    arg_value @container --description "Target container (e.g., 1111)" \
        --option-cmd "cat '$FILE_CONTAINER_LIVE' 2>/dev/null"

    # 2. --- Actions ---------------
    # ------ Primary execution modes.
    
    arg_value @cmd --description "Command to execute" \
        --option-cmd "lx db --file 'cmds.db' --table 'commands' --select --cols 'command,description' --sep ' # ' 2>/dev/null"
    
    arg_value @alias --description "Execute a saved command alias" \
        --option-cmd "lx db --file 'cmds.db' --table 'commands' --select --cols 'alias,description' --sep ' # ' 2>/dev/null"
    
    arg_value @delete --description "Delete a saved command alias" \
        --option-cmd "lx db --file 'cmds.db' --table 'commands' --select --cols 'alias,description' --sep ' # ' 2>/dev/null"
    
    arg_value @edit --description "Edit a saved command alias" \
        --option-cmd "lx db --file 'cmds.db' --table 'commands' --select --cols 'alias,description' --sep ' # ' 2>/dev/null"
    
    arg_flag @list --description "List all saved commands"

    # 3. --- Options ---------------
    # ------ Modifiers and dependent arguments.
    
    # Options for --cmd
    arg_flag @run --description "Execute command directly" --depends-on "ARG_CMD"
    arg_value @save --description "Save command with an alias in cmds.db" --depends-on "ARG_CMD"

    # Options for --save
    arg_value @desc --description "Optional description for the saved command" --depends-on "ARG_SAVE"
    arg_value @devices --description "Allow command for specific devices (e.g., 'host_1,vm_1111' or 'all')" --depends-on "ARG_SAVE" --multi \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # '; lx db --file 'homelab_conf.db' --table 'observers' --select --cols 'id,name' --sep ' # '; cat '$FILE_CONTAINER_LIVE' 2>/dev/null; cat '$FILE_VM_LIVE' 2>/dev/null"
    
    # Options for --edit
    arg_value @edit_alias --description "New alias name" --depends-on "ARG_EDIT"
    arg_value @edit_cmd --description "New command string" --depends-on "ARG_EDIT"
    arg_value @edit_desc --description "New description" --depends-on "ARG_EDIT"
    arg_value @edit_devices --description "New device assignment" --depends-on "ARG_EDIT"
}

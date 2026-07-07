#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the files submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab files <action> [options]
#
# @actions          : --push   <device...|all>  | Push full device mirror(s) to the device(s)
#                     --fetch  <device>         | Fetch from device into mirror (FZF file browser)
#                     --delete <mirror-path...> | Delete on device(s) AND in local mirror
#                     --rename <mirror-path>    | Rename on device(s) AND in local mirror
#                     --goto   <mirror-dir>     | Open a mirror directory in the terminal
#
# @options          : --path      <dir>  (only with --fetch)  | Base directory to search on device
#                     --rename-to <name> (only with --rename) | New basename for the entry
#
# @notes            : Exactly one action per call — enforced in extension_start.
#                     No --fzf on the actions: with five parallel actions a bare call
#                     would chain FZF prompts. Values come from fish completion.
# ==============================================================================
function arguments {
    # 1. --- Actions ----------------------------------------------------------

    # Devices to push — 'all' expands to every device with a mirror directory.
    # Completion lists hosts, observers and all client mirrors (ct_<id>, vm_<id>).
    arg_value @push \
        --description "Device(s) to push (host_1, ct_3040, ... or 'all')" \
        --multi \
        --option "all # every device with a mirror directory" \
        --option-cmd "
            { get_hosts    | awk '{print \$1}';
              get_observers | awk '{print \$1}';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"

    # Device to fetch from — the remote file selection happens later via FZF
    # in the action itself (SSH helpers are not available in --option-cmd subshells).
    arg_value @fetch \
        --description "Device to fetch from (e.g. host_1, ct_3040)" \
        --option-cmd "
            { get_hosts    | awk '{print \$1}';
              get_observers | awk '{print \$1}';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"

    # Mirror paths to delete — completion lists all existing local mirror entries.
    arg_value @delete \
        --description "Local mirror path(s) to delete (on device and in mirror)" \
        --multi \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null | sort"

    # Mirror path to rename — completion lists all existing local mirror entries.
    arg_value @rename \
        --description "Local mirror path to rename (on device and in mirror)" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null | sort"

    # Mirror directory to open — unified types (host, observer) are listed directly,
    # client types scan their per-device subdirectories.
    arg_value @goto \
        --description "Device mirror directory to open in terminal" \
        --option-cmd "
            { echo '${PATH_EXTENSION_DATA}/mirror/host';
              echo '${PATH_EXTENSION_DATA}/mirror/observer';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null; } \
            | sort"

    # 2. --- Options ----------------------------------------------------------

    # Base directory on the device — free text, only relevant for --fetch.
    arg_value @path \
        --description "Base directory to search on device (e.g. /root or /opt/homelab)" \
        --depends-on "ARG_FETCH"

    # New name for the entry — only relevant for --rename.
    # Declared with underscore: @rename_to → CLI flag --rename-to → ARG_RENAME_TO.
    arg_value @rename_to \
        --description "New name for the entry" \
        --depends-on "ARG_RENAME"
}

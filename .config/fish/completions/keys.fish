# keys.fish - Completions for the 'keys' wrapper script

# Inherit all completions from rbw
complete -c keys -w rbw

# --- Custom Field Management (via bw) ---
# Only active when 'get' subcommand is present

set -l has_get "__fish_seen_subcommand_from get"

# --field / -f
complete -c keys -n "$has_get" -l field -s f -d "Modify an existing field"

# --add-field
complete -c keys -n "$has_get" -l add-field -d "Add a new custom field"

# Actions for --field (change, update, remove)
complete -c keys -n "$has_get; and __fish_contains_opt field" -a "change update remove delete" -d "Action"

# Options for --add-field
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l pass -d "Type: Hidden/Password (input hidden)"
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l hidden -d "Type: Hidden/Password (input hidden)"
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l text -d "Type: Text (visible, default)"
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l website -d "Type: Text (visible)"
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l bool -d "Type: Boolean"
complete -c keys -n "$has_get; and __fish_contains_opt add-field" -l value -d "Set the value directly"

# This file was created by fish when upgrading to version 4.3.
# Its purpose is to facilitate the migration of the 'fish_key_bindings' variable
# from its old default scope (universal) to its new default scope (global).
#
# It is generally recommended to delete this file once all fish instances
# on the system are upgraded to 4.3 or newer, and to configure key bindings
# directly in ~/.config/fish/config.fish if custom settings are needed.

# The following line was part of the migration strategy, but is now commented out
# as the key bindings should ideally be set in config.fish or handled by newer fish versions.
# set --global fish_key_bindings fish_default_key_bindings

# Prior to fish version 4.3, an event handler would reset `fish_key_bindings`
# to `fish_default_key_bindings` if the universal variable was erased.
# As a workaround to ensure proper migration and prevent older fish versions
# from reinstating the universal variable, it is explicitly erased at every shell startup.
# This ensures that newer configurations (e.g., from config.fish) take precedence.
set --erase --universal fish_key_bindings

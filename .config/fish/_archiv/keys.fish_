# Function: keys
# Description: Manages authentication for `rbw` (Bitwarden CLI) by automatically unlocking the vault.
# This function checks if `rbw` is unlocked and, if not, attempts to unlock it using a password
# retrieved from `pass` (GnuPG password manager) via an `expect` script.
function keys --description 'Manage Vaultwarden rbw keys' 
    # Check if `rbw` is currently unlocked.
	rbw unlocked
    # If `rbw` is not unlocked (exit status is not 0), proceed to unlock.
	if test $status -ne 0
        # First, synchronize the local Bitwarden database with the server.
		rbw sync
        # Retrieve the master password for Vaultwarden from the `pass` command.
		set -l pw (pass show vaultwarden)
        # Use `expect` to automate the `rbw unlock` process.
        # `log_user 0` prevents the spawned command's output from being printed.
        # `spawn rbw unlock` starts the unlock process.
        # `expect "Master Password:"` waits for the password prompt.
        # `send "$pw\r"` sends the retrieved password followed by a newline.
        # `expect eof` waits for the spawned process to finish.
		expect -c "
		log_user 0
		spawn rbw unlock
		expect \"Master Password:\"
		send \"$pw\r\"
		expect eof
		"
	end
    # Execute the original `rbw` command with all provided arguments.
    # `command rbw` ensures that the actual `rbw` executable is called, not this wrapper function recursively.
	command rbw $argv

end

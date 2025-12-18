function keys --description 'Mangage vaultwarden rbw keys' 
	rbw unlocked
	if test $status -ne 0
		rbw sync
		set -l pw (pass show vaultwarden)
		expect -c "
		log_user 0
		spawn rbw unlock
		expect \"Master Password:\"
		send \"$pw\r\"
		expect eof
		"
	end

	command rbw $argv

end

# Function: cd-ranger
# Description: Changes the current directory interactively using the Ranger file manager.
# When executed, Ranger is launched, allowing the user to navigate and select a directory.
# Upon exiting Ranger, the shell's current directory is changed to the selected path.
function cd-ranger

	# Create a temporary file to store the path of the directory chosen in Ranger.
	set -l tempfile '/tmp/cd-ranger'
	# Launch Ranger. The `--choosedir=$tempfile` option tells Ranger to write the
	# selected directory's path to the specified temporary file upon exit.
	# `(pwd)` ensures Ranger starts in the current working directory.
	ranger --choosedir=$tempfile (pwd)
	
	# Check if the temporary file was created (meaning a directory was selected).
	if test -f $tempfile
		# Read the selected directory path from the temporary file.
		# Check if the selected directory is different from the current working directory.
		if [ (cat $tempfile) != "(pwd)" ]
			# Change the shell's current directory to the path read from the file.
			cd (cat $tempfile)
		end
	end
	
	# Clean up and remove the temporary file regardless of whether a directory was changed.
	rm -f $tempfile
end

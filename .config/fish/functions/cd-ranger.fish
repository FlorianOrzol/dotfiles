# Description: Change directory using Ranger file manager in Fish shell
function cd-ranger

	# Create a temporary file to store the selected directory
	set -l tempfile '/tmp/cd-ranger'
	# Launch Ranger to choose a directory
	ranger --choosedir=$tempfile (pwd)
	# Change to the selected directory if it exists and is different from the current directory
	if test -f $tempfile
		# Read the selected directory and change to it
		if [ (cat $tempfile) != "(pwd)" ]
			# Change directory to the selected path
			cd (cat $tempfile)
		end
	end
	# Clean up the temporary file
	rm -f $tempfile
end

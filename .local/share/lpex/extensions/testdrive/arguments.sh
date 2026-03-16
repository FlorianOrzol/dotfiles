function arguments() {
	# There are the following types of arguments
	# ==========================================
	#
	# The arg_flag is used for flags without values.
	arg_flag @argument_name_flag
	# The Arguments would get the value '1'. You can check if flag is set by e.g. (( ARG_ARGUMENT_NAME_FLAG )) and it would be empty if the flag is not set.
	# The program call would be like 'lpex <extension> --argument-name' to set the flag.

	# The arg_value is used for arguments with values.
	arg_value @argument_name_value
	# The Arguments would be available as ARG_ARGUMENT_NAME (like 'echo $ARG_ARGUMENT_NAME' to get the value.  
	# The program call would be like 'lpex <extension> --argument-name value' to set the argument with value.

	# Option: --description
	arg_value @argument_description --description "This is an argument with description"
	# The --description is used to describe the argument. It is used in the help message.
	#	- It will be printed in fish completion as description of the argument.
	#	- and also in the fzf menu as description of the argument.
	#	- if no options are given, the description in fish shell would set be by a trick.
	#		if you start by 'lpex --argument-description "my text"<TAB> it will be shown as '_ my text (Enter free text)' in the fish completion.  
	
	# Option: --ask (in arg_flag)
	arg_flag @test-ask --ask --description "It would test the --ask option."
	# Use the --ask option in arg_flag to ask via fzf for setting the flag after program start.
	
	arg_value @file --type "file" --descrtiption "path to a file"
	arg_value @directory --type "dir" --description "path to a directory"
	
	# Option: --multi
	arg_value @argument_name_more_vals --multi
	# The --more-vals option is used to allow multiple values for the argument.
	# You can call the program by 'lpex <extension> --argument-name-more-vals value1 --argument-name-more-vals value2',
	# 	or 'lpex <extension> --argument-name-more-vals value1 value2' to set multiple values for the argument.
	# It would be available as an array ARG_ARGUMENT_NAME_MORE_VALS. You can check the values by 'echo ${ARG_ARGUMENT_NAME_MORE_VALS[@]}'.
	
	# Option: --option
	arg_value @argument_name_options \
		--option "option_1 # description for option 1" \
		--option "option_2 # description for option 2" \
		--option "option_3 # description for option 3"
	# The --option is used to define options for the argument.
	# There are only the defined options allowed to be set for the argument. 
	# :TESTIT: If you try to set a value that is not defined as an option, it would not be accepted.
	# The options would be shown in the fzf menu and also in the fish completion. The description for each option would be shown in both places as well.
	
	# Option: --option-cmd
	arg_value @argument_name_options_cmd --option-cmd \
	   "echo -e 'option_1 # description for option 1\noption_2 # description for option 2\noption_3 # description for option 3'"	
	# The --option-cmd is used to define options for the argument by a command. The command should output the options in the format 'option # description' for each option.
	
	# Option: --fzf
	arg_flag @argument_name_fzf --fzf
	# The --fzf option would start fzf after program start, if the argument is not set. 
	# The combination with --option or --option-cmd would show the options in the fzf menu. The --ask option would also trigger the fzf menu, but without the options from --option or --option-cmd.
	
	# Option: --ask (in arg_value)
	arg_value @argument_name_ask --ask
	# Use the --ask option in arg_value to ask via fzf for setting further value(s) after program start.


	# Obviously, you can combine the options as you like. For example, you can use --multi with --fzf, --ask.
	#
	# The regular arguments $1, $2, are not available in the extension.
	# Use the ARG_ARGUMENT_NAME variables instead to get the argument values!

}



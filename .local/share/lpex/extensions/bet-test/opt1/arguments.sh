function arguments() {
	arg_direct @key --description "The key to set the value for" \
		--option "aber doch" --option "doch nicht" --option "doch doch"
	arg_flag @key_flag --description "The key to set the value for (flag)"
	arg_value @key_value --description "The key to set the value for (value)"
}

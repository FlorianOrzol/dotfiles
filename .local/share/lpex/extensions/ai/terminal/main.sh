function extension_start() {

#		export OLLAMA_API_BASE="http://localhost:11434"
#		export OLLAMA_API_KEY="$API_KEY"

#		aider --model ollama/$ARG_MODEL ${ARG_ARGS[@]}
	# e.g. ARG_MODEL=kimi-k2.5:cloud, if version is not cloud, then...
	if [[ "$ARG_MODEL" == *":cloud"* ]]; then
		# if model is cloud, then we need to set the environment variable for cloud model
	#	export OLLAMA_API_BASE="http://api.ollama.com/v1"
		export OLLAMA_API_BASE="http://localhost:11434"
		export OLLAMA_API_KEY="$API_KEY"
		#output --info "-> aider --model \"ollama_chat/$ARG_MODEL\" \"${ARG_ARGS[@]}"
#		aider --model "ollama_chat/$ARG_MODEL" "${ARG_ARGS[@]}"
		aider --model ollama/$ARG_MODEL ${ARG_ARGS[@]} --architect --restore-chat-history --no-auto-commits
	else
		# if model is not cloud, then we need to set the environment variable for local model
		#output --info "-> aider --model \"ollama_chat/$ARG_MODEL\" \"${ARG_ARGS[@]}"
#		aider --model "ollama$ARG_MODEL" "${ARG_ARGS[@]}"
#
		#lx cmd --show-cmd --run "aider --model ollama/$ARG_MODEL ${ARG_ARGS[@]}"
		aider --model ollama/$ARG_MODEL ${ARG_ARGS[@]}
	fi
}

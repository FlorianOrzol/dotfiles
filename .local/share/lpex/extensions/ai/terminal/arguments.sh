function arguments() {

	path_models="/home/ollama_models/manifests/registry.ollama.ai/library"

	arg_value @model --option-cmd "
	for model in \$(ls $path_models); do
		for version in \$(ls $path_models/\$model/); do
			echo \"\$model:\$version\"
		done
	done"

	arg_value @args --depends-on "MODEL" --multi --description "additional arguments to pass to the model"
}

function extension_start() {
	lx cmd @name --run "read -p \"Enter your name: \" name && echo \"\$name\"" --log 
	lx cmd --run "echo 'ls' | fzf" --log

lx cmd --run "	for i in {1..10}; do
		echo \"Iteration \$i\" 
		sleep 1
	done" --log

	lx cmd --run "ls -la" --log
	lx cmd @withlog --run "ls -la" --log
	echo
	echo "output: Hello, $name!"
}

function extension_start() {
    output --section "LPEX V2 Test Drive (Automated Backend Test)"

    # --- 1. Test Output Engine ---
    output --info "Testing output levels..."
    output --ok "This is a success message."
    output --warn "This is a warning."
    output --error "This is an error (should go to stderr)."

    # --- 2. Test DB Engine (Raw and Direct) ---
    output --section "Testing Database Engine (__db)"
    
    local test_db="${PATH_EXTENSION_DATA}/my_test.db"
    
    # Init custom table
    lx db --file "my_test.db" --table "my_test" --create-table --cols "name TEXT, age INTEGER"
    
    # Insert data
    lx db --file "my_test.db" --table "my_test" --insert --data "name" "Alice" "age" "30"
    lx db --file "my_test.db" --table "my_test" --insert --data "name" "Bob" "age" "25"
    
    # Read data back into array
    local db_results=()
    lx db --file "my_test.db" --table "my_test" --select @db_results --cols "name, age" --order-by "age DESC"
    
    output --info "DB Results (Expected: Alice|30, then Bob|25):"
    for row in "${db_results[@]}"; do
        echo "  -> $row"
    done

    # --- 3. Test Log Engine (Custom Tables) ---
    output --section "Testing Logging Engine (__log)"
    
    # Write to generic log
    lx log --write --table "logs_generic" --data "message" "Backend test started." "level" "200" "tags" "test,backend"
    
    # Write to custom log table
    lx log --write --table "logs_metrics" --data "cpu_load" "45" "ram_usage" "1024"
    
    # Read back generic logs
    local log_results=()
    lx log --read --table "logs_generic" --limit 2 @log_results
    
    output --info "Recent Generic Logs:"
    for row in "${log_results[@]}"; do
        echo "  -> $row"
    done

    # --- 4. Test Command Engine (__cmd) ---
    output --section "Testing Command Engine (__cmd)"
    
    # Simple success command
    lx cmd --run "echo Hello from CMD" --show-cmd
    
    # Command with capture and quiet
    local cmd_out=""
    lx cmd @cmd_out --run "pwd" 
    output --ok "Captured PWD output silently: $cmd_out"
    
    # Command with failure (should not exit if --exit-on-fail is missing)
    output --info "Testing a failing command (should print error but continue):"
    lx cmd --run "ls /nonexistent_path_for_testing" --error-msg "Expected failure"
    
    # Command with logging
    output --info "Testing a command with database logging..."
    lx cmd --run "echo This should be in the DB" --log --log-tags "cmd_test"
    
    local cmd_log_results=()
    lx log --read --table "logs_cmd" --limit 1 @cmd_log_results
    output --info "Latest CMD Log from DB:"
    echo "  -> ${cmd_log_results[0]}"

    output --section "Test Complete"
}

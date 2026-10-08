function __fish_complete_test_lpex
    echo "DEBUG: Test Completion wurde aufgerufen!" >&2
    printf "hallo_test\tTestvorschlag\n"
end
complete -c test-lpex -f -a "(__fish_complete_test_lpex)"

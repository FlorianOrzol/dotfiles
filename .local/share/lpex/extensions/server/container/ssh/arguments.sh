function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    arg_value @ctid \
        --fzf \
        --description "Select Container" \
        --option-cmd "$(get_lxc_completion_cmd)"
}

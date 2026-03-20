function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    arg_value @ctid --fzf --description "Target Container" --option-cmd "$(get_lxc_completion_cmd)"
    arg_value @remote_file --description "Absolute path to file INSIDE the container (e.g. /etc/nginx/nginx.conf)"
}

#!/bin/bash
function arguments() {
    arg_value @node        --description "Target Proxmox Node" --option "pve101" --option "pve102" --option "pve103"
    arg_value @remote_file --description "Absolute path to the file or directory on the Host"
}

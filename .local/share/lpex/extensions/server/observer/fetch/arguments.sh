#!/bin/bash
function arguments() {
    arg_value @node        --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    arg_value @remote_file --description "Absolute path to the file or directory on the Observer"
}

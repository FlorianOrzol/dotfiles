#!/bin/bash
function arguments() {
    arg_value @files \
        --type "path" \
        --multi \
        --description "Files/Folders to add to the private repo"
}

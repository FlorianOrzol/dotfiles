#!/bin/bash
function arguments() {
    arg_value @files \
        --type "path" \
        --multi \
        --positional \
        --description "Files/Folders to add to the private repo"
}

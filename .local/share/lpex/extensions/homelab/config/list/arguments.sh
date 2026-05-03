#!/bin/bash
# @meta_name : config/list/arguments.sh
function arguments {
    # Keine Pflichtargumente — listet alle Einträge
    arg_value @filter --description "Optional filter string (e.g. HOST, OBSERVER, ZFS)"
}

#!/bin/bash
# @meta_name : config/add/arguments.sh
function arguments {
    arg_value @key   --description "New config key (e.g. IP_HOST_3, ZFS_POOL_4)"
    arg_value @value --description "Value for the new key"
}

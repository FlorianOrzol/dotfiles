#!/bin/bash
# ==============================================================================
# @meta_name        : config/push/main.sh
# @desc_short       : Generate homelab.conf from DB and deploy it to the leader observer.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/_generate.sh"

function extension_start {
    action_generate || return 1   # generate homelab.conf from DB; abort on failure
    action_deploy   || return 1   # deploy to leader observer; abort on failure
}

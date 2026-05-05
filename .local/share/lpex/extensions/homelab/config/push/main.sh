#!/bin/bash
# ==============================================================================
# @meta_name        : config/push/main.sh
# @desc_short       : homelab.conf generieren und auf observer_1 deployen.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/_generate.sh"

function extension_start {
    action_generate || return 1   # generate homelab.conf from DB; abort on failure
    action_deploy   || return 1   # deploy to leader observer; abort on failure
}

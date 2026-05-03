#!/bin/bash
# ==============================================================================
# @meta_name        : config/push/main.sh
# @desc_short       : homelab.conf generieren und auf observer_1 deployen.
# ==============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../_generate.sh"

function extension_start {
    action_generate || return 1
    action_deploy   || return 1
}

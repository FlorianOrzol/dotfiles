#!/bin/bash
# ==============================================================================
# @meta_name        : config/main.sh
# @desc_short       : homelab_conf.db verwalten und homelab.conf generieren.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/manage.sh"
source "$(dirname "${BASH_SOURCE[0]}")/generate.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short   : Validates action and routes to the correct function.
# ==============================================================================
function extension_start {
    # 1. --- Validate Action ---------------
    local action_count=0
    [[ -n "$ARG_LIST" ]]      && (( action_count++ ))
    [[ -n "$ARG_GENERATE" ]]  && (( action_count++ ))
    [[ -n "$ARG_DEPLOY" ]]    && (( action_count++ ))
    [[ -n "$ARG_FETCH" ]]     && (( action_count++ ))
    [[ -n "$ARG_HOST" ]]      && (( action_count++ ))
    [[ -n "$ARG_OBSERVER" ]]  && (( action_count++ ))
    [[ -n "$ARG_SHAREDATA" ]] && (( action_count++ ))
    [[ -n "$ARG_POOL" ]]      && (( action_count++ ))

    if (( action_count == 0 )); then
        ERROR "Keine Aktion angegeben. Verwende --list, --host, --observer, --sharedata, --pool, --generate, --deploy oder --fetch."
        return 1
    fi

    if (( action_count > 1 )); then
        ERROR "Nur eine Aktion gleichzeitig erlaubt."
        return 1
    fi

    # 2. --- Action Routing ---------------
    if [[ -n "$ARG_LIST" ]];      then action_list;           return $?; fi
    if [[ -n "$ARG_GENERATE" ]];  then action_generate;       return $?; fi
    if [[ -n "$ARG_DEPLOY" ]];    then action_deploy;         return $?; fi
    if [[ -n "$ARG_FETCH" ]];     then action_fetch;          return $?; fi
    if [[ -n "$ARG_HOST" ]];      then action_set_host;       return $?; fi
    if [[ -n "$ARG_OBSERVER" ]];  then action_set_observer;   return $?; fi
    if [[ -n "$ARG_SHAREDATA" ]]; then action_set_sharedata;  return $?; fi
    if [[ -n "$ARG_POOL" ]];      then action_set_pool;       return $?; fi
}

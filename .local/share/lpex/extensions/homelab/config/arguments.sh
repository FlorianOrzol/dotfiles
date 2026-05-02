#!/bin/bash
# ==============================================================================
# @meta_name        : config/arguments.sh
# @desc_short       : homelab_conf.db verwalten und homelab.conf generieren.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for config management.
# @usage            : lpex homelab config <action> [target] [options]
#
# @actions          : --list | --host | --observer | --sharedata | --pool
#                     --generate | --deploy | --fetch
# ==============================================================================
function arguments {
    # 1. --- Actions ---------------

    arg_flag  @list     --description "Alle Einträge aus homelab_conf.db anzeigen"
    arg_flag  @generate --description "homelab.conf aus DB generieren (lokal)"
    arg_flag  @deploy   --description "homelab.conf generieren und auf observer_1 pushen"
    arg_flag  @fetch    --description "homelab.conf von observer_1 zurückholen (Recovery)"
    arg_flag  @remove   --description "Eintrag aus DB löschen (mit --host / --observer / --pool)"

    # 2. --- Targets ---------------

    arg_value @host     --description "Host-ID (z.B. 1, 2, 3)"
    arg_value @observer --description "Observer-ID (z.B. 1, 2)"
    arg_flag  @sharedata --description "ShareData-Container konfigurieren"
    arg_value @pool     --description "ZFS-Dataset hinzufügen (z.B. pool_fast/data)"

    # 3. --- Device Options ---------------

    arg_value @name     --description "Logischer Name (z.B. host_3)"
    arg_value @ip       --description "IP-Adresse"
    arg_value @mac      --description "MAC-Adresse für WOL (nur Hosts)"
    arg_value @share_id --description "Container-ID des ShareData-LXC"
    arg_value @share_ip --description "IP-Adresse des ShareData-Containers"
}

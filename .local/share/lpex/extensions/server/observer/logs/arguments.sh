#!/bin/bash
# ==============================================================================
# @meta_module      : server observer logs
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer logs'.
#
# @arg_values       : --node      | Target Observer (pi1 or pi2)
# @arg_values       : --name      | Name of the systemd unit to inspect
# @arg_values       : --lines     | Number of lines to show in --no-follow mode (default: 50)
# @arg_values       : --since     | Show entries since this journalctl time string
# @arg_flags        : --no-follow | Display a snapshot instead of streaming live
# ==============================================================================
function arguments() {
    arg_value @node      --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    arg_value @name      --description "Name of the systemd unit (e.g. obs-heartbeat.service)"
    arg_flag  @no_follow --description "Show a snapshot instead of following live"
    arg_value @lines     --description "Number of lines to show in snapshot mode (default: 50)"
    arg_value @since     --description "Show entries since this time (e.g. '1h ago', 'yesterday')"
}

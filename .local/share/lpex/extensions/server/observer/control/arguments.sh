#!/bin/bash
# ==============================================================================
# @meta_module      : server observer control
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer control'.
#
# @arg_values       : --node    | Target Observer node (pi1 or pi2)
# @arg_flags        : --stop    | Graceful shutdown via ACPI SSH signal
# @arg_flags        : --restart | Graceful reboot via ACPI SSH signal
# ==============================================================================
function arguments() {
    arg_value @node    --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    arg_flag  @stop    --description "Graceful shutdown (sudo shutdown -h now)"
    arg_flag  @restart --description "Graceful reboot (sudo shutdown -r now)"
}

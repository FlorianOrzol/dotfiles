#!/bin/bash
# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers CLI arguments for the read-only inspection recipe.
# @usage            : lpex usb check [<device>]
#
# @devices          : <device>  (positional, e.g. /dev/sdb — fzf picker if omitted)
#
# @notes            : Show mode (-s) and unattended mode (-y) are global LPEX flags
# @notes            : and are handled by 'lx cmd' — no argument needed here.
# ==============================================================================
function arguments {
	arg_direct @device --description "Device to inspect" --fzf \
		--option-cmd "_usb_list_devices"
}

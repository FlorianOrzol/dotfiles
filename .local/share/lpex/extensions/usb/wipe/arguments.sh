#!/bin/bash
# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers CLI arguments for the wipe recipe.
# @usage            : lpex usb wipe [<device>] [options]
#
# @devices          : <device>  (positional, e.g. /dev/sdb — fzf picker if omitted)
# @options          : --full   overwrite the whole device instead of start and end
#
# @notes            : Show mode (-s) and unattended mode (-y) are global LPEX flags
# @notes            : and are handled by 'lx cmd' — no argument needed here.
# ==============================================================================
function arguments {
	arg_direct @device --description "Device to wipe" --fzf \
		--option-cmd "_usb_list_devices"

	arg_flag @full --description "Overwrite the entire device (takes a long time)"
}

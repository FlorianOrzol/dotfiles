#!/bin/bash
# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers CLI arguments for the image writing recipe.
# @usage            : lpex usb write <image> [<device>] [options]
#
# @devices          : <image>   (positional, first — path to the .iso/.img file)
#                     <device>  (positional, second — fzf picker if omitted)
# @options          : --no-verify  skip the byte comparison after writing
#
# @notes            : Show mode (-s) and unattended mode (-y) are global LPEX flags
# @notes            : and are handled by 'lx cmd' — no argument needed here.
# ==============================================================================
function arguments {
	arg_direct @image --description "Image file (.iso / .img)" --type file

	arg_value @device --description "Target device" --fzf \
		--option-cmd "_usb_list_devices"

	arg_flag @no_verify --description "Skip the byte comparison after writing"
}

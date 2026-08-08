#!/bin/bash
# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers CLI arguments for the format recipe.
# @usage            : lpex usb format [<device>] [options]
#
# @devices          : <device>  (positional, e.g. /dev/sdb — fzf picker if omitted)
# @options          : --fs     vfat | exfat | ext4   (required)
#                     --label  volume label (optional)
#                     --table  msdos | gpt   (default: msdos for vfat, else gpt)
#
# @notes            : Show mode (-s) and unattended mode (-y) are global LPEX flags
# @notes            : and are handled by 'lx cmd' — no argument needed here.
# ==============================================================================
function arguments {
	arg_direct @device --description "Target device" --fzf \
		--option-cmd "_usb_list_devices"

	arg_value @fs --description "Filesystem" --fzf \
		--option "vfat # FAT32 — readable everywhere, no file above 4 GB" \
		--option "exfat # large files, Windows/macOS/Linux" \
		--option "ext4 # Linux only, real permissions and journal"

	arg_value @label --description "Volume label (optional)"

	arg_value @table --description "Partition table (default: msdos for vfat, else gpt)" \
		--option "msdos # MBR — maximum compatibility, up to 2 TB" \
		--option "gpt # modern, beyond 2 TB, ignored by some old devices"
}

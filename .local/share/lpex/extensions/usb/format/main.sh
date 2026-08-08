#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Sets up a USB stick from scratch (validation and routing).
# @desc_detailed    : Validates the target and the requested filesystem, then hands
# @desc_detailed    : over to _action_format, which holds the actual step chain.
# ==============================================================================

# source action files — must be explicit, LPEX does not auto-load _*.sh
source "${PATH_EXTENSION}/_format.sh"

function extension_start {
	local usb_device=""

	if [[ -z "$ARG_FS" ]]; then
		ERROR "No filesystem given."
		INFO  "Example: usb format /dev/sdb --fs vfat --label DATA"
		return 1
	fi

	# Only these three are covered by the recipe — anything else would be guesswork
	case "$ARG_FS" in
		vfat|exfat|ext4) ;;
		*) ERROR "Unknown filesystem: ${ARG_FS} (allowed: vfat, exfat, ext4)"; return 1 ;;
	esac

	_usb_resolve_device @usb_device || return 1

	_action_format "$usb_device"
}

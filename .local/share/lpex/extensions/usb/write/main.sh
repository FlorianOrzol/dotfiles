#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Writes an ISO/IMG image onto a USB device and verifies it.
# @desc_detailed    : The image is copied raw onto the device — no partitioning, no
# @desc_detailed    : filesystem. Afterwards the written bytes are compared against
# @desc_detailed    : the source file, which catches a silently failing stick.
# ==============================================================================

function extension_start {
	local usb_device=""
	local image_path="$ARG_IMAGE"
	local image_size_bytes=""

	if [[ -z "$image_path" ]]; then
		ERROR "No image file given."
		INFO  "Example: usb write ~/Downloads/archlinux.iso --device /dev/sdb"
		return 1
	fi

	if [[ ! -f "$image_path" ]]; then
		ERROR "Image file not found: ${image_path}"
		return 1
	fi

	_usb_resolve_device @usb_device || return 1

	# Needed for the byte comparison. No --confirm on purpose: this lookup must run
	# in every mode, otherwise the verify command below has no length to work with.
	lx cmd --run "stat -c%s '${image_path}'" @image_size_bytes --quiet

	_usb_confirm_target "$usb_device" || return 1
	_usb_require_root || return 1

	SECTION "Write image: $(basename "$image_path") -> ${usb_device}"

	lx cmd --run "ls -lh '${image_path}'; lsblk -o PATH,SIZE ${usb_device}" \
		--title "Cross-check image size against target size" \
		--note  "The image must be smaller than the stick, or dd aborts halfway through" \
		--note  "Image: ${image_size_bytes} bytes"

	lx cmd --run "lsblk -nrpo MOUNTPOINTS ${usb_device} | awk 'NF' | xargs -r sudo umount -v" \
		--title "Unmount every mounted partition of the device" \
		--note  "dd writes past the filesystem layer — a mounted device would end up corrupt" \
		--confirm --log --log-tags "usb,write" || return 1

	lx cmd --run "sudo dd if='${image_path}' of=${usb_device} bs=4M status=progress oflag=direct conv=fsync" \
		--title "Write the image raw onto the device" \
		--note  "of=${usb_device} — onto the DEVICE, not onto a partition" \
		--note  "bs=4M makes dd fast, oflag=direct bypasses the page cache" \
		--note  "conv=fsync makes dd return only once everything reached the stick" \
		--danger --log --log-tags "usb,write" || return 1

	lx cmd --run "sync && sudo udevadm settle" \
		--title "Flush the write buffers" \
		--note  "Pulling the stick too early is the most common cause of broken images" \
		--confirm --log --log-tags "usb,write" || return 1

	# The comparison reads the whole stick back — slow on large images, hence skippable
	if (( ARG_NO_VERIFY )); then
		INFO "Byte comparison skipped (--no-verify)."
	else
		lx cmd --run "sudo cmp -n ${image_size_bytes} '${image_path}' ${usb_device}" \
			--title "Compare the written bytes against the source" \
			--note  "-n limits the comparison to the length of the image" \
			--note  "No output means identical. Any message means a broken stick or an aborted write" \
			--confirm --log --log-tags "usb,write" || return 1
	fi

	OK "Image written."
	INFO "Eject safely with: udisksctl power-off -b ${usb_device}"
}

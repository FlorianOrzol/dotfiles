#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Read-only inspection of a USB device.
# @desc_detailed    : Answers the two questions asked before and after every other
# @desc_detailed    : recipe: is this the right stick, and did the result turn out
# @desc_detailed    : as intended. Changes nothing, therefore no command is gated.
# ==============================================================================

function extension_start {
	local usb_device=""

	_usb_resolve_device @usb_device || return 1

	# blkid and fdisk read the raw device — ask for the password once, not per step
	_usb_require_root || return 1

	SECTION "Inspect USB device: ${usb_device}"

	lx cmd --run "lsblk -o PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS ${usb_device}" \
		--title "Device and partitions at a glance" \
		--note  "TYPE 'disk' is the stick itself, 'part' are its partitions" \
		--note  "Partitions adding up to less than the disk means space lies idle" \
		--log --log-tags "usb,check"

	lx cmd --run "sudo blkid ${usb_device}*" \
		--title "Filesystems and UUIDs" \
		--note  "blkid reads the signatures off the device, not from a cache" \
		--note  "No output means there is no recognizable filesystem" \
		--log --log-tags "usb,check" --no-error-msg

	lx cmd --run "sudo fdisk -l ${usb_device}" \
		--title "Partition table and sector boundaries" \
		--note  "'Disklabel type' is either 'gpt' or 'dos' (= MBR)" \
		--note  "That type decides whether old devices can read the stick at all" \
		--log --log-tags "usb,check" --no-error-msg

	lx cmd --run "udevadm info --query=property --name=${usb_device} | grep -E '^ID_(VENDOR|MODEL|SERIAL_SHORT|BUS)='" \
		--title "Which stick is this physically?" \
		--note  "The serial number tells two identical sticks apart" \
		--log --log-tags "usb,check" --no-error-msg

	OK "Inspection finished."
}

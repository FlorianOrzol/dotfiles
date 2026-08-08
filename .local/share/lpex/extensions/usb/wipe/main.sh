#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Removes every trace of previous content from a USB device.
# @desc_detailed    : Targets the case where a stick still shows leftovers of an old
# @desc_detailed    : ISO or a second, hidden partition table. Zeroes the start and
# @desc_detailed    : the end of the device, because GPT keeps a backup header in
# @desc_detailed    : the last sectors.
# ==============================================================================

function extension_start {
	local usb_device=""
	local device_size_bytes=""
	local seek_position=""

	_usb_resolve_device @usb_device || return 1
	_usb_confirm_target "$usb_device" || return 1
	_usb_require_root || return 1

	SECTION "Wipe USB: ${usb_device}"

	lx cmd --run "lsblk -nrpo MOUNTPOINTS ${usb_device} | awk 'NF' | xargs -r sudo umount -v" \
		--title "Unmount every mounted partition of the device" \
		--note  "As long as something is mounted the kernel refuses to reread the table" \
		--confirm --log --log-tags "usb,wipe" || return 1

	lx cmd --run "sudo wipefs -a ${usb_device}" \
		--title "Remove all filesystem and partition table signatures" \
		--note  "wipefs knows the signatures of all common filesystems and finds them" \
		--note  "even when no partition table points at them anymore" \
		--danger --log --log-tags "usb,wipe" || return 1

	# Whatever wipefs leaves behind sits in the first and last megabytes: bootloader
	# code at the front, the GPT backup header at the very end of the device.
	if (( ARG_FULL )); then
		lx cmd --run "sudo dd if=/dev/zero of=${usb_device} bs=4M status=progress conv=fsync" \
			--title "Overwrite the entire device with zeroes" \
			--note  "Takes a good ten minutes on a 32 GB stick — only needed before giving it away" \
			--note  "status=progress keeps reporting throughput and remaining data" \
			--danger --log --log-tags "usb,wipe" || return 1
	else
		lx cmd --run "sudo dd if=/dev/zero of=${usb_device} bs=1M count=16 status=progress conv=fsync" \
			--title "Zero the first 16 MB (boot sector and primary table header)" \
			--note  "MBR boot code and the primary GPT header live here" \
			--note  "conv=fsync forces the write onto the medium instead of into the cache" \
			--danger --log --log-tags "usb,wipe" || return 1

		# GPT stores a backup header in the last sectors — target 16 MiB before the end.
		# This lookup must run in every mode, otherwise the next command has no seek value.
		lx cmd --run "lsblk -bdno SIZE ${usb_device} | tr -d ' '" @device_size_bytes --quiet
		seek_position=$(( device_size_bytes / 1048576 - 16 ))

		lx cmd --run "sudo dd if=/dev/zero of=${usb_device} bs=1M seek=${seek_position} count=16 conv=fsync" \
			--title "Zero the last 16 MB (GPT backup header)" \
			--note  "GPT keeps a second copy of the table at the end of the device" \
			--note  "Without this step the old partitioning keeps reappearing" \
			--note  "seek=${seek_position} = size in MB minus 16, derived from lsblk -bdno SIZE" \
			--danger --log --log-tags "usb,wipe" || return 1
	fi

	lx cmd --run "sudo partprobe ${usb_device} && sudo udevadm settle" \
		--title "Let the kernel read the now empty table" \
		--note  "Only afterwards do stale device nodes like ${usb_device}1 disappear" \
		--confirm --log --log-tags "usb,wipe" || return 1

	lx cmd --run "sudo wipefs ${usb_device}; lsblk -o PATH,SIZE,TYPE,FSTYPE,LABEL ${usb_device}" \
		--title "Verify that nothing is left" \
		--note  "wipefs WITHOUT -a deletes nothing, it only lists what it finds" \
		--note  "No wipefs output and no 'part' line means the stick is blank"

	OK "Stick is blank."
	INFO "Continue with: usb format ${usb_device} --fs vfat --label DATA"
}

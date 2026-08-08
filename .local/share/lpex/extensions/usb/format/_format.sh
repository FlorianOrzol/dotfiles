#!/bin/bash
# ==============================================================================
# @meta_name        : _format.sh
# @desc_short       : Step chain that rebuilds a USB stick from scratch.
# @desc_detailed    : Sourced by format/main.sh. Every command that changes the
# @desc_detailed    : device carries --confirm (destructive ones --danger), so the
# @desc_detailed    : show mode displays exactly what the execute mode would run.
# ==============================================================================


# --- _action_format ---
# @desc_short       : Wipes a device and creates a single partition with a filesystem.
# @usage            : _action_format <device>
# @parameter        : $1 | device_path | Validated target device, e.g. /dev/sdb.
# Returns: 0 when the recipe completed, 1 on abort or failure.
# ================================================================================
function _action_format {
	local device_path="$1"
	local fs_type="$ARG_FS"
	local label_value="$ARG_LABEL"
	local table_type="$ARG_TABLE"
	local partition_path=""
	local parted_fs_hint=""
	local mkfs_command=""
	local label_option=""

	partition_path="$(_usb_partition_path "$device_path" 1)"

	# 1. --- Derive the toolchain from the requested filesystem ---------------
	# ------ parted needs a type hint so the partition ID matches the filesystem
	case "$fs_type" in
		vfat)
			parted_fs_hint="fat32"
			mkfs_command="sudo mkfs.vfat -F 32"
			label_option="-n"
			_usb_require_tool "mkfs.vfat" "dosfstools" || return 1
			;;
		exfat)
			# exFAT uses the same MBR partition ID (0x07) as NTFS
			parted_fs_hint="ntfs"
			mkfs_command="sudo mkfs.exfat"
			label_option="-n"
			_usb_require_tool "mkfs.exfat" "exfatprogs" || return 1
			;;
		ext4)
			parted_fs_hint="ext4"
			mkfs_command="sudo mkfs.ext4"
			label_option="-L"
			_usb_require_tool "mkfs.ext4" "e2fsprogs" || return 1
			;;
	esac

	_usb_require_tool "parted" "parted" || return 1

	# 2. --- Choose the partition table ---------------------------------------
	# ------ MBR is the safer default for FAT32: car radios, TVs and BIOS setups
	# ------ frequently ignore a GPT-partitioned stick entirely.
	if [[ -z "$table_type" ]]; then
		if [[ "$fs_type" == "vfat" ]]; then table_type="msdos"; else table_type="gpt"; fi
	fi

	# 3. --- Normalize the label ----------------------------------------------
	# ------ FAT32 labels are stored uppercase and are limited to 11 characters
	if [[ "$fs_type" == "vfat" && -n "$label_value" ]]; then
		local label_normalized="${label_value^^}"
		label_normalized="${label_normalized:0:11}"

		[[ "$label_normalized" != "$label_value" ]] && \
			WARN "FAT32 label adjusted to '${label_normalized}' (uppercase, 11 characters max)."

		label_value="$label_normalized"
	fi

	# Without a label the mkfs call simply omits the option
	local mkfs_full="$mkfs_command"
	[[ -n "$label_value" ]] && mkfs_full="${mkfs_command} ${label_option} ${label_value}"

	# 4. --- Confirm the target and run the chain ------------------------------
	_usb_confirm_target "$device_path" || return 1
	_usb_require_root || return 1

	SECTION "Format USB: ${device_path} -> ${fs_type} (${table_type})"

	lx cmd --run "lsblk -nrpo MOUNTPOINTS ${device_path} | awk 'NF' | xargs -r sudo umount -v" \
		--title "Unmount every mounted partition of the device" \
		--note  "lsblk lists device and partitions, awk 'NF' drops the empty lines" \
		--note  "xargs -r never calls umount when nothing is mounted at all" \
		--confirm --log --log-tags "usb,format" || return 1

	lx cmd --run "sudo wipefs -a ${device_path}" \
		--title "Remove all signatures, including hidden partition tables" \
		--note  "-a removes ALL signatures (filesystem, RAID, partition table)" \
		--note  "This is the step against leftovers of an old ISO on the stick" \
		--danger --log --log-tags "usb,format" || return 1

	lx cmd --run "sudo parted -s ${device_path} mklabel ${table_type}" \
		--title "Create a fresh partition table (${table_type})" \
		--note  "-s is script mode, parted asks nothing interactively" \
		--note  "msdos = MBR (compatible, up to 2 TB), gpt = modern and larger" \
		--danger --log --log-tags "usb,format" || return 1

	lx cmd --run "sudo parted -s -a optimal ${device_path} mkpart primary ${parted_fs_hint} 0% 100%" \
		--title "One partition spanning the whole stick" \
		--note  "-a optimal aligns the start to the block size, which matters for speed" \
		--note  "0% 100% instead of fixed MB values — parted computes the bounds itself" \
		--note  "'${parted_fs_hint}' only sets the partition ID, it formats nothing yet" \
		--confirm --log --log-tags "usb,format" || return 1

	lx cmd --run "sudo partprobe ${device_path} && sudo udevadm settle" \
		--title "Let the kernel read the new table" \
		--note  "Without this ${partition_path} does not exist for the kernel yet" \
		--note  "udevadm settle waits until the device nodes are really created" \
		--confirm --log --log-tags "usb,format" || return 1

	lx cmd --run "${mkfs_full} ${partition_path}" \
		--title "Create the filesystem (${fs_type})" \
		--note  "Note the target: the PARTITION (${partition_path}), not the device" \
		--note  "A filesystem straight on ${device_path} works on Linux, but Windows sees an empty stick" \
		--danger --log --log-tags "usb,format" || return 1

	lx cmd --run "lsblk -o PATH,SIZE,TYPE,FSTYPE,LABEL ${device_path}" \
		--title "Result check" \
		--note  "FSTYPE and LABEL must now appear on ${partition_path}"

	OK "Stick is ready."
	INFO "Eject safely with: udisksctl power-off -b ${device_path}"

	return 0
}

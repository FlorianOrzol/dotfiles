#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 1.0.0
# @meta_date        : 2026-08-06
#
# @desc_short       : Shared device selection and safety layer for all usb recipes.
# @desc_detailed    : Auto-sourced by LPEX for every 'usb' submodule and also by the
# @desc_detailed    : fish completion, so the listing helpers can be used inside
# @desc_detailed    : '--option-cmd' as well.
#
# @req_packages     : util-linux (lsblk, findmnt), fzf
#
# @notes            : _usb_guard is the one function that must never be bypassable.
# @notes            : It refuses any disk carrying /, /boot, /home, /usr, /var or swap
# @notes            : and is enforced independently of -y.
# ==============================================================================


# ==============================================================================
# --- USB Configuration ---
# Adjust these to change which devices are offered and which are protected.
# ==============================================================================
function _usb_globals {
	# Mountpoints that mark a disk as "system disk" — never writable by a recipe
	USB_PROTECTED_MOUNTS='^(/|/boot|/boot/.*|/home|/usr|/usr/.*|/var|/var/.*|/etc|\[SWAP\])$'

	# Transports offered in the device picker; everything else must be typed out
	USB_ALLOWED_TRANSPORTS='usb'
}
_usb_globals                               # Initialize defaults on source


# ==============================================================================
# --- Device Listing ---
# Used by the fzf picker and by '--option-cmd' inside arguments.sh.
# ==============================================================================

# --- _usb_list_devices ---
# @desc_short       : Lists removable/USB disks as "path # size model" lines.
# @usage            : _usb_list_devices
# Returns: 0 always; prints nothing when no matching device is attached.
# ================================================================================
function _usb_list_devices {
	# Fall back to the default when running inside the detached completion shell,
	# where only the function itself is exported and no globals are set
	local allowed_transports="${USB_ALLOWED_TRANSPORTS:-usb}"

	# TRAN holds the transport (usb/sata/nvme), RM marks removable media
	lsblk -dno PATH,SIZE,TRAN,RM,MODEL 2>/dev/null | while read -r path size tran rm model; do
		# Keep USB devices and anything the kernel flags as removable
		[[ "$tran" =~ $allowed_transports ]] || [[ "$rm" == "1" ]] || continue
		printf '%s # %s %s\n' "$path" "$size" "$model"
	done

	return 0
}

# '--option-cmd' is executed via 'bash -c', a child process that does not inherit
# shell functions — exporting is what makes the picker work in the fish completion
export -f _usb_list_devices


# --- _usb_describe_device ---
# @desc_short       : Prints size, model and partition layout of one device.
# @usage            : _usb_describe_device <device>
# @parameter        : $1 | device_path | Block device, e.g. /dev/sdb.
# ================================================================================
function _usb_describe_device {
	local device_path="$1"

	lsblk -o PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$device_path" 2>/dev/null

	return 0
}


# ==============================================================================
# --- Device Selection & Safety ---
# Every recipe resolves its target through _usb_resolve_device, which always runs
# the guard. No recipe may take $ARG_DEVICE directly.
# ==============================================================================

# --- _usb_pick_device ---
# @desc_short       : Opens an fzf picker over all removable devices.
# @usage            : _usb_pick_device @device_path
# @parameter        : $1 | @return var | Receives the selected device path.
# Returns: 0 on selection, 1 when nothing was attached or the user aborted.
# ================================================================================
function _usb_pick_device {
	local -n return_usb_pick_device="${1#@}"
	local device_list=""
	local selected_device=""

	device_list="$(_usb_list_devices)"

	# Without any removable device an fzf popup would just be an empty box
	if [[ -z "$device_list" ]]; then
		ERROR "No removable device found."
		INFO  "Stick plugged in? Check with: lsblk -o PATH,SIZE,TRAN,RM,MODEL"
		return 1
	fi

	lx fzf @selected_device \
		--list "$device_list" \
		--header "Select the target device:" \
		--prompt "Device> " \
		--preview-bash "lsblk -o PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS {1}" \
		--standard --return-first-word

	[[ -z "$selected_device" ]] && return 1

	return_usb_pick_device="$selected_device"
	return 0
}


# --- _usb_guard ---
# @desc_short       : Refuses devices that carry the running system.
# @usage            : _usb_guard <device>
# @parameter        : $1 | device_path | Block device to validate.
# Returns: 0 when the device may be written, 1 when it must not be touched.
# ================================================================================
function _usb_guard {
	local device_path="$1"
	local mountpoint=""

	# Walk the device and all of its partitions; lsblk prints one line per node
	while read -r mountpoint; do
		[[ -z "$mountpoint" ]] && continue

		# A single system mountpoint disqualifies the whole disk
		if [[ "$mountpoint" =~ $USB_PROTECTED_MOUNTS ]]; then
			ERROR "Refused: ${device_path} carries the running system (${mountpoint})."
			INFO  "The usb recipes never touch this device, not even with -y."
			return 1
		fi
	done < <(lsblk -nrpo MOUNTPOINTS "$device_path" 2>/dev/null)

	return 0
}


# --- _usb_resolve_device ---
# @desc_short       : Turns $ARG_DEVICE (or an fzf pick) into a validated device path.
# @usage            : _usb_resolve_device @device_path
# @parameter        : $1 | @return var | Receives the validated device path.
# Returns: 0 when a safe, existing block device was resolved, 1 otherwise.
# ================================================================================
function _usb_resolve_device {
	local -n return_usb_resolve_device="${1#@}"
	local resolved_device="$ARG_DEVICE"

	# No device given on the CLI — let the user pick one interactively
	if [[ -z "$resolved_device" ]]; then
		_usb_pick_device @resolved_device || return 1
	fi

	# Accept the short form 'sdb' as well as the full path
	[[ "$resolved_device" != /* ]] && resolved_device="/dev/${resolved_device}"

	if [[ ! -b "$resolved_device" ]]; then
		ERROR "Not a block device: ${resolved_device}"
		INFO  "Available devices: lsblk -o PATH,SIZE,TRAN,RM,MODEL"
		return 1
	fi

	# The hard block — runs before anything is printed or executed
	_usb_guard "$resolved_device" || return 1

	return_usb_resolve_device="$resolved_device"
	return 0
}


# --- _usb_partition_path ---
# @desc_short       : Builds the path of a partition on a device.
# @usage            : _usb_partition_path <device> [number]
# @parameter        : $1 | device_path      | Base device, e.g. /dev/sdb or /dev/nvme0n1.
# @parameter        : $2 | partition_number | Partition index, default 1.
# ================================================================================
function _usb_partition_path {
	local device_path="$1"
	local partition_number="${2:-1}"

	# Devices whose name ends in a digit (nvme0n1, mmcblk0, loop0) get a 'p' separator
	if [[ "$device_path" =~ [0-9]$ ]]; then
		echo "${device_path}p${partition_number}"
	else
		echo "${device_path}${partition_number}"
	fi

	return 0
}


# --- _usb_confirm_target ---
# @desc_short       : Shows the target and demands the device name to be typed out.
# @usage            : _usb_confirm_target <device>
# @parameter        : $1 | device_path | The device that is about to be destroyed.
# Returns: 0 when confirmed or in show mode, 1 when the input did not match.
# ================================================================================
function _usb_confirm_target {
	local device_path="$1"
	local typed_name=""
	local expected_name="${device_path##*/}"

	SUBSECTION "Target device"
	_usb_describe_device "$device_path"

	# Show mode never destroys anything, so it must not demand a confirmation
	(( ${ARG_ONLY_SHOW:-0} )) && return 0

	WARN "Every byte on ${device_path} will be lost."

	# The @var must come BEFORE --prompt: __input collects every following non-flag
	# token into the prompt text, so a trailing @var would be swallowed by it
	lx input @typed_name --prompt "Type the device name to confirm (${expected_name})"

	# A plain yes is too cheap for a destructive operation — the name must match
	if [[ "$typed_name" != "$expected_name" ]]; then
		ERROR "Input '${typed_name}' does not match '${expected_name}' — aborted."
		return 1
	fi

	return 0
}


# ==============================================================================
# --- Preconditions ---
# Checks a recipe runs before its first step, so it fails early and loudly
# instead of dying halfway through.
# ==============================================================================

# --- _usb_require_tool ---
# @desc_short       : Ensures an external tool exists, otherwise names the package.
# @usage            : _usb_require_tool <command> [package]
# @parameter        : $1 | tool_name    | Command that must be callable.
# @parameter        : $2 | package_name | Pacman package providing it (default: $1).
# Returns: 0 when available, 1 otherwise.
# ================================================================================
function _usb_require_tool {
	local tool_name="$1"
	local package_name="${2:-$1}"

	command -v "$tool_name" >/dev/null 2>&1 && return 0

	ERROR "Required tool is missing: ${tool_name}"
	INFO  "Install it with: sudo pacman -S ${package_name}"
	return 1
}


# --- _usb_require_root ---
# @desc_short       : Obtains a sudo timestamp once, so no step stalls on a hidden prompt.
# @usage            : _usb_require_root
# Returns: 0 when root is available or not needed, 1 when authentication failed.
# ================================================================================
function _usb_require_root {
	# Show mode executes nothing, so it must never ask for a password
	(( ${ARG_ONLY_SHOW:-0} )) && return 0

	# Refreshes the sudo timestamp, prompting only if it is not cached yet
	if ! sudo -v; then
		ERROR "No sudo privileges granted — recipe aborted."
		return 1
	fi

	return 0
}

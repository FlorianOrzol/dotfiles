#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @meta_author      : Florian Orzol <florian.orzol@gmail.com>
# @meta_version     : 1.0.0
# @meta_date        : 2026-08-06
#
# @desc_short       : Shared printer and project helpers for all label recipes.
# @desc_detailed    : Auto-sourced by LPEX for every 'label' submodule and by the
# @desc_detailed    : fish completion. All configurable values come from
# @desc_detailed    : ~/.local/state/lpex/data/label/config.conf.
#
# @req_packages     : glabels, cups (lp, lpstat, lpoptions)
# @config_env       : PRINTER_LABEL, PATH_LABEL_PROJECTS, LABEL_MEDIA_DEFAULT
# ==============================================================================


# ==============================================================================
# --- Listing Helpers ---
# Used inside '--option-cmd', which runs in a detached 'bash -c'. Every function
# used there must be exported and must not rely on unexported globals.
# ==============================================================================

# --- _label_list_projects ---
# @desc_short       : Lists all .glabels project files of the configured directory.
# @usage            : _label_list_projects
# ================================================================================
function _label_list_projects {
	local path_projects="${PATH_LABEL_PROJECTS:-${HOME}/Dokumente/labels}"

	[[ -d "$path_projects" ]] || return 0

	# Print path plus filename as description, so fzf shows a readable second column
	find "$path_projects" -maxdepth 2 -type f -name "*.glabels" 2>/dev/null | while read -r project_file; do
		printf '%s # %s\n' "$project_file" "$(basename "$project_file" .glabels)"
	done

	return 0
}
export -f _label_list_projects


# --- _label_list_media ---
# @desc_short       : Lists the page sizes the label printer accepts.
# @usage            : _label_list_media
# ================================================================================
function _label_list_media {
	local printer_name="${PRINTER_LABEL:-Brother_QL-600}"

	# 'lpoptions -l' prints "PageSize/Media Size: a b *c" — the star marks the default
	lpoptions -p "$printer_name" -l 2>/dev/null \
		| awk -F': ' '/^PageSize/ { print $2 }' \
		| tr ' ' '\n' \
		| sed 's/^\*//' \
		| awk 'NF'

	return 0
}
export -f _label_list_media


# ==============================================================================
# --- Printer State ---
# The QL-600 pauses its queue whenever it is switched off, and stays paused after
# it comes back. Every recipe therefore checks the queue before printing.
# ==============================================================================

# --- _label_printer_name ---
# @desc_short       : Returns the configured printer, falling back to the CUPS default.
# @usage            : _label_printer_name @printer_name
# @parameter        : $1 | @return var | Receives the queue name.
# Returns: 0 when a queue was found, 1 when CUPS knows none.
# ================================================================================
function _label_printer_name {
	local -n return_label_printer_name="${1#@}"
	local queue_name="$PRINTER_LABEL"

	# Without configuration fall back to the first queue whose name mentions QL
	[[ -z "$queue_name" ]] && queue_name="$(lpstat -p 2>/dev/null | awk '/QL/ {print $2; exit}')"

	if [[ -z "$queue_name" ]]; then
		ERROR "Kein Etikettendrucker gefunden."
		INFO  "Warteschlangen anzeigen: lpstat -p"
		INFO  "Danach eintragen mit: lpex --config label"
		return 1
	fi

	return_label_printer_name="$queue_name"
	return 0
}


# --- _label_warn_if_paused ---
# @desc_short       : Warns when the queue is paused and names the command that fixes it.
# @usage            : _label_warn_if_paused <printer>
# @parameter        : $1 | printer_name | CUPS queue to inspect.
# ================================================================================
function _label_warn_if_paused {
	local printer_name="$1"
	local printer_state=""

	printer_state="$(lpoptions -p "$printer_name" 2>/dev/null | grep -o 'printer-state-reasons=[^ ]*')"

	# A paused queue accepts jobs silently and never prints them — the classic trap
	if [[ "$printer_state" == *paused* ]]; then
		WARN "Warteschlange ${printer_name} ist angehalten — Aufträge bleiben liegen."
		INFO "Freigeben mit: sudo cupsenable ${printer_name}   (oder: label status)"
	fi

	return 0
}

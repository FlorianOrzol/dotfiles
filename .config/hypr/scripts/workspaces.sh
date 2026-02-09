#!/bin/bash
#
#   _____        _
#  |~>   |     ('v') 
#  /:::::\    /{w w}\ 
# --------------------------------
# Copyright Florian Orzol
#
# description:
# date: 2025-09-12
# version:  0.0.1
#
#    <')
# \_;( )
# >>>> START SCRIPT <<<< #
#



MONITOR_MAIN_NAME="DP-1"
MONITOR_LEFT_NAME="HDMI-A-1"
MONITOR_RIGHT_NAME="HDMI-A-2"
MONITOR_MAIN_ID="0"
MONITOR_LEFT_ID="2"
MONITOR_RIGHT_ID="1"
MONITOR_INFO_ID="3"


#MONITOR_MAIN_ID="$(hyprctl -j monitors | jq -r ".[] | select(.name==\"$MONITOR_MAIN_NAME\") | .id")"
#MONITOR_LEFT_ID="$(hyprctl -j monitors | jq -r ".[] | select(.name==\"$MONITOR_LEFT_NAME\") | .id")"
#MONITOR_RIGHT_ID="$(hyprctl -j monitors | jq -r ".[] | select(.name==\"$MONITOR_RIGHT_NAME\") | .id")"
#MONITOR_INFO_ID="$(hyprctl -j monitors | jq -r ".[] | select(.name==\"$MONITOR_INFO_NAME\") | .id")"

DIR_TMP_AVAILABLE_DESKTOPS="/tmp/.hyprland/available-desktops"
DIR_TMP_ACTIVE_WORKSPACES="/tmp/.hyprland/active-workspaces"

SLEEP_TIME=0




# Create tmp directories if they don't exist
[[ ! -d "$DIR_TMP_AVAILABLE_DESKTOPS" ]] && mkdir -p "$DIR_TMP_AVAILABLE_DESKTOPS"
[[ ! -d "$DIR_TMP_ACTIVE_WORKSPACES" ]] && mkdir -p "$DIR_TMP_ACTIVE_WORKSPACES"

#Create symlink for this script in /usr/local/bin if it doesn't exist
[[ ! -L "/usr/local/bin/workspaces" ]] && ln -s "$(realpath "$0")" /usr/local/bin/workspaces










# show all Desktops and Workspaces
function Show_all_Desktops_and_Workspaces() {
	local savedDesktops=()
	Get_saved_Desktops_ID savedDesktops
	local savedNamedDesktops=($(ls $DIR_TMP_AVAILABLE_DESKTOPS/* 2>/dev/null | xargs -n 1 basename | sort -V))
	local desktopID workspaceID

	local activeWorkspaceID="$(Get_current_Workspace_ID)"

	
	local workspacesOnDesktop=()
	#for desktop in "${savedDesktops[@]}"; do
	for desktop in "${savedNamedDesktops[@]}"; do

		[[ "${desktop:0:2}" == "${activeWorkspaceID:0:2}" ]] && echo -e "\033[1;32m$desktop\033[0m" || echo -e "$desktop"
		desktopID="${desktop:0:2}"
		

		Get_saved_Workspaces_on_Desktop "$desktopID" workspacesOnDesktop
		for workspace in "${workspacesOnDesktop[@]}"; do
			workspaceID="$(basename "$workspace")"
			[[ "$workspaceID" == "$activeWorkspaceID" ]] && echo -e "   \033[1;32mcurrent workspace: $workspaceID\033[0m" || echo -e "   active workspaces: $workspaceID"
		done
		workspacesOnDesktop=()
	done



}









# initialize the script
function Initialize_script() {
	# set symlink if not exists
	[[ ! -L "/usr/local/bin/workspaces" ]] && sudo ln -s "$(realpath "$0")" /usr/local/bin/workspaces

	# delete and recreate tmp directories
	rm -rf "$DIR_TMP_AVAILABLE_DESKTOPS"
	rm -rf "$DIR_TMP_ACTIVE_WORKSPACES"
	mkdir -p "$DIR_TMP_AVAILABLE_DESKTOPS"
	mkdir -p "$DIR_TMP_ACTIVE_WORKSPACES"

	Create_new_Desktop "default"
	Switch_to_Desktop_by_number "11"
}









##############################
### DESKTOP USER FUNCTIONS ###
##############################


# Create a new Desktop 
function Create_new_Desktop() {
	local newDesktopName="$1"

	local availableDesktops=()
	Get_available_Desktops availableDesktops
	
	if [[ -z "$newDesktopName" ]]; then
		newDesktopName="unnamed"
	fi

	for i in {11..99}; do
		if ! grep -q "${i}" <<<"${availableDesktops[*]}"; then
			[[ $newDesktopName == "unnamed" ]] && newDesktopName="${newDesktopName}_$i"
			Save_Desktop "${i}_${newDesktopName}"
			Switch_to_WorkspaceID "${i}${MONITOR_LEFT_ID}1"
			Switch_to_WorkspaceID "${i}${MONITOR_RIGHT_ID}1"
			Switch_to_WorkspaceID "${i}${MONITOR_MAIN_ID}1"
			break
		fi
	done
	Cleanup_available_Desktops
}









function Create_Desktop_and_move_current_window() {
	local newDesktopName="$1"
	local monitorID="$2"
	local workspaceNumber="$3"

	# if new Desktop name is empty, set it to "unnamed"
	[[ -z "$newDesktopName" ]] && newDesktopName="unnamed"


	[[ -z "$monitorID" ]] && monitorID="left"
	[[ $monitorID == "left" ]] && monitorID="$MONITOR_LEFT_ID"
	[[ $monitorID == "right" ]] && monitorID="$MONITOR_RIGHT_ID"
	[[ $monitorID == "main" ]] && monitorID="$MONITOR_MAIN_ID"

	[[ -z "$workspaceNumber" ]] && workspaceNumber="1"

	# if new Desktop name exists in the available desktops, move Window to that Desktop instead
	local availableDesktop="$(ls $DIR_TMP_AVAILABLE_DESKTOPS/*_${newDesktopName} 2>/dev/null)"
	if [[ -n "$availableDesktop" ]]; then
		#Move_current_Window_to_Desktop_by_name "${availableDesktop##*/}" "$monitorID" "$workspaceNumber"
		return
	fi

	local availableDesktops=()
	Get_available_Desktops availableDesktops
	for i in {11..99}; do
		if ! grep -q "${i}" <<<"${availableDesktops[*]}"; then
			[[ $newDesktopName == "unnamed" ]] && newDesktopName="${newDesktopName}_$i"
			Save_Desktop "${i}_${newDesktopName}"
			Move_current_Window_to_Desktop_by_number "$i"
			Move_current_Window_to_Workspace "${i}${monitorID}1"
			Switch_to_WorkspaceID "${i}${MONITOR_LEFT_ID}1"
			Switch_to_WorkspaceID "${i}${MONITOR_RIGHT_ID}1"
			Switch_to_WorkspaceID "${i}${MONITOR_MAIN_ID}1"
			Switch_to_WorkspaceID "${i}${monitorID}1"
			break
		fi
	done
	Cleanup_available_Desktops
}










# Switch to Desktop by its name
function Switch_to_Desktop_by_name() {
	local desktopName=$1

	# check if the desktop exists, if not create it
	local availableDesktops=()
	Get_available_Desktops availableDesktops
	if ! grep -q "${desktopName:0:2}$" <<<"${availableDesktops[*]}"; then
		Save_Desktop "${desktopName}"
	fi

	currentWorkspaceID="$(Get_current_Workspace_ID)"
	# Switch to the saved workspace for each monitor, or default to 1
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "${desktopName:0:2}" "$MONITOR_MAIN_ID")"
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "${desktopName:0:2}" "$MONITOR_LEFT_ID")"
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "${desktopName:0:2}" "$MONITOR_RIGHT_ID")"

	sleep $SLEEP_TIME
	hyprctl dispatch focusmonitor ${currentWorkspaceID:2:1} > /dev/null 2>&1
	Cleanup_available_Desktops
}









# Switch to Desktop by its number
function Switch_to_Desktop_by_number() {
	local desktopNumber=$1

	# if number is not between 11 and 99, return
	if ! [[ "$desktopNumber" =~ ^[1-9][0-9]$ ]]; then
		echo "Invalid desktop number. Must be between 11 and 99."
		return 1
	fi
	# check if the desktop exists, if not create it
	local availableDesktops=()
	Get_available_Desktops availableDesktops
	if ! grep -q "${desktopNumber}$" <<<"${availableDesktops[*]}"; then
		Save_Desktop "${desktopNumber}_unnamed-$desktopNumber"
	fi
	currentWorkspaceID="$(Get_current_Workspace_ID)"

	# Switch to the saved workspace for each monitor, or default to 1
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "$desktopNumber" "$MONITOR_MAIN_ID")"
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "$desktopNumber" "$MONITOR_LEFT_ID")"
	Switch_to_WorkspaceID "$(Get_saved_active_workspace_for_monitor "$desktopNumber" "$MONITOR_RIGHT_ID")"
	sleep $SLEEP_TIME
	hyprctl dispatch focusmonitor ${currentWorkspaceID:2:1} > /dev/null 2>&1
	
	Cleanup_available_Desktops
}









# Move current Window to Desktop by its number
function Move_current_Window_to_Desktop_by_number() {
	local desktopNumber=$1

	# if number is not between 11 and 99, return
	if ! [[ "$desktopNumber" =~ ^[1-9][0-9]$ ]]; then
		echo "Invalid desktop number. Must be between 11 and 99."
		return 1
	fi


	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"

	# check if the desktop exists, if not create it
	local availableDesktops=()
	Get_available_Desktops availableDesktops
	if ! grep -q "${desktopNumber}$" <<<"${availableDesktops[*]}"; then
		Save_Desktop "${desktopNumber}_unnamed-$desktopNumber"
	fi

	Move_current_Window_to_Workspace "${desktopNumber}${currentMonitor}"
	Switch_to_Desktop_by_number "$desktopNumber"
	
	Cleanup_available_Desktops
}









# Move current Window to next Desktop
function Move_current_Window_to_next_Desktop() {

	# get all saved desktops
	local savedDesktops=()
	Get_saved_Desktops_ID savedDesktops

	# get current workspace info
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"

	# find the index of the current desktop in the saved desktops array
	for i in "${!savedDesktops[@]}"; do
		if [[ "${savedDesktops[$i]}" == "$currentDesktop" ]]; then
			# get the next index, wrap around if necessary (circular, goes back to the first element after the last)
			nextIndex=$(( (i + 1) % ${#savedDesktops[@]} ))
			nextDesktop="${savedDesktops[$nextIndex]}"
			break
		fi
	done
	Move_current_Window_to_Desktop_by_number "$nextDesktop"
}









# Move current Window to previous Desktop
function Move_current_Window_to_previous_Desktop() {

	# get all saved desktops
	local savedDesktops=()
	Get_saved_Desktops_ID savedDesktops

	# get current workspace info
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"

	# find the index of the current desktop in the saved desktops array
	for i in "${!savedDesktops[@]}"; do
		if [[ "${savedDesktops[$i]}" == "$currentDesktop" ]]; then
			# get the previous index, wrap around if necessary (circular, goes back to the last element if at the first)
			previousIndex=$(( (i - 1 + ${#savedDesktops[@]}) % ${#savedDesktops[@]} ))
			previousDesktop="${savedDesktops[$previousIndex]}"
			break
		fi
	done
	Move_current_Window_to_Desktop_by_number "$previousDesktop"
}









# Switch to next Desktop
function Switch_to_next_available_Desktop() {
	local savedDesktops=()
	Get_saved_Desktops_ID savedDesktops
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"

	for i in "${!savedDesktops[@]}"; do
		if [[ "${savedDesktops[$i]}" == "$currentDesktop" ]]; then
			# get the next index, wrap around if necessary (circular, goes back to the first element after the last)
			nextIndex=$(( (i + 1) % ${#savedDesktops[@]} ))
			nextDesktop="${savedDesktops[$nextIndex]}"
			break
		fi
	done

	Switch_to_Desktop_by_number "$nextDesktop"
	Cleanup_available_Desktops
}










# Switch to previous Desktop
function Switch_to_previous_available_Desktop() {
	local savedDesktops=()
	Get_saved_Desktops_ID savedDesktops
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"

	for i in "${!savedDesktops[@]}"; do
		if [[ "${savedDesktops[$i]}" == "$currentDesktop" ]]; then
			# get the previous index, wrap around if necessary (circular, goes back to the last element if at the first)
			previousIndex=$(( (i - 1 + ${#savedDesktops[@]}) % ${#savedDesktops[@]} ))
			previousDesktop="${savedDesktops[$previousIndex]}"
			break
		fi
	done

	Switch_to_Desktop_by_number "$previousDesktop"
	Cleanup_available_Desktops
}

















################################
### WORKSPACE USER FUNCTIONS ###
################################

#Switch to Workspace by its number
function Switch_to_Workspace_on_current_Desktop_and_Monitor_by_number() {
	local workspaceNumber=$1
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local newWorkspaceID="${currentDesktop}${currentMonitor}${workspaceNumber}"

	# if workspaceNumber is not between 1 and 3, return
	if ! [[ "$workspaceNumber" =~ ^[1-3]$ ]]; then
		echo "Invalid workspace number. Must be between 1 and 3."
		return 1
	fi

	Switch_to_WorkspaceID "$newWorkspaceID"
}









# Switch to next workspace on the current desktop
function Switch_to_next_Workspace() {
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"
	local nextWorkspaceNumber=$(( (currentWorkspaceNumber % 3) + 1 ))
	local nextWorkspaceID="${currentDesktop}${currentMonitor}${nextWorkspaceNumber}"

	Switch_to_WorkspaceID "$nextWorkspaceID"
}








# Switch to previous workspace on the current desktop
function Switch_to_previous_Workspace() {
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"
	local previousWorkspaceNumber=$(( (currentWorkspaceNumber - 2 + 3) % 3 + 1 ))
	local previousWorkspaceID="${currentDesktop}${currentMonitor}${previousWorkspaceNumber}"

	Switch_to_WorkspaceID "$previousWorkspaceID"
}









# Move current Window to Desktop by its name, optional monitor and workspace number
function Move_current_Window_to_Desktop_by_name() {
	local desktopName="$1"
	local monitorID="$2"
	local workspaceNumber="$3"


	local availableDesktop="$(ls $DIR_TMP_AVAILABLE_DESKTOPS/*_${desktopName} 2>/dev/null)"

	if [[ -z "$availableDesktop" ]]; then
		echo "Desktop '$desktopName' does not exist."
		return 1
	fi
	local desktopID="$(basename "$availableDesktop" | cut -c1-2)"

	[[ -z "$monitorID" ]] && monitorID="left"
	[[ $monitorID == "left" ]] && monitorID="$MONITOR_LEFT_ID"
	[[ $monitorID == "right" ]] && monitorID="$MONITOR_RIGHT_ID"
	[[ $monitorID == "main" ]] && monitorID="$MONITOR_MAIN_ID"


	[[ -z "$workspaceNumber" ]] && workspaceNumber="1"

	Move_current_Window_to_Workspace "${desktopID}${monitorID}${workspaceNumber}"
}









# Move current Window to Workspace by number on current Desktop and current Monitor
function Move_current_Window_to_Workspace() {
	local workspaceNumber=$1
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local newWorkspaceID="${currentDesktop}${currentMonitor}${workspaceNumber}"

	# if workspaceNumber is not between 1 and 3, return
	if ! [[ "$workspaceNumber" =~ ^[1-3]$ ]]; then
		echo "Invalid workspace number. Must be between 1 and 3."
		return 1
	fi

	Move_current_Window_to_Workspace "$newWorkspaceID"
}









# Move current Window to Monitor by its name, optional workspace number
function Move_current_Window_to_Monitor_by_name() {
	local monitorID="$1"
	local workspaceNumber="$2"
	[[ -z "$monitorID" ]] && monitorID="left"
	[[ $monitorID == "left" ]] && monitorID="$MONITOR_LEFT_ID"
	[[ $monitorID == "right" ]] && monitorID="$MONITOR_RIGHT_ID"
	[[ $monitorID == "main" ]] && monitorID="$MONITOR_MAIN_ID"

	[[ -z "$workspaceNumber" ]] && workspaceNumber="1"

	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"


	Move_current_Window_to_Workspace "${currentDesktop}${monitorID}${workspaceNumber}"
}










# Move current Window to next workspace on the current desktop and current monitor
function Move_current_Window_to_next_Workspace() {
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"
	local nextWorkspaceNumber=$(( (currentWorkspaceNumber % 3) + 1 ))
	local nextWorkspaceID="${currentDesktop}${currentMonitor}${nextWorkspaceNumber}"
	Move_current_Window_to_Workspace "$nextWorkspaceID"
}









# Move current Window to previous workspace on the current desktop and current monitor
function Move_current_Window_to_previous_Workspace() {
	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"
	local currentMonitor="${currentWorkspaceID:2:1}"
	local currentWorkspaceNumber="${currentWorkspaceID:3:1}"
	local previousWorkspaceNumber=$(( (currentWorkspaceNumber - 2 + 3) % 3 + 1 ))
	local previousWorkspaceID="${currentDesktop}${currentMonitor}${previousWorkspaceNumber}"
	Move_current_Window_to_Workspace "$previousWorkspaceID"
}









function Switch_to_Monitor_on_Current_Desktop_by_name() {
	local monitorName="$1"
	local workspaceNumber="$2"

	[[ -z "$monitorName" ]] && monitorName="left"
	[[ $monitorName == "left" ]] && monitorID="$MONITOR_LEFT_ID"
	[[ $monitorName == "right" ]] && monitorID="$MONITOR_RIGHT_ID"
	[[ $monitorName == "main" ]] && monitorID="$MONITOR_MAIN_ID"

	[[ -z "$workspaceNumber" ]] && workspaceNumber="1"

	local currentWorkspaceID="$(Get_current_Workspace_ID)"
	local currentDesktop="${currentWorkspaceID:0:2}"

	Switch_to_WorkspaceID "${currentDesktop}${monitorID}${workspaceNumber}"
}
















#########################
### SUPPORT FUNCTIONS ###
#########################



# get all active workspaces on a specific desktop
function Get_saved_Workspaces_on_Desktop() {
	local desktopNumber=$1
	local -n savedWorkspaces_ref=$2
	mapfile -t savedWorkspaces_ref < <(ls -t "$DIR_TMP_ACTIVE_WORKSPACES/${desktopNumber}"*)
}









# get all available desktops, only the first two numers
function Get_available_Desktops() {
	local -n availableDeskops_ref=$1

	# get all available desktops, only the first two numers
	#hyprctl workspaces -j | jq -r '.[].name' | cut -c1-2 | sort -V | uniq 
	mapfile -t availableDeskops_ref < <(hyprctl -j workspaces | jq -r '.[].name' | cut -c1-2 | sort -V | uniq)
}








# get all saved desktops id (first two chars) from the tmp directory
function Get_saved_Desktops_ID() {
	local -n savedDesktops_ref=$1

	mapfile -t savedDesktops_ref < <(ls -tr "$DIR_TMP_AVAILABLE_DESKTOPS" | xargs -n 1 basename | cut -c1-2)
}









# Get Desktop name by its number
function Get_Desktop_name_by_number() {
	local desktopNumber=$1
	if [[ -f "$DIR_TMP_AVAILABLE_DESKTOPS/${desktopNumber}" ]]; then
		echo "$(cat "$DIR_TMP_AVAILABLE_DESKTOPS/${desktopNumber}" | cut -d'_' -f2-)"
	else
		return 1
	fi
}









#Save desktop to a file
function Save_Desktop() {
	local newDesktopName=$1 # numberPart + name part

	local numberPart="${newDesktopName:0:2}"
	# if file already exists, return
	[[ $(ls $DIR_TMP_AVAILABLE_DESKTOPS/${numberPart}* 2> /dev/null) ]] && return 1
	touch "$DIR_TMP_AVAILABLE_DESKTOPS/${newDesktopName}"
}









function Switch_to_WorkspaceID() {
	local workspaceID=$1
	local foundSavedWorkspace
	# if workspaceID is only three characters or numbers long, check if it saved in the tmp directory
	# (it doesn't care if it's a three or four character long workspaceID, it just checks if there's a saved workspace with that name)
	# if only three characters or numbers long, it adds a 1 at the end
	if ! [[ "$workspaceID" =~ ^[0-9]{4}$ ]]; then
		# if file doesn't exist, return
		if ls "$DIR_TMP_ACTIVE_WORKSPACES/${workspaceID}*" &> /dev/null; then

			workspaceID="$(ls "$DIR_TMP_ACTIVE_WORKSPACES/${workspaceID}*")"
			workspaceID="$(basename "$workspaceID")"
		else
			workspaceID="${workspaceID}1"
		fi
	fi

	sleep $SLEEP_TIME
	hyprctl dispatch focusmonitor "${workspaceID:2:1}" > /dev/null 2>&1 
	sleep $SLEEP_TIME
	hyprctl dispatch workspace "$workspaceID" > /dev/null 2>&1 

	Save_active_Workspace "$workspaceID"
}









function Move_current_Window_to_Workspace() {
	local workspaceID_input=$1
	local workspaceID_final="$workspaceID_input"

	local foundSavedWorkspace="$(ls "$DIR_TMP_ACTIVE_WORKSPACES/${workspaceID_input}*" 2>/dev/null)"
	foundSavedWorkspace="$(basename "$foundSavedWorkspace")"

	if [[ -n "$foundSavedWorkspace" ]]; then
		workspaceID_final="$foundSavedWorkspace"
	elif [[ "${#workspaceID_input}" -eq 3 ]]; then # Only append '1' if it's a 3-digit ID and no saved workspace was found
		workspaceID_final="${workspaceID_input}1"
	fi
	# If it's a 4-digit ID and no saved workspace was found, workspaceID_final remains workspaceID_input (4 digits), which is correct.

	sleep $SLEEP_TIME
	hyprctl dispatch movetoworkspace "$workspaceID_final" > /dev/null 2>&1

	Save_active_Workspace "$workspaceID_final"
}









# Save the current active workspace to a file
function Save_active_Workspace() {
	local toSaveWorkspaceName=$1

	rm -f $DIR_TMP_ACTIVE_WORKSPACES/${toSaveWorkspaceName:0:3}*
	touch $DIR_TMP_ACTIVE_WORKSPACES/${toSaveWorkspaceName}
}









# Get the saved active workspace for a specific desktop and monitor
function Get_saved_active_workspace_for_monitor() {
	local desktopNumber=$1
	local monitorID=$2
	local prefix="${desktopNumber}${monitorID}"
	local savedWorkspaceFile="$(ls "$DIR_TMP_ACTIVE_WORKSPACES/${prefix}*" 2>/dev/null)"

	if [[ -n "$savedWorkspaceFile" ]]; then
		basename "$savedWorkspaceFile"
	else
		echo "${prefix}1" # Default to workspace 1 if no saved workspace found
	fi
}









# clean up non existing desktops
function Cleanup_available_Desktops() {
	# get all available desktops
	local desktopName
	local savedDesktop=()
	Get_available_Desktops savedDesktop
	local file filename prefix desktop found
	found=false
	# loop through all files in the available desktops directory
	for file in "$DIR_TMP_AVAILABLE_DESKTOPS"/*; do
		filename="$(basename "$file")"
		prefix="${filename:0:2}"
		for desktop in "${savedDesktop[@]}"; do
			if [[ "$desktop" == "$prefix" ]]; then
				found=true
				break
			fi
		done 
		if ! $found; then
			rm -f "$file"
		else
			found=false
		fi
			
	done
	Cleanup_active_Workspaces
}









#clean up non existing workspaces
function Cleanup_active_Workspaces() {
	# get all active workspaces

	local workspaceName
	for file in "$DIR_TMP_ACTIVE_WORKSPACES"/*; do
		if ! hyprctl -j workspaces | jq -r '.[].name' | grep -q "$(basename "$file")"; then
			rm -f "$file"
		fi
	done

	# Ensure that for every active desktop and every monitor, a default workspace (DDM1) is saved
	local activeDesktops=()
	Get_available_Desktops activeDesktops

	local monitors=("$MONITOR_MAIN_ID" "$MONITOR_LEFT_ID" "$MONITOR_RIGHT_ID")

	for desktop in "${activeDesktops[@]}"; do
		for monitor in "${monitors[@]}"; do
			local prefix="${desktop}${monitor}"
			if ! ls "$DIR_TMP_ACTIVE_WORKSPACES/${prefix}*" &> /dev/null; then
				touch "$DIR_TMP_ACTIVE_WORKSPACES/${prefix}1"
			fi
		done
	done
}









function Get_current_Workspace_ID() {
	echo $(hyprctl -j activeworkspace | jq -r '.name')
}








mycall="$1"
shift

# 



case $mycall in
	"--desktop-nr")
		Switch_to_Desktop_by_number "$@"
		;;
	"--ws-nr")
		Switch_to_WorkspaceID "$@"
		;;
	"--monitor")
		Switch_to_Monitor_on_Current_Desktop_by_name "$@"
		;;
	"--next-ws")
		Switch_to_next_Workspace
		;;
	"--previous-ws")
		Switch_to_previous_Workspace
		;;
	"--next-desktop")
		Switch_to_next_available_Desktop
		;;
	"--previous-desktop")
		Switch_to_previous_available_Desktop
		;;
	"--new-desktop")
		Create_new_Desktop "$@"
		;;
	"--mvx-new-desktop")
		Create_Desktop_and_move_current_window "$@"
		;;
	"--mvx-desktop-name")
		Move_current_Window_to_Desktop_by_name "$@"
		;;
	"--mvx-desktop-nr")
		Move_current_Window_to_Desktop_by_number "$@"
		;;
	"--mvx-next-desktop")
		Move_current_Window_to_next_Desktop
		;;
	"--mvx-previous-desktop")
		Move_current_Window_to_previous_Desktop
		;;
	"--mvx-monitor")
		Move_current_Window_to_Monitor_by_name "$@"
		;;
	"--mvx-ws-nr")
		Move_current_Window_to_Workspace "$@"
		;;
	"--mvx-next-ws")
		Move_current_Window_to_next_Workspace
		;;
	"--mvx-previous-ws")
		Move_current_Window_to_previous_Workspace
		;;
	"--show-all")
		Show_all_Desktops_and_Workspaces
		;;
	"--cleanup")
		Cleanup_available_Desktops
		;;
	"--init")
		Initialize_script
		;;
	*)
		echo "Usage: $0 {switch-to-desktop <number>|switch-to-workspace <number>|next-workspace|previous-workspace|next-desktop|previous-desktop|new-desktop <name>|move-window-to-workspace <number>|move-window-to-next-workspace|move-window-to-previous-workspace|move-window-to-desktop <number>|move-window-to-next-desktop|move-window-to-previous-desktop|show-all|init}"
		exit 1
		;;
esac
# >>>> END SCRIPT <<<< #
	



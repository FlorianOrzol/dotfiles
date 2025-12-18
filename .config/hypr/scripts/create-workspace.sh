#!/bin/bash
#
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
WORKSPACES=("ws_default")

function create_workspace() {
	local workspace_name=$1

	hyprctl dispatch workspace "$workspace_name"
	hyprctl dispatch movetoworkspace "$workspace_name"
	hyprctl dispatch workspace "$workspace_name"
}

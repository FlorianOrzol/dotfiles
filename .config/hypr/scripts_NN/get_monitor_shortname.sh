#!/bin/bash

MONITOR_NAME=$1

case "$MONITOR_NAME" in
    "HDMI-A-4") echo "left" ;;
    "DP-2") echo "main" ;;
    "DP-3") echo "right" ;;
    "HDMI-A-5") echo "info" ;;
    *) echo "unknown" ;;
esac
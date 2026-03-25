#!/bin/bash
function arguments() {
    arg_value @node --description "Target Proxmox Node (pve101, pve102, pve103)" --option "pve101" --option "pve102" --option "pve103"
}

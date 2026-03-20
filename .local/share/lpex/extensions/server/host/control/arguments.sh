function arguments() {
    arg_value @node \
        --fzf \
        --description "Select Proxmox Node" \
        --option "pve101 # 10.0.101.1 (Main)" \
        --option "pve102 # 10.0.102.1 (Standby)" \
        --option "pve103 # 10.0.103.1 (Standby)"
        
    arg_flag @start --description "Wake up via Shelly"
    arg_flag @stop --description "Soft Shutdown via SSH"
}

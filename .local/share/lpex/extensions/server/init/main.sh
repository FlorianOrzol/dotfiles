#!/bin/bash
# ==============================================================================
# @meta_module      : server init
# @meta_file        : main.sh
# @meta_date        : 2026-04-13
#
# @desc_short       : Full initial bootstrap (or re-initialization) of homelab nodes.
# @desc_detailed    : Supports Observer nodes (pi1, pi2) and Proxmox hosts (pve101-103).
# @desc_detailed    : Steps are idempotent wherever possible — already-correct states
# @desc_detailed    : are detected and skipped to avoid unnecessary side effects.
# @desc_detailed    : Use --force to bypass idempotency checks after hardware replacement.
#
# @arg_values       : --node  | Target node(s), repeatable (pi1, pi2, pve101, pve102, pve103)
# @arg_flags        : --force | Skip SSH-key and flag checks; always re-run all steps
#
# @exit_codes       : 0 | All requested nodes initialized successfully
# @exit_codes       : 1 | Missing config, unknown node, or critical step failed
#
# @notes            : Requires ~/.private/priv_data (homelab.conf source).
# @notes            : SSH passwords are prompted once by ssh-copy-id if key is missing.
# ==============================================================================

# ------------------------------------------------------------------------------
# Private config path — never copied into the LPEX state directory.
# This file is pushed directly via --source-path to avoid leaking credentials.
# ------------------------------------------------------------------------------
readonly _INIT_PRIV_CONF="$HOME/.privates/priv_data"

# ==============================================================================
# _check_ssh_key <user> <ip>
#   Returns 0 if passwordless SSH login works, 1 if password is still required.
#   BatchMode=yes prevents any interactive password prompt from blocking the script.
# ==============================================================================
function _check_ssh_key() {
    local user="$1"
    local ip="$2"
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "$user@$ip" exit 2>/dev/null
}

# ==============================================================================
# _push_homlab_conf <user> <ip> <remote_dest>
#   Copies the private homelab.conf directly to a remote path via rsync + mv.
#   Uses the same two-step approach as the push module: rsync to /tmp first,
#   then move to the final destination (with sudo if under /etc).
# ==============================================================================
function _push_homelab_conf() {
    local user="$1"
    local ip="$2"
    local remote_dest="$3"
    local remote_tmp="/tmp/lpex_init_homelab.conf"

    output --info "-> Transferring homelab.conf to /tmp..."
    if ! lx cmd --run "rsync -az '$_INIT_PRIV_CONF' '$user@$ip:$remote_tmp'" \
            --quiet --error-msg "rsync of homelab.conf failed"; then
        return 1
    fi

    # [LOGIC] /etc requires root — use sudo mv. The fadmin home dir does not.
    local mv_cmd
    if [[ "$remote_dest" == /etc/* ]]; then
        mv_cmd="sudo mkdir -p '$(dirname "$remote_dest")' && sudo mv '$remote_tmp' '$remote_dest'"
        lx cmd --run "ssh -t '$user@$ip' '$mv_cmd'" --quiet --error-msg "Move to $remote_dest failed"
    else
        mv_cmd="mkdir -p '$(dirname "$remote_dest")' && mv '$remote_tmp' '$remote_dest'"
        lx cmd --run "ssh '$user@$ip' '$mv_cmd'" --quiet --error-msg "Move to $remote_dest failed"
    fi
}

# ==============================================================================
# _init_observer <node> <force>
#   Full initialization sequence for an Observer node (pi1 or pi2).
#   Steps:
#     1. SSH key   — skip if already working (unless --force)
#     2. homelab.conf → /home/fadmin/scripts/homelab.conf
#     3. Full tree-mirror push (scripts + systemd units)
#     4. State directories (mkdir -p, idempotent)
#     5. observer_leader flag — only set on pi1, only if not yet present
#     6. systemd daemon-reload
#     7. Enable + start all observer timer units
#     8. Enable obs-startup-check.service for boot
# ==============================================================================
function _init_observer() {
    local node="$1"
    local force="$2"

    local ip
    ip=$(get_observer_ip "$node")

    # ------------------------------------------------------------------
    # Step 1: SSH key
    # ------------------------------------------------------------------
    output --info "[1/7] SSH key check..."
    if (( force )) || ! _check_ssh_key "$USER_OBSERVER" "$ip"; then
        output --info "-> Running ssh-copy-id for $node (password required once)..."
        # [LOGIC] ssh-copy-id is idempotent — it checks for duplicates before
        # appending. Running it again after hardware replacement is always safe.
        ssh-copy-id "$USER_OBSERVER@$ip"
    else
        output --ok "SSH key already present on $node — skipped."
    fi

    # ------------------------------------------------------------------
    # Step 2: homelab.conf
    # ------------------------------------------------------------------
    output --info "[2/7] Deploying homelab.conf..."
    _push_homelab_conf "$USER_OBSERVER" "$ip" "/home/fadmin/scripts/homelab.conf" || return 1
    output --ok "homelab.conf deployed."

    # ------------------------------------------------------------------
    # Step 3: Full tree-mirror push (scripts + systemd units)
    # ------------------------------------------------------------------
    # [LOGIC] We push specific directories rather than "." to avoid the
    # interactive confirmation prompt that the "." shorthand triggers.
    # The two directories cover everything: user scripts and systemd units.
    output --info "[3/7] Deploying scripts and systemd units..."
    lx cmd --run "lpex server observer push --node '$node' --local-file 'home/fadmin/scripts'" \
        --error-msg "Failed to deploy scripts to $node"
    lx cmd --run "lpex server observer push --node '$node' --local-file 'etc/systemd/system'" \
        --error-msg "Failed to deploy systemd units to $node"

    # ------------------------------------------------------------------
    # Step 4: Runtime state directories
    # ------------------------------------------------------------------
    # [LOGIC] These directories are created at runtime by the observer scripts
    # but may not exist on a fresh Pi. mkdir -p is always safe to re-run.
    output --info "[4/7] Creating state directories..."
    lx cmd --run "ssh '$USER_OBSERVER@$ip' \
        'mkdir -p ~/db/flags ~/db/logs ~/db/network_status/pve101/status ~/db/network_status/pve102/status'" \
        --quiet --error-msg "Failed to create state directories on $node"

    # ------------------------------------------------------------------
    # Step 5: Initial flag files (only set if not already present)
    # ------------------------------------------------------------------
    # [LOGIC] These flags drive runtime decisions — we must not overwrite them
    # if the system is already running, as pi2 might legitimately be the leader.
    # With --force all flags are reset unconditionally (e.g. after hardware swap).
    output --info "[5/7] Initializing state flags..."
    if [[ "$node" == "pi1" ]]; then
        # observer_leader: pi1 is the default primary — set only if not yet present
        if (( force )); then
            lx cmd --run "ssh '$USER_OBSERVER@$ip' 'echo pi1 > ~/db/flags/observer_leader'" \
                --quiet --error-msg "Failed to set observer_leader"
            output --ok "observer_leader = pi1 (--force)."
        else
            lx cmd --run "ssh '$USER_OBSERVER@$ip' \
                '[ -f ~/db/flags/observer_leader ] || echo pi1 > ~/db/flags/observer_leader'" \
                --quiet --error-msg "Failed to initialize observer_leader"
            output --ok "observer_leader: already set or initialized to pi1."
        fi

        # allow_zfs_sync: must be 1 on first boot so the backup job can run
        # [LOGIC] Only set if not already present — after a failover the flag may
        # have been cleared intentionally and must be re-enabled manually.
        if (( force )); then
            lx cmd --run "ssh '$USER_OBSERVER@$ip' 'echo 1 > ~/db/flags/allow_zfs_sync'" \
                --quiet --error-msg "Failed to set allow_zfs_sync"
            output --ok "allow_zfs_sync = 1 (--force)."
        else
            lx cmd --run "ssh '$USER_OBSERVER@$ip' \
                '[ -f ~/db/flags/allow_zfs_sync ] || echo 1 > ~/db/flags/allow_zfs_sync'" \
                --quiet --error-msg "Failed to initialize allow_zfs_sync"
            output --ok "allow_zfs_sync: already set or initialized to 1."
        fi

        # host_leader: the active PVE host — defaults to pve101
        if (( force )); then
            lx cmd --run "ssh '$USER_OBSERVER@$ip' 'echo pve101 > ~/db/host_leader'" \
                --quiet --error-msg "Failed to set host_leader"
            output --ok "host_leader = pve101 (--force)."
        else
            lx cmd --run "ssh '$USER_OBSERVER@$ip' \
                '[ -f ~/db/host_leader ] || echo pve101 > ~/db/host_leader'" \
                --quiet --error-msg "Failed to initialize host_leader"
            output --ok "host_leader: already set or initialized to pve101."
        fi
    else
        # pi2: observer_leader points to pi1 (pi2 is standby), peer_check_fail_count starts at 0
        lx cmd --run "ssh '$USER_OBSERVER@$ip' \
            '[ -f ~/db/flags/observer_leader ] || echo pi1 > ~/db/flags/observer_leader'" \
            --quiet --error-msg "Failed to initialize observer_leader on pi2"
        lx cmd --run "ssh '$USER_OBSERVER@$ip' \
            '[ -f ~/db/flags/peer_check_fail_count ] || echo 0 > ~/db/flags/peer_check_fail_count'" \
            --quiet --error-msg "Failed to initialize peer_check_fail_count"
        output --ok "Standby flags initialized (observer_leader=pi1, peer_check_fail_count=0)."
    fi

    # ------------------------------------------------------------------
    # Step 6: systemd daemon-reload
    # ------------------------------------------------------------------
    output --info "[6/7] Reloading systemd daemon..."
    lx cmd --run "ssh -t '$USER_OBSERVER@$ip' 'sudo systemctl daemon-reload'" \
        --quiet --error-msg "daemon-reload failed on $node"

    # ------------------------------------------------------------------
    # Step 7: Enable systemd units — different sets for pi1 vs pi2
    # ------------------------------------------------------------------
    # [LOGIC] The timer layout is asymmetric by design:
    #   pi1 (Primary) : runs all job timers + heartbeat + watchdog
    #   pi2 (Standby) : runs ONLY the peer-check timer; all others are
    #                   activated/deactivated dynamically by obs-promote.sh
    #                   and step_down(). Enabling them here would break HA.
    # obs-startup-check.service is a oneshot boot unit — enabled on both.
    output --info "[7/7] Enabling systemd units..."
    if [[ "$node" == "pi1" ]]; then
        local pi1_timers="obs-heartbeat.timer obs-watchdog.timer job-check-standby.timer job-backup-nightly.timer"
        lx cmd --run "ssh -t '$USER_OBSERVER@$ip' 'sudo systemctl enable --now $pi1_timers'" \
            --quiet --error-msg "Failed to enable pi1 timer units"
    else
        # pi2 only needs the peer-check timer permanently enabled
        lx cmd --run "ssh -t '$USER_OBSERVER@$ip' 'sudo systemctl enable --now obs-peer-check.timer'" \
            --quiet --error-msg "Failed to enable obs-peer-check.timer on pi2"
    fi
    lx cmd --run "ssh -t '$USER_OBSERVER@$ip' 'sudo systemctl enable obs-startup-check.service'" \
        --quiet --error-msg "Failed to enable obs-startup-check.service on $node"

    output --ok "Observer $node initialized successfully."
}

# ==============================================================================
# _init_host <node> <force>
#   Full initialization sequence for a Proxmox host node (pve101, pve102, pve103).
#   Steps:
#     1. SSH key   — skip if already working (unless --force)
#     2. homelab.conf → /etc/homelab.conf
#     3. Deploy mount-nfs.sh and homelab-nfs-mounts.service
#     4. daemon-reload
#     5. Enable + start homelab-nfs-mounts.service (skip if already active)
# ==============================================================================
function _init_host() {
    local node="$1"
    local force="$2"

    # Resolve IP from config variable (e.g. IP_PVE101)
    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"

    if [[ -z "$ip" ]]; then
        output --error "IP not found for $node (${ip_var} not set in config.conf)."
        return 1
    fi

    # ------------------------------------------------------------------
    # Step 1: SSH key
    # ------------------------------------------------------------------
    output --info "[1/5] SSH key check..."
    if (( force )) || ! _check_ssh_key "$USER_PVE" "$ip"; then
        output --info "-> Running ssh-copy-id for $node (password required once)..."
        ssh-copy-id "$USER_PVE@$ip"
    else
        output --ok "SSH key already present on $node — skipped."
    fi

    # ------------------------------------------------------------------
    # Step 2: homelab.conf → /etc/homelab.conf
    # ------------------------------------------------------------------
    output --info "[2/5] Deploying homelab.conf..."
    _push_homelab_conf "$USER_PVE" "$ip" "/etc/homelab.conf" || return 1
    output --ok "homelab.conf deployed."

    # ------------------------------------------------------------------
    # Step 3: NFS mount script and service unit
    # ------------------------------------------------------------------
    output --info "[3/5] Deploying NFS mount files..."
    lx cmd --run "lpex server host push --node '$node' --local-file 'root/scripts/mount-nfs.sh'" \
        --error-msg "Failed to deploy mount-nfs.sh to $node"
    lx cmd --run "lpex server host push --node '$node' --local-file 'etc/systemd/system/homelab-nfs-mounts.service'" \
        --error-msg "Failed to deploy homelab-nfs-mounts.service to $node"

    # ------------------------------------------------------------------
    # Step 4: systemd daemon-reload
    # ------------------------------------------------------------------
    output --info "[4/5] Reloading systemd daemon..."
    # [LOGIC] USER_PVE is root on Proxmox — no sudo needed.
    lx cmd --run "ssh '$USER_PVE@$ip' 'systemctl daemon-reload'" \
        --quiet --error-msg "daemon-reload failed on $node"

    # ------------------------------------------------------------------
    # Step 5: Enable NFS mount service (skip if already active)
    # ------------------------------------------------------------------
    output --info "[5/5] Enabling homelab-nfs-mounts.service..."
    if (( force )) || ! ssh "$USER_PVE@$ip" "systemctl is-active homelab-nfs-mounts.service" &>/dev/null; then
        lx cmd --run "ssh '$USER_PVE@$ip' 'systemctl enable --now homelab-nfs-mounts.service'" \
            --quiet --error-msg "Failed to enable homelab-nfs-mounts.service on $node"
        output --ok "NFS mount service enabled and started."
    else
        output --ok "homelab-nfs-mounts.service already active — skipped."
    fi

    output --ok "Host $node initialized successfully."
}

# ==============================================================================
# extension_start — main entry point
# ==============================================================================
function extension_start() {
    enforce_config_var "USER_OBSERVER"
    enforce_config_var "USER_PVE"

    # Verify private config exists before attempting anything
    if [[ ! -f "$_INIT_PRIV_CONF" ]]; then
        output --error "Private config not found: $_INIT_PRIV_CONF"
        output --warn  "Create it with the required variables (IP_SHAREDATA, PATH_POOL_FAST, etc.) first."
        return 1
    fi

    local target_nodes=("${ARG_NODE[@]}")
    local force=$(( ARG_FORCE ))

    if [[ ${#target_nodes[@]} -eq 0 ]]; then
        output --error "No nodes specified. Use --node pi1|pi2|pve101|pve102|pve103"
        return 1
    fi

    # Dispatch each node to the appropriate initialization function
    for node in "${target_nodes[@]}"; do
        output --section "Initializing: $node"

        case "$node" in
            pi1|pi2)
                _init_observer "$node" "$force"
                ;;
            pve101|pve102|pve103)
                _init_host "$node" "$force"
                ;;
            *)
                output --error "Unknown node: '$node'. Supported: pi1, pi2, pve101, pve102, pve103."
                ;;
        esac
    done
}

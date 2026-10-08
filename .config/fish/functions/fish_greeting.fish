function fish_greeting
    # Limit to 1s — NFS soft-timeouts can block for minutes if the server is unreachable at boot
    timeout 1 lpex homelab state short
    or echo " homelab state: NFS not yet available"
end

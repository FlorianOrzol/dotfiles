#!/bin/bash
export VAULT_PASS="test"
RBW_PROFILE=test_lpex expect <<EOF
log_user 1
spawn rbw login
expect "Master Password:"
send "\$env(VAULT_PASS)\r"
expect eof
EOF

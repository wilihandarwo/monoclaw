#!/bin/bash
# MonoClaw Installer - fail2ban Configuration
# Configures fail2ban jail for SSH protection

log_step "Configuring fail2ban for SSH protection..."

# Enable SSH brute-force protection with custom port
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled  = true
port     = ${MONOCLAW_SSH_PORT}
logpath  = /var/log/auth.log
maxretry = 5
findtime = 600
bantime  = 3600
EOF

# Ensure fail2ban service is running
log_step "Starting fail2ban service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now fail2ban || true
    systemctl restart fail2ban || true
fi

log_info "fail2ban configured for SSH on port ${MONOCLAW_SSH_PORT}"

#!/bin/bash
# MonoClaw Installer - Final Directory Setup
# Ensures all directories have correct permissions

log_step "Verifying directory permissions..."

# Ensure vps-scripts directory exists with correct ownership
mkdir -p /usr/local/vps-scripts
chmod 755 /usr/local/vps-scripts

# Ensure MonoClaw config directory has correct permissions
chmod 700 /etc/monoclaw

# Ensure OpenClaw service user home has correct permissions
if [ -d /var/lib/openclaw ]; then
    chown -R ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} /var/lib/openclaw
    chmod 700 /var/lib/openclaw

    if [ -d /var/lib/openclaw/.openclaw ]; then
        chmod 700 /var/lib/openclaw/.openclaw
        [ -f /var/lib/openclaw/.openclaw/openclaw.json ] && chmod 600 /var/lib/openclaw/.openclaw/openclaw.json
    fi
fi

log_info "Directory permissions verified"

#!/bin/bash
# MonoClaw Installer - Systemd Service Configuration
# Creates and enables OpenClaw systemd service

log_step "Creating OpenClaw systemd service..."

# Get the path to the openclaw binary
OPENCLAW_PATH="$(command -v openclaw || echo /usr/bin/openclaw)"

# Create systemd service unit file with security hardening
# Note: Using "openclaw gateway" not "openclaw daemon" (which is a legacy alias)
cat > /etc/systemd/system/openclaw.service <<EOF
[Unit]
Description=OpenClaw AI Assistant Gateway
Documentation=https://docs.openclaw.ai/
After=network.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=${MONOCLAW_SERVICE_USER}
Group=${MONOCLAW_SERVICE_USER}
WorkingDirectory=/var/lib/openclaw
Environment=HOME=/var/lib/openclaw
Environment=NODE_ENV=production
ExecStart=${OPENCLAW_PATH} gateway --port 18789
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ReadWritePaths=/var/lib/openclaw
ReadWritePaths=/tmp/openclaw

# Resource limits
MemoryMax=2G
TasksMax=100

[Install]
WantedBy=multi-user.target
EOF

log_step "Enabling and starting OpenClaw service..."

# Reload systemd daemon
systemctl daemon-reload

# Enable service to start on boot
systemctl enable openclaw

# Stop if running, then start fresh
systemctl stop openclaw 2>/dev/null || true
systemctl start openclaw

# Wait a moment for service to start
sleep 3

# Check service status
log_step "Checking OpenClaw service status..."
systemctl status openclaw --no-pager || {
    log_warning "OpenClaw service may not have started correctly."
    log_info "Check logs with: journalctl -u openclaw -n 50"
}

log_info "OpenClaw systemd service configured"

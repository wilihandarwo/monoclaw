#!/bin/bash
# MonoClaw Installer - Systemd Service Configuration
# Creates and enables OpenClaw systemd service

log_step "Creating OpenClaw systemd service..."

# Ensure temp directory exists for OpenClaw
mkdir -p /tmp/openclaw
chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} /tmp/openclaw
chmod 700 /tmp/openclaw

# Get the path to the openclaw binary
OPENCLAW_PATH="$(command -v openclaw || echo /usr/bin/openclaw)"

# Test if systemd namespace features are supported
# Some VPS types (OpenVZ, LXC) don't support these
log_step "Checking systemd security feature support..."
SYSTEMD_SECURITY_SUPPORTED=true

# Create a test service to check namespace support
cat > /tmp/test-namespace.service <<EOF
[Service]
Type=oneshot
ExecStart=/bin/true
ProtectSystem=strict
EOF

if ! systemd-analyze verify /tmp/test-namespace.service 2>/dev/null; then
    SYSTEMD_SECURITY_SUPPORTED=false
    log_warning "Systemd namespace features not supported on this VPS"
    log_info "Using basic service configuration (still secure via loopback binding)"
fi
rm -f /tmp/test-namespace.service

# Create systemd service unit file
# Note: Using "openclaw gateway" not "openclaw daemon" (which is a legacy alias)
if [ "$SYSTEMD_SECURITY_SUPPORTED" = "true" ]; then
    log_info "Creating service with security hardening..."
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
else
    log_info "Creating basic service configuration..."
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

[Install]
WantedBy=multi-user.target
EOF
fi

log_step "Enabling and starting OpenClaw service..."

# Reload systemd daemon
systemctl daemon-reload

# Enable service to start on boot
systemctl enable openclaw

# Stop if running, then start fresh
systemctl stop openclaw 2>/dev/null || true
systemctl start openclaw

# Wait for service to start and verify it's actually listening
log_step "Waiting for OpenClaw service to start..."
sleep 5

# Check service status
log_step "Checking OpenClaw service status..."
if systemctl is-active --quiet openclaw; then
    log_info "OpenClaw service is running"

    # Verify the port is actually listening
    log_step "Verifying OpenClaw is listening on port 18789..."
    sleep 2

    if ss -tlnp 2>/dev/null | grep -q ':18789'; then
        log_info "OpenClaw gateway is listening on port 18789"
    else
        log_warning "OpenClaw service is running but port 18789 is NOT listening!"
        log_warning "This usually means the gateway failed to start properly."
        echo ""
        echo "=== Recent logs ==="
        journalctl -u openclaw -n 20 --no-pager 2>/dev/null || true
        echo ""
        log_info "Try running manually to see errors:"
        log_info "  sudo -u openclaw HOME=/var/lib/openclaw openclaw gateway --port 18789"
    fi
else
    log_warning "OpenClaw service failed to start!"
    echo ""
    echo "=== Service status ==="
    systemctl status openclaw --no-pager 2>/dev/null || true
    echo ""
    echo "=== Recent logs ==="
    journalctl -u openclaw -n 30 --no-pager 2>/dev/null || true
    echo ""
    log_info "Check logs with: journalctl -u openclaw -n 50"
fi

log_info "OpenClaw systemd service configured"

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

# Method 1: Check if running in a container (most reliable)
CONTAINER_TYPE=$(systemd-detect-virt --container 2>/dev/null || echo "none")
if [ "$CONTAINER_TYPE" != "none" ] && [ -n "$CONTAINER_TYPE" ]; then
    log_warning "Container detected: $CONTAINER_TYPE"
    log_info "Disabling namespace features (not supported in containers)"
    SYSTEMD_SECURITY_SUPPORTED=false
fi

# Method 2: Check /proc/1/status for container indicators
if [ "$SYSTEMD_SECURITY_SUPPORTED" = "true" ]; then
    if grep -q "lxc\|docker\|container" /proc/1/cgroup 2>/dev/null; then
        log_warning "Container environment detected via cgroup"
        SYSTEMD_SECURITY_SUPPORTED=false
    fi
fi

# Method 3: Try running a command with PrivateTmp (actual runtime test)
if [ "$SYSTEMD_SECURITY_SUPPORTED" = "true" ]; then
    if ! systemd-run --quiet --wait --property=PrivateTmp=yes /bin/true 2>/dev/null; then
        log_warning "Namespace test failed at runtime"
        SYSTEMD_SECURITY_SUPPORTED=false
    fi
fi

if [ "$SYSTEMD_SECURITY_SUPPORTED" = "false" ]; then
    log_info "Using basic service configuration (still secure via loopback binding)"
fi

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

# Function to create basic service (no security hardening)
create_basic_service() {
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
    systemctl daemon-reload
}

# Function to start and verify service
start_and_verify_service() {
    systemctl stop openclaw 2>/dev/null || true
    systemctl start openclaw
    sleep 5

    if systemctl is-active --quiet openclaw; then
        return 0
    else
        return 1
    fi
}

log_step "Enabling and starting OpenClaw service..."

# Reload systemd daemon
systemctl daemon-reload

# Enable service to start on boot
systemctl enable openclaw

# Try to start the service
if ! start_and_verify_service; then
    # Check if it's a NAMESPACE error
    if systemctl status openclaw 2>&1 | grep -q "NAMESPACE\|226"; then
        log_warning "Service failed with NAMESPACE error - VPS doesn't support security hardening"
        log_info "Recreating service without namespace features..."

        # Recreate with basic config
        create_basic_service

        # Try again
        if start_and_verify_service; then
            log_info "Service started successfully with basic configuration"
        else
            log_warning "Service still failed after removing security hardening"
        fi
    fi
fi

# Final status check
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

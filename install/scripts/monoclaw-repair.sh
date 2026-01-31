#!/bin/bash
# MonoClaw Installer - Repair Script Creator
# Creates the monoclaw-repair management script

log_step "Creating monoclaw-repair script..."

cat > /usr/local/vps-scripts/monoclaw-repair <<'SCRIPT'
#!/bin/bash
# MonoClaw Repair - Fixes common issues with OpenClaw service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo monoclaw-repair)${NC}"
    exit 1
fi

echo "=== MonoClaw Repair Tool ==="
echo ""

# Get service user
SERVICE_USER=$(cat /etc/monoclaw/service-user 2>/dev/null || echo "openclaw")

# Get openclaw path
OPENCLAW_PATH="$(command -v openclaw || echo /usr/bin/openclaw)"

# Check current service status
echo "Checking OpenClaw service..."

SERVICE_STATUS=$(systemctl status openclaw 2>&1 || true)

# Check for NAMESPACE error (226)
if echo "$SERVICE_STATUS" | grep -q "NAMESPACE\|226"; then
    echo -e "${YELLOW}Detected NAMESPACE error - VPS doesn't support systemd security hardening${NC}"
    echo ""
    echo "Recreating service without namespace features..."

    # Create basic service without security hardening
    cat > /etc/systemd/system/openclaw.service <<EOF
[Unit]
Description=OpenClaw AI Assistant Gateway
Documentation=https://docs.openclaw.ai/
After=network.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=/var/lib/openclaw
Environment=HOME=/var/lib/openclaw
Environment=NODE_ENV=production
ExecStart=${OPENCLAW_PATH} gateway --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload and restart
    systemctl daemon-reload
    systemctl restart openclaw

    echo ""
    echo "Waiting for service to start..."
    sleep 5

    if systemctl is-active --quiet openclaw; then
        echo -e "${GREEN}Service started successfully!${NC}"
    else
        echo -e "${RED}Service still not running. Check logs:${NC}"
        journalctl -u openclaw -n 20 --no-pager
        exit 1
    fi

# Check if service is not running for other reasons
elif ! systemctl is-active --quiet openclaw; then
    echo -e "${YELLOW}Service is not running${NC}"
    echo ""
    echo "Attempting to restart..."

    systemctl daemon-reload
    systemctl restart openclaw
    sleep 5

    if systemctl is-active --quiet openclaw; then
        echo -e "${GREEN}Service restarted successfully!${NC}"
    else
        echo -e "${RED}Service failed to start. Checking logs...${NC}"
        echo ""
        journalctl -u openclaw -n 30 --no-pager
        exit 1
    fi
else
    echo -e "${GREEN}Service is running${NC}"
fi

# Verify port is listening
echo ""
echo "Checking if gateway is listening on port 18789..."
sleep 2

if ss -tlnp 2>/dev/null | grep -q ':18789'; then
    echo -e "${GREEN}Gateway is listening on port 18789${NC}"
else
    echo -e "${YELLOW}Port 18789 is not listening yet. Checking logs...${NC}"
    journalctl -u openclaw -n 10 --no-pager
fi

# Check Tailscale serve
echo ""
echo "Checking Tailscale Serve..."
if tailscale serve status 2>/dev/null | grep -q "18789"; then
    echo -e "${GREEN}Tailscale Serve is configured${NC}"
    echo ""
    tailscale serve status
else
    echo -e "${YELLOW}Tailscale Serve may not be configured${NC}"
    echo "Run 'sudo monoclaw-tailscale' to configure"
fi

echo ""
echo "=== Repair Complete ==="
SCRIPT

chmod +x /usr/local/vps-scripts/monoclaw-repair
ln -sf /usr/local/vps-scripts/monoclaw-repair /usr/local/bin/monoclaw-repair

log_info "monoclaw-repair script created"

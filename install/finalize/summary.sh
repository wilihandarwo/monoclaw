#!/bin/bash
# MonoClaw Installer - Summary
# Prints completion message and usage instructions

log_section "Installation Complete!"

echo ""
echo "======================================="
echo "   MonoClaw has been installed!"
echo "======================================="
echo ""

# SSH Access Information
echo "=== SSH Access ==="
echo ""
echo "Connect to your server using:"
echo "  ssh ${MONOCLAW_PRIMARY_USER}@<server-ip> -p ${MONOCLAW_SSH_PORT}"
echo ""

# Dashboard Access Information
echo "=== OpenClaw Dashboard Access ==="
echo ""
echo "Local access (via SSH tunnel):"
echo "  1. Create tunnel: ssh -L 18789:127.0.0.1:18789 ${MONOCLAW_PRIMARY_USER}@<server-ip> -p ${MONOCLAW_SSH_PORT}"
echo "  2. Open browser: http://127.0.0.1:18789/"
echo ""

if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
    TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null)
    if [ -n "$TAILSCALE_STATUS" ]; then
        HOSTNAME=$(echo "$TAILSCALE_STATUS" | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
        TAILNET=$(echo "$TAILSCALE_STATUS" | grep -o '"MagicDNSSuffix":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$HOSTNAME" ] && [ -n "$TAILNET" ]; then
            echo "Tailscale access (from any device on your tailnet):"
            echo "  https://${HOSTNAME}.${TAILNET}/"
            echo ""
        fi
    fi
fi

# Management Commands
echo "=== Management Commands ==="
echo ""
echo "  monoclaw-status      - Check service status and dashboard URL"
echo "  monoclaw-logs        - View OpenClaw logs"
echo "  monoclaw-logs -f     - Follow logs in real-time"
echo "  monoclaw-config      - Manage configuration"
echo "  monoclaw-security    - Run security audit"
echo "  monoclaw-update      - Update OpenClaw to latest version"
echo "  monoclaw-tailscale   - Manage Tailscale settings"
echo ""

# Security Information
echo "=== Security Information ==="
echo ""
echo "Gateway authentication token stored at:"
echo "  /etc/monoclaw/auth-token"
echo ""
echo "View token with: sudo cat /etc/monoclaw/auth-token"
echo ""
echo "Run security audit: sudo monoclaw-security"
echo ""

# Service Control
echo "=== Service Control ==="
echo ""
echo "  sudo systemctl status openclaw   - Check service status"
echo "  sudo systemctl restart openclaw  - Restart service"
echo "  sudo systemctl stop openclaw     - Stop service"
echo "  sudo systemctl start openclaw    - Start service"
echo ""

# Channel Setup
echo "=== Channel Setup ==="
echo ""
echo "To set up WhatsApp, Telegram, or other channels:"
echo "  sudo -u openclaw HOME=/var/lib/openclaw openclaw channels login"
echo ""

# Reboot check
if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "===================================================="
    echo "  A system reboot is required (kernel was upgraded)"
    echo "  Please run: sudo reboot"
    echo "===================================================="
fi

echo ""
echo "For documentation, visit: https://docs.openclaw.ai/"
echo ""

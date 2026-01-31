#!/bin/bash
# MonoClaw Installer - monoclaw-status Script Creator

log_step "Creating monoclaw-status script..."

cat > /usr/local/vps-scripts/monoclaw-status <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-status - MonoClaw Service Status
# Usage: monoclaw-status

echo "=== OpenClaw Service Status ==="
echo ""
systemctl status openclaw --no-pager 2>/dev/null || echo "Service not found"

echo ""
echo "=== Listening Ports ==="
ss -tlnp 2>/dev/null | grep -E "(openclaw|18789)" || echo "OpenClaw not listening"

echo ""
echo "=== Tailscale Status ==="
if command -v tailscale >/dev/null 2>&1; then
    tailscale status 2>/dev/null || echo "Tailscale not connected"
else
    echo "Tailscale not installed"
fi

echo ""
echo "=== Tailscale Serve Status ==="
if command -v tailscale >/dev/null 2>&1; then
    tailscale serve status 2>/dev/null || echo "No Tailscale Serve configured"
else
    echo "Tailscale not installed"
fi

echo ""
echo "=== Dashboard Access ==="
echo ""
echo "Local (via SSH tunnel):"
echo "  http://127.0.0.1:18789/"
echo ""
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
    TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null)
    if [ -n "$TAILSCALE_STATUS" ]; then
        HOSTNAME=$(echo "$TAILSCALE_STATUS" | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
        TAILNET=$(echo "$TAILSCALE_STATUS" | grep -o '"MagicDNSSuffix":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$HOSTNAME" ] && [ -n "$TAILNET" ]; then
            echo "Tailscale (from any device on your tailnet):"
            echo "  https://${HOSTNAME}.${TAILNET}/"
        fi
    fi
fi

echo ""
echo "=== Recent Service Logs ==="
journalctl -u openclaw -n 10 --no-pager 2>/dev/null || echo "No logs available"
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-status
ln -sf /usr/local/vps-scripts/monoclaw-status /usr/local/bin/monoclaw-status

log_info "monoclaw-status script created"

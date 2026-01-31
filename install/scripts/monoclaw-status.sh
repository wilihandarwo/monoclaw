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
echo "Via Tailscale:"
echo "  Run 'tailscale serve status' to see your HTTPS URL"

echo ""
echo "=== Recent Service Logs ==="
journalctl -u openclaw -n 10 --no-pager 2>/dev/null || echo "No logs available"
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-status
ln -sf /usr/local/vps-scripts/monoclaw-status /usr/local/bin/monoclaw-status

log_info "monoclaw-status script created"

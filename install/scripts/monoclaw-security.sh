#!/bin/bash
# MonoClaw Installer - monoclaw-security Script Creator

log_step "Creating monoclaw-security script..."

cat > /usr/local/vps-scripts/monoclaw-security <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-security - MonoClaw Security Audit
# Usage: monoclaw-security [--deep] [--fix]

DEEP=""
FIX=""

for arg in "$@"; do
    case $arg in
        --deep)
            DEEP="--deep"
            ;;
        --fix)
            FIX="--fix"
            ;;
    esac
done

echo "=== MonoClaw Security Audit ==="
echo ""

echo "--- OpenClaw Security Audit ---"
sudo -u openclaw HOME=/var/lib/openclaw openclaw security audit $DEEP $FIX 2>/dev/null || {
    echo "OpenClaw security audit not available (service may not be running)"
}

echo ""
echo "--- File Permission Check ---"
echo ""
echo "MonoClaw config directory:"
ls -la /etc/monoclaw/ 2>/dev/null || echo "  Not found"

echo ""
echo "OpenClaw data directory:"
ls -la /var/lib/openclaw/ 2>/dev/null || echo "  Not found"

echo ""
echo "OpenClaw config file:"
ls -la /var/lib/openclaw/.openclaw/openclaw.json 2>/dev/null || echo "  Not found"

echo ""
echo "--- Firewall Status ---"
ufw status 2>/dev/null || echo "UFW not installed"

echo ""
echo "--- fail2ban Status ---"
if command -v fail2ban-client >/dev/null 2>&1; then
    fail2ban-client status sshd 2>/dev/null || echo "SSH jail not configured"
else
    echo "fail2ban not installed"
fi

echo ""
echo "--- SSH Configuration ---"
if [ -f /etc/ssh/sshd_config.d/99-custom.conf ]; then
    echo "Custom SSH config:"
    grep -E "^(Port|PermitRootLogin|PasswordAuthentication|AllowUsers)" /etc/ssh/sshd_config.d/99-custom.conf
else
    echo "Custom SSH config not found"
fi

echo ""
echo "--- Tailscale Status ---"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status 2>/dev/null || echo "Tailscale not connected"
else
    echo "Tailscale not installed"
fi

echo ""
echo "=== Security Audit Complete ==="
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-security
ln -sf /usr/local/vps-scripts/monoclaw-security /usr/local/bin/monoclaw-security

log_info "monoclaw-security script created"

#!/bin/bash
# MonoClaw Installer - Diagnose Script Creator
# Creates the monoclaw-diagnose management script

log_step "Creating monoclaw-diagnose script..."

cat > /usr/local/vps-scripts/monoclaw-diagnose <<'SCRIPT'
#!/bin/bash
# MonoClaw Diagnose - Comprehensive diagnostic tool for OpenClaw issues
# Run this when you see "disconnected (1008): pairing required" or other connection errors

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo monoclaw-diagnose)${NC}"
    exit 1
fi

echo "============================================="
echo "       MonoClaw Diagnostic Report"
echo "============================================="
echo ""

# Configuration
SERVICE_USER=$(cat /etc/monoclaw/service-user 2>/dev/null || echo "openclaw")
OPENCLAW_CONFIG="/var/lib/openclaw/.openclaw/openclaw.json"
STORED_TOKEN_FILE="/etc/monoclaw/auth-token"

ISSUES_FOUND=0
WARNINGS_FOUND=0

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    ((ISSUES_FOUND++))
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    ((WARNINGS_FOUND++))
}

info() {
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

# ============================================
# 1. Service Status
# ============================================
echo -e "${BLUE}1. Service Status${NC}"
echo "-------------------------------------------"

if systemctl is-active --quiet openclaw; then
    pass "OpenClaw service is running"
else
    fail "OpenClaw service is not running"
    info "Run: sudo systemctl start openclaw"
fi

if systemctl is-enabled --quiet openclaw; then
    pass "OpenClaw service is enabled at boot"
else
    warn "OpenClaw service is not enabled at boot"
    info "Run: sudo systemctl enable openclaw"
fi

echo ""

# ============================================
# 2. Port Listening
# ============================================
echo -e "${BLUE}2. Port Listening${NC}"
echo "-------------------------------------------"

if ss -tlnp 2>/dev/null | grep -q ':18789'; then
    pass "Gateway listening on port 18789"

    # Check if bound to loopback only
    if ss -tlnp 2>/dev/null | grep ':18789' | grep -q '127.0.0.1'; then
        pass "Gateway bound to loopback (127.0.0.1) - secure"
    else
        warn "Gateway may be bound to all interfaces"
    fi
else
    fail "Gateway NOT listening on port 18789"
    info "Check service logs: journalctl -u openclaw -n 50"
fi

echo ""

# ============================================
# 3. Configuration Files
# ============================================
echo -e "${BLUE}3. Configuration Files${NC}"
echo "-------------------------------------------"

# Check config directory
if [ -d "/var/lib/openclaw/.openclaw" ]; then
    pass "Config directory exists"

    # Check permissions
    dir_perms=$(stat -c "%a" "/var/lib/openclaw/.openclaw" 2>/dev/null)
    if [ "$dir_perms" = "700" ]; then
        pass "Config directory permissions correct (700)"
    else
        warn "Config directory permissions: $dir_perms (should be 700)"
    fi

    # Check ownership
    dir_owner=$(stat -c "%U:%G" "/var/lib/openclaw/.openclaw" 2>/dev/null)
    if [ "$dir_owner" = "$SERVICE_USER:$SERVICE_USER" ]; then
        pass "Config directory ownership correct ($SERVICE_USER)"
    else
        fail "Config directory ownership: $dir_owner (should be $SERVICE_USER:$SERVICE_USER)"
    fi
else
    fail "Config directory missing: /var/lib/openclaw/.openclaw"
fi

# Check config file
if [ -f "$OPENCLAW_CONFIG" ]; then
    pass "openclaw.json exists"

    # Check permissions
    file_perms=$(stat -c "%a" "$OPENCLAW_CONFIG" 2>/dev/null)
    if [ "$file_perms" = "600" ]; then
        pass "Config file permissions correct (600)"
    else
        warn "Config file permissions: $file_perms (should be 600)"
    fi

    # Check ownership
    file_owner=$(stat -c "%U:%G" "$OPENCLAW_CONFIG" 2>/dev/null)
    if [ "$file_owner" = "$SERVICE_USER:$SERVICE_USER" ]; then
        pass "Config file ownership correct ($SERVICE_USER)"
    else
        fail "Config file ownership: $file_owner (should be $SERVICE_USER:$SERVICE_USER)"
    fi
else
    fail "Config file missing: $OPENCLAW_CONFIG"
fi

echo ""

# ============================================
# 4. Authentication Token (Critical for pairing)
# ============================================
echo -e "${BLUE}4. Authentication Token${NC}"
echo "-------------------------------------------"

STORED_TOKEN=""
CONFIG_TOKEN=""

# Check stored token
if [ -f "$STORED_TOKEN_FILE" ]; then
    STORED_TOKEN=$(cat "$STORED_TOKEN_FILE")
    if [ -n "$STORED_TOKEN" ]; then
        pass "Stored token exists in $STORED_TOKEN_FILE"
        info "Token: ${STORED_TOKEN:0:16}...${STORED_TOKEN: -8}"
    else
        fail "Stored token file is empty"
    fi
else
    fail "Stored token file missing: $STORED_TOKEN_FILE"
fi

# Check config token
if [ -f "$OPENCLAW_CONFIG" ]; then
    if command -v jq >/dev/null 2>&1; then
        CONFIG_TOKEN=$(jq -r '.gateway.auth.token // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
        AUTH_MODE=$(jq -r '.gateway.auth.mode // empty' "$OPENCLAW_CONFIG" 2>/dev/null)

        if [ -n "$CONFIG_TOKEN" ]; then
            pass "Token configured in openclaw.json"
            info "Token: ${CONFIG_TOKEN:0:16}...${CONFIG_TOKEN: -8}"
        else
            fail "Token MISSING in openclaw.json - causes 'pairing required' error!"
            info "The gateway.auth.token field is empty or missing"
        fi

        if [ "$AUTH_MODE" = "token" ]; then
            pass "Auth mode is 'token'"
        elif [ -z "$AUTH_MODE" ]; then
            fail "Auth mode not set in config"
        else
            warn "Auth mode is '$AUTH_MODE' (expected 'token')"
        fi
    else
        warn "jq not installed - cannot parse JSON config"
        if grep -q '"token"' "$OPENCLAW_CONFIG" 2>/dev/null; then
            pass "Token appears to be present in config (basic check)"
        else
            fail "Token may be missing from config"
        fi
    fi
fi

# Compare tokens
if [ -n "$STORED_TOKEN" ] && [ -n "$CONFIG_TOKEN" ]; then
    if [ "$STORED_TOKEN" = "$CONFIG_TOKEN" ]; then
        pass "Tokens match between stored file and config"
    else
        fail "Token MISMATCH - causes 'pairing required' error!"
        info "Stored:  ${STORED_TOKEN:0:20}..."
        info "Config:  ${CONFIG_TOKEN:0:20}..."
        info "Run 'sudo monoclaw-repair' to fix"
    fi
fi

echo ""

# ============================================
# 5. Tailscale Configuration
# ============================================
echo -e "${BLUE}5. Tailscale Configuration${NC}"
echo "-------------------------------------------"

if command -v tailscale >/dev/null 2>&1; then
    pass "Tailscale is installed"

    if tailscale status >/dev/null 2>&1; then
        pass "Tailscale is connected"

        # Get Tailscale IP
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$TS_IP" ]; then
            info "Tailscale IP: $TS_IP"
        fi
    else
        fail "Tailscale is not connected"
        info "Run: sudo tailscale up"
    fi

    # Check serve status
    if tailscale serve status 2>/dev/null | grep -q "18789"; then
        pass "Tailscale Serve is configured for port 18789"

        # Extract URL
        SERVE_URL=$(tailscale serve status 2>/dev/null | grep "https://" | head -1 | awk '{print $1}')
        if [ -n "$SERVE_URL" ]; then
            info "Dashboard URL: $SERVE_URL"
        fi
    else
        warn "Tailscale Serve not configured"
        info "Run: sudo monoclaw-tailscale"
    fi
else
    fail "Tailscale not installed"
fi

echo ""

# ============================================
# 6. Gateway Configuration
# ============================================
echo -e "${BLUE}6. Gateway Configuration${NC}"
echo "-------------------------------------------"

if [ -f "$OPENCLAW_CONFIG" ] && command -v jq >/dev/null 2>&1; then
    GATEWAY_MODE=$(jq -r '.gateway.mode // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
    GATEWAY_BIND=$(jq -r '.gateway.bind // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
    GATEWAY_PORT=$(jq -r '.gateway.port // empty' "$OPENCLAW_CONFIG" 2>/dev/null)

    if [ "$GATEWAY_MODE" = "local" ]; then
        pass "Gateway mode: local"
    else
        warn "Gateway mode: $GATEWAY_MODE (expected 'local')"
    fi

    if [ "$GATEWAY_BIND" = "loopback" ]; then
        pass "Gateway bind: loopback"
    else
        warn "Gateway bind: $GATEWAY_BIND (expected 'loopback')"
    fi

    if [ "$GATEWAY_PORT" = "18789" ]; then
        pass "Gateway port: 18789"
    else
        warn "Gateway port: $GATEWAY_PORT (expected 18789)"
    fi
else
    warn "Cannot check gateway config (jq not available or config missing)"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "============================================="
echo "                 Summary"
echo "============================================="
echo ""

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "If you still see 'pairing required', make sure to enter"
    echo "your auth token in the Password field of the dashboard."
    echo ""
    echo "Your token: $STORED_TOKEN"
elif [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS_FOUND warning(s) found${NC}"
    echo "These may not prevent operation but should be addressed."
else
    echo -e "${RED}$ISSUES_FOUND issue(s) found${NC}"
    if [ $WARNINGS_FOUND -gt 0 ]; then
        echo -e "${YELLOW}$WARNINGS_FOUND warning(s) found${NC}"
    fi
    echo ""
    echo "Run 'sudo monoclaw-repair' to attempt automatic fixes."
fi

echo ""
SCRIPT

chmod +x /usr/local/vps-scripts/monoclaw-diagnose
ln -sf /usr/local/vps-scripts/monoclaw-diagnose /usr/local/bin/monoclaw-diagnose

log_info "monoclaw-diagnose script created"

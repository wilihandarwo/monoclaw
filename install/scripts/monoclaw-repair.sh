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

# Check for token mismatch (causes "pairing required" error)
echo ""
echo "Checking gateway authentication token..."

STORED_TOKEN=""
CONFIG_TOKEN=""
TOKEN_FIXED=false
OPENCLAW_CONFIG="/var/lib/openclaw/.openclaw/openclaw.json"

# Get stored token
if [ -f /etc/monoclaw/auth-token ]; then
    STORED_TOKEN=$(cat /etc/monoclaw/auth-token)
fi

# Get config token
if [ -f "$OPENCLAW_CONFIG" ]; then
    if command -v jq >/dev/null 2>&1; then
        CONFIG_TOKEN=$(jq -r '.gateway.auth.token // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
    else
        # Fallback: extract with grep/sed
        CONFIG_TOKEN=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$OPENCLAW_CONFIG" 2>/dev/null | head -1 | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi
fi

if [ -z "$STORED_TOKEN" ]; then
    echo -e "${RED}No auth token found in /etc/monoclaw/auth-token${NC}"
    echo "Generating new token..."
    STORED_TOKEN=$(openssl rand -hex 32)
    echo "$STORED_TOKEN" > /etc/monoclaw/auth-token
    chmod 600 /etc/monoclaw/auth-token
    echo -e "${GREEN}New token generated${NC}"
fi

if [ -z "$CONFIG_TOKEN" ]; then
    echo -e "${YELLOW}Auth token missing from openclaw.json - this causes 'pairing required' error${NC}"
    echo "Injecting token into config..."
    TOKEN_FIXED=true
elif [ "$CONFIG_TOKEN" != "$STORED_TOKEN" ]; then
    echo -e "${YELLOW}Token mismatch detected - this causes 'pairing required' error${NC}"
    echo "  Stored:  ${STORED_TOKEN:0:16}..."
    echo "  Config:  ${CONFIG_TOKEN:0:16}..."
    echo "Fixing token in config..."
    TOKEN_FIXED=true
else
    echo -e "${GREEN}Token is correctly configured${NC}"
fi

# Fix token if needed
if [ "$TOKEN_FIXED" = "true" ]; then
    if command -v jq >/dev/null 2>&1; then
        jq --arg token "$STORED_TOKEN" '
            .gateway.auth = {"mode": "token", "token": $token} |
            .gateway.trustedProxies = ["127.0.0.1", "::1"]
        ' "$OPENCLAW_CONFIG" > "${OPENCLAW_CONFIG}.tmp" && \
            mv "${OPENCLAW_CONFIG}.tmp" "$OPENCLAW_CONFIG"
    else
        # If jq not available, recreate minimal config with token
        cat > "$OPENCLAW_CONFIG" <<CONFIGEOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${STORED_TOKEN}"
    },
    "trustedProxies": ["127.0.0.1", "::1"]
  },
  "channels": {},
  "logging": {
    "redactSensitive": "tools"
  },
  "discovery": {
    "mdns": {
      "mode": "minimal"
    }
  }
}
CONFIGEOF
    fi

    chown ${SERVICE_USER}:${SERVICE_USER} "$OPENCLAW_CONFIG"
    chmod 600 "$OPENCLAW_CONFIG"
    echo -e "${GREEN}Token fixed in config${NC}"

    # Restart service to pick up new config
    echo "Restarting service to apply token fix..."
    systemctl restart openclaw
    sleep 3

    if systemctl is-active --quiet openclaw; then
        echo -e "${GREEN}Service restarted successfully${NC}"
    else
        echo -e "${RED}Service failed to restart after token fix${NC}"
    fi
fi

# Sync primary user's config with system token
echo ""
echo "Syncing primary user config..."

PRIMARY_USER=$(cat /etc/monoclaw/primary-user 2>/dev/null || echo "")
if [ -n "$PRIMARY_USER" ] && [ "$PRIMARY_USER" != "root" ]; then
    PRIMARY_USER_HOME=$(getent passwd "$PRIMARY_USER" | cut -d: -f6)

    if [ -n "$PRIMARY_USER_HOME" ] && [ -d "$PRIMARY_USER_HOME" ]; then
        PRIMARY_USER_CONFIG="$PRIMARY_USER_HOME/.openclaw/openclaw.json"

        # Create directory structure if missing
        mkdir -p "$PRIMARY_USER_HOME/.openclaw/agents/main/sessions"
        mkdir -p "$PRIMARY_USER_HOME/.openclaw/credentials"

        if [ -f "$PRIMARY_USER_CONFIG" ]; then
            # Check if user config has different token
            if command -v jq >/dev/null 2>&1; then
                USER_TOKEN=$(jq -r '.gateway.auth.token // empty' "$PRIMARY_USER_CONFIG" 2>/dev/null)
                USER_REMOTE_TOKEN=$(jq -r '.gateway.remote.token // empty' "$PRIMARY_USER_CONFIG" 2>/dev/null)

                if [ "$USER_TOKEN" != "$STORED_TOKEN" ] || [ "$USER_REMOTE_TOKEN" != "$STORED_TOKEN" ]; then
                    echo -e "${YELLOW}User config token mismatch - updating...${NC}"
                    jq --arg token "$STORED_TOKEN" '
                        .gateway.auth.token = $token |
                        .gateway.trustedProxies = ["127.0.0.1", "::1"] |
                        .gateway.remote = (.gateway.remote // {}) |
                        .gateway.remote.token = $token
                    ' "$PRIMARY_USER_CONFIG" > "${PRIMARY_USER_CONFIG}.tmp" && \
                    mv "${PRIMARY_USER_CONFIG}.tmp" "$PRIMARY_USER_CONFIG"
                    chown "${PRIMARY_USER}:${PRIMARY_USER}" "$PRIMARY_USER_CONFIG"
                    chmod 600 "$PRIMARY_USER_CONFIG"
                    echo -e "${GREEN}User config updated${NC}"
                else
                    echo -e "${GREEN}User config token matches${NC}"
                fi
            fi
        else
            # Create user config with matching token
            echo "Creating user config..."
            cat > "$PRIMARY_USER_CONFIG" <<USERCONFIGEOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${STORED_TOKEN}"
    },
    "trustedProxies": ["127.0.0.1", "::1"],
    "remote": {
      "token": "${STORED_TOKEN}"
    }
  },
  "channels": {},
  "logging": {
    "redactSensitive": "tools"
  },
  "discovery": {
    "mdns": {
      "mode": "minimal"
    }
  }
}
USERCONFIGEOF
            echo -e "${GREEN}User config created${NC}"
        fi

        # Fix ownership and permissions
        chown -R "${PRIMARY_USER}:${PRIMARY_USER}" "$PRIMARY_USER_HOME/.openclaw"
        chmod 700 "$PRIMARY_USER_HOME/.openclaw"
        [ -f "$PRIMARY_USER_CONFIG" ] && chmod 600 "$PRIMARY_USER_CONFIG"
    fi
else
    echo -e "${YELLOW}Primary user not found in /etc/monoclaw/primary-user${NC}"
fi

echo ""
echo "=== Repair Complete ==="

echo ""
echo "Your gateway token: $STORED_TOKEN"
echo "Enter this in the Password field of the dashboard to connect."
SCRIPT

chmod +x /usr/local/vps-scripts/monoclaw-repair
ln -sf /usr/local/vps-scripts/monoclaw-repair /usr/local/bin/monoclaw-repair

log_info "monoclaw-repair script created"

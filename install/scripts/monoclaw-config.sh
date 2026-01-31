#!/bin/bash
# MonoClaw Installer - monoclaw-config Script Creator

log_step "Creating monoclaw-config script..."

cat > /usr/local/vps-scripts/monoclaw-config <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-config - MonoClaw Configuration Management
# Usage: monoclaw-config [option]

set -e

OPENCLAW_CONFIG="/var/lib/openclaw/.openclaw/openclaw.json"
MONOCLAW_CONFIG_DIR="/etc/monoclaw"

show_usage() {
    echo "monoclaw-config - MonoClaw Configuration Management"
    echo ""
    echo "Usage: monoclaw-config [option]"
    echo ""
    echo "Options:"
    echo "  --show                Show current configuration"
    echo "  --token               Show gateway authentication token"
    echo "  --token-regenerate    Regenerate gateway authentication token"
    echo "  --edit                Edit OpenClaw configuration (opens in editor)"
    echo "  --help                Show this help"
}

show_config() {
    echo "=== MonoClaw Configuration ==="
    echo ""
    echo "Primary user: $(cat ${MONOCLAW_CONFIG_DIR}/primary-user 2>/dev/null || echo 'not set')"
    echo "Service user: $(cat ${MONOCLAW_CONFIG_DIR}/service-user 2>/dev/null || echo 'openclaw')"
    echo "Tailscale IP: $(cat ${MONOCLAW_CONFIG_DIR}/tailscale-ip 2>/dev/null || echo 'not set')"
    echo ""
    echo "=== OpenClaw Configuration ==="
    if [ -f "$OPENCLAW_CONFIG" ]; then
        cat "$OPENCLAW_CONFIG"
    else
        echo "Configuration file not found at: $OPENCLAW_CONFIG"
    fi
}

show_token() {
    TOKEN_FILE="${MONOCLAW_CONFIG_DIR}/auth-token"
    if [ -f "$TOKEN_FILE" ]; then
        echo "Gateway Authentication Token:"
        cat "$TOKEN_FILE"
    else
        echo "Token file not found at: $TOKEN_FILE"
        exit 1
    fi
}

regenerate_token() {
    echo "Regenerating gateway authentication token..."

    NEW_TOKEN=$(openssl rand -hex 32)

    # Update token file
    echo "$NEW_TOKEN" > "${MONOCLAW_CONFIG_DIR}/auth-token"
    chmod 600 "${MONOCLAW_CONFIG_DIR}/auth-token"

    # Update OpenClaw config if jq is available
    if command -v jq >/dev/null 2>&1 && [ -f "$OPENCLAW_CONFIG" ]; then
        jq --arg token "$NEW_TOKEN" '.gateway.auth.token = $token' "$OPENCLAW_CONFIG" > "${OPENCLAW_CONFIG}.tmp"
        mv "${OPENCLAW_CONFIG}.tmp" "$OPENCLAW_CONFIG"
        chown openclaw:openclaw "$OPENCLAW_CONFIG"
        chmod 600 "$OPENCLAW_CONFIG"
    fi

    echo ""
    echo "New token: $NEW_TOKEN"
    echo ""
    echo "Remember to update any remote clients with this new token."
    echo "Restarting OpenClaw service..."

    systemctl restart openclaw
}

edit_config() {
    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        echo "Configuration file not found at: $OPENCLAW_CONFIG"
        exit 1
    fi

    EDITOR=${EDITOR:-nano}
    $EDITOR "$OPENCLAW_CONFIG"

    echo ""
    echo "Configuration updated. Restarting OpenClaw service..."
    systemctl restart openclaw
}

case "${1:-}" in
    --show)
        show_config
        ;;
    --token)
        show_token
        ;;
    --token-regenerate)
        regenerate_token
        ;;
    --edit)
        edit_config
        ;;
    --help|"")
        show_usage
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-config
ln -sf /usr/local/vps-scripts/monoclaw-config /usr/local/bin/monoclaw-config

log_info "monoclaw-config script created"

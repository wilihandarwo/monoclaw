#!/bin/bash
# MonoClaw Installer - OpenClaw Security Configuration
# Configures security settings based on OpenClaw security best practices

log_step "Configuring OpenClaw security settings..."

# Check if token already exists
if [ -f /etc/monoclaw/auth-token ]; then
    MONOCLAW_AUTH_TOKEN=$(cat /etc/monoclaw/auth-token)
    log_info "Using existing gateway authentication token"
else
    # Generate a secure gateway authentication token
    MONOCLAW_AUTH_TOKEN=$(openssl rand -hex 32)

    # Store the token securely
    echo "$MONOCLAW_AUTH_TOKEN" > /etc/monoclaw/auth-token
    chmod 600 /etc/monoclaw/auth-token
    log_info "Generated new gateway authentication token"
fi

# Create OpenClaw configuration with security settings
# Based on https://docs.openclaw.ai/gateway/security
OPENCLAW_CONFIG="/var/lib/openclaw/.openclaw/openclaw.json"

# Ensure directory exists
mkdir -p /var/lib/openclaw/.openclaw
chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} /var/lib/openclaw/.openclaw
chmod 700 /var/lib/openclaw/.openclaw

# Check if config already exists from onboarding
create_fresh_config=false

if [ -f "$OPENCLAW_CONFIG" ]; then
    log_info "Existing OpenClaw configuration found, updating security settings..."

    # Backup existing config
    cp "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.backup"

    # Use jq to update security settings if available
    if command_exists jq; then
        jq --arg token "$MONOCLAW_AUTH_TOKEN" '
            .gateway = (.gateway // {}) |
            .gateway.mode = "local" |
            .gateway.bind = "loopback" |
            .gateway.port = 18789 |
            .gateway.auth = {
                "mode": "token",
                "token": $token
            } |
            .gateway.trustedProxies = ["127.0.0.1", "::1"] |
            .controlUi = { "allowInsecureAuth": true } |
            .logging = (.logging // {}) |
            .logging.redactSensitive = "tools" |
            .discovery = (.discovery // {}) |
            .discovery.mdns = { "mode": "minimal" }
        ' "$OPENCLAW_CONFIG" > "${OPENCLAW_CONFIG}.tmp" && mv "${OPENCLAW_CONFIG}.tmp" "$OPENCLAW_CONFIG"
    else
        log_warning "jq not installed, creating fresh security configuration"
        create_fresh_config=true
    fi
else
    create_fresh_config=true
fi

if [ "$create_fresh_config" = "true" ]; then
    # Create secure default configuration
    # Note: Empty channels - gateway chat works without explicit channels
    # Add WhatsApp/Telegram later with: sudo -u openclaw HOME=/var/lib/openclaw openclaw channels login
    # trustedProxies includes 127.0.0.1 for Tailscale Serve reverse proxy
    # controlUi.allowInsecureAuth enables dashboard access without device identity
    cat > "$OPENCLAW_CONFIG" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${MONOCLAW_AUTH_TOKEN}"
    },
    "trustedProxies": ["127.0.0.1", "::1"]
  },
  "controlUi": {
    "allowInsecureAuth": true
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
EOF
fi

# Set proper permissions on config
chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} "$OPENCLAW_CONFIG"
chmod 600 "$OPENCLAW_CONFIG"

# Verify token was properly injected into config
log_info "Verifying token injection..."
verify_failed=false

if [ -f "$OPENCLAW_CONFIG" ]; then
    if command_exists jq; then
        # Use jq to verify token
        config_token=$(jq -r '.gateway.auth.token // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
        if [ -z "$config_token" ]; then
            log_warning "Token not found in config - gateway.auth.token is missing"
            verify_failed=true
        elif [ "$config_token" != "$MONOCLAW_AUTH_TOKEN" ]; then
            log_warning "Token mismatch detected between config and stored token"
            verify_failed=true
        fi
    else
        # Fallback: grep for token in config
        if ! grep -q "$MONOCLAW_AUTH_TOKEN" "$OPENCLAW_CONFIG" 2>/dev/null; then
            log_warning "Token may not be properly set in config (jq not available for precise check)"
            verify_failed=true
        fi
    fi
else
    log_error "Config file not created at $OPENCLAW_CONFIG"
    verify_failed=true
fi

# Attempt to fix if verification failed
if [ "$verify_failed" = "true" ]; then
    log_warning "Attempting to fix token injection..."

    # Force recreate config with token
    cat > "$OPENCLAW_CONFIG" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${MONOCLAW_AUTH_TOKEN}"
    },
    "trustedProxies": ["127.0.0.1", "::1"]
  },
  "controlUi": {
    "allowInsecureAuth": true
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
EOF
    chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} "$OPENCLAW_CONFIG"
    chmod 600 "$OPENCLAW_CONFIG"
    log_info "Config recreated with token"
fi

log_info "OpenClaw security configuration complete"
log_info "Security audit will be available after service starts"

# Also configure the primary user's OpenClaw config with the same token
# This prevents "pairing required" errors when user runs openclaw commands
if [ -n "$MONOCLAW_PRIMARY_USER" ] && [ "$MONOCLAW_PRIMARY_USER" != "root" ]; then
    PRIMARY_USER_HOME=$(getent passwd "$MONOCLAW_PRIMARY_USER" | cut -d: -f6)

    if [ -n "$PRIMARY_USER_HOME" ] && [ -d "$PRIMARY_USER_HOME" ]; then
        log_info "Configuring OpenClaw for primary user ($MONOCLAW_PRIMARY_USER)..."

        PRIMARY_USER_OPENCLAW_DIR="$PRIMARY_USER_HOME/.openclaw"
        PRIMARY_USER_CONFIG="$PRIMARY_USER_OPENCLAW_DIR/openclaw.json"

        # Create user's .openclaw directory
        mkdir -p "$PRIMARY_USER_OPENCLAW_DIR"
        mkdir -p "$PRIMARY_USER_OPENCLAW_DIR/agents/main/sessions"
        mkdir -p "$PRIMARY_USER_OPENCLAW_DIR/credentials"

        # Create or update user's config with matching token
        if [ -f "$PRIMARY_USER_CONFIG" ] && command_exists jq; then
            # Update existing config
            jq --arg token "$MONOCLAW_AUTH_TOKEN" '
                .gateway = (.gateway // {}) |
                .gateway.mode = "local" |
                .gateway.bind = "loopback" |
                .gateway.port = 18789 |
                .gateway.auth = {
                    "mode": "token",
                    "token": $token
                } |
                .gateway.trustedProxies = ["127.0.0.1", "::1"] |
                .gateway.remote = (.gateway.remote // {}) |
                .gateway.remote.token = $token |
                .controlUi = { "allowInsecureAuth": true }
            ' "$PRIMARY_USER_CONFIG" > "${PRIMARY_USER_CONFIG}.tmp" && \
            mv "${PRIMARY_USER_CONFIG}.tmp" "$PRIMARY_USER_CONFIG"
        else
            # Create fresh config for user
            cat > "$PRIMARY_USER_CONFIG" <<USEREOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${MONOCLAW_AUTH_TOKEN}"
    },
    "trustedProxies": ["127.0.0.1", "::1"],
    "remote": {
      "token": "${MONOCLAW_AUTH_TOKEN}"
    }
  },
  "controlUi": {
    "allowInsecureAuth": true
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
USEREOF
        fi

        # Set proper ownership and permissions for user
        chown -R "${MONOCLAW_PRIMARY_USER}:${MONOCLAW_PRIMARY_USER}" "$PRIMARY_USER_OPENCLAW_DIR"
        chmod 700 "$PRIMARY_USER_OPENCLAW_DIR"
        chmod 600 "$PRIMARY_USER_CONFIG"

        log_info "Primary user OpenClaw config created with matching token"
    fi
fi

# Display token info
echo ""
print_box "Gateway Authentication Token"
echo ""
echo "Your gateway authentication token is stored at:"
echo "  /etc/monoclaw/auth-token"
echo ""
echo "Token: ${MONOCLAW_AUTH_TOKEN}"
echo ""
echo "Keep this token secure! You'll need it to connect to the gateway."
echo "You can view it later with: sudo cat /etc/monoclaw/auth-token"
echo ""

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
    cat > "$OPENCLAW_CONFIG" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${MONOCLAW_AUTH_TOKEN}"
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
EOF
    chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} "$OPENCLAW_CONFIG"
    chmod 600 "$OPENCLAW_CONFIG"
    log_info "Config recreated with token"
fi

log_info "OpenClaw security configuration complete"
log_info "Security audit will be available after service starts"

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

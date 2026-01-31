#!/bin/bash
# MonoClaw Installer - Configuration Prompts
# Gathers all user input at the start of installation

log_section "Configuration"

# --- Primary User Configuration ---
# Only prompt if not already set (from config file)
if [ -z "$MONOCLAW_PRIMARY_USER" ]; then
    read -p "Enter primary username (for SSH access): " MONOCLAW_PRIMARY_USER
fi

if [ -z "$MONOCLAW_SSH_PORT" ]; then
    read -p "Enter SSH port [22]: " MONOCLAW_SSH_PORT
    MONOCLAW_SSH_PORT=${MONOCLAW_SSH_PORT:-22}
fi

# Optional local password for the primary user (used for sudo/console, not SSH)
if [ -z "$MONOCLAW_PRIMARY_USER_PASS" ]; then
    echo ""
    echo "Optional: Set a password for ${MONOCLAW_PRIMARY_USER} (for sudo/console access)"
    echo "Leave empty to use SSH key-only authentication."
    read -s -p "Enter password (leave empty for none): " MONOCLAW_PRIMARY_USER_PASS_1; echo

    if [ -n "$MONOCLAW_PRIMARY_USER_PASS_1" ]; then
        read -s -p "Confirm password: " MONOCLAW_PRIMARY_USER_PASS_2; echo

        if [ "$MONOCLAW_PRIMARY_USER_PASS_1" != "$MONOCLAW_PRIMARY_USER_PASS_2" ]; then
            log_error "Passwords do not match"
            exit 1
        fi
    fi
    export MONOCLAW_PRIMARY_USER_PASS="$MONOCLAW_PRIMARY_USER_PASS_1"
fi

# --- Export all configuration variables ---
export MONOCLAW_PRIMARY_USER
export MONOCLAW_SSH_PORT
export MONOCLAW_SERVICE_USER="openclaw"

# --- Store persistent configuration ---
log_step "Storing persistent configuration..."
mkdir -p /etc/monoclaw
chmod 700 /etc/monoclaw

# Store primary user for reference by management scripts
echo "$MONOCLAW_PRIMARY_USER" > /etc/monoclaw/primary-user
chmod 644 /etc/monoclaw/primary-user

# Store service user
echo "$MONOCLAW_SERVICE_USER" > /etc/monoclaw/service-user
chmod 644 /etc/monoclaw/service-user

log_info "Configuration complete. Starting installation..."

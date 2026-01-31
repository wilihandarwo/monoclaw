#!/bin/bash
# MonoClaw Installer - OpenClaw Installation
# Installs OpenClaw via npm and runs onboarding

log_step "Installing OpenClaw globally via npm..."

# Check if OpenClaw is already installed
if command -v openclaw &>/dev/null; then
    CURRENT_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
    log_info "OpenClaw already installed (version: ${CURRENT_VERSION}), updating to latest..."
    npm update -g openclaw@latest || npm install -g openclaw@latest
else
    # Install OpenClaw globally
    npm install -g openclaw@latest
fi

# Verify installation
log_step "Verifying OpenClaw installation..."
INSTALLED_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
log_info "OpenClaw ${INSTALLED_VERSION} installed successfully"

log_step "Running OpenClaw onboarding..."

# Create .openclaw directory for service user with proper ownership
mkdir -p /var/lib/openclaw/.openclaw
chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} /var/lib/openclaw/.openclaw
chmod 700 /var/lib/openclaw/.openclaw

# Check if onboarding was already completed
if [ -f "/var/lib/openclaw/.openclaw/openclaw.json" ]; then
    log_info "OpenClaw configuration already exists, skipping onboarding"
else
    # Run onboarding as the service user with daemon installation
    echo ""
    echo "======================================="
    echo "OpenClaw Onboarding"
    echo "======================================="
    echo ""
    echo "This will set up OpenClaw and may prompt you to:"
    echo "  1. Scan a QR code with WhatsApp"
    echo "  2. Configure channels (Telegram, Discord, etc.)"
    echo ""
    echo "You can skip channel setup now and configure later with 'openclaw channels login'"
    echo ""

    # Run onboarding as the service user
    sudo -u ${MONOCLAW_SERVICE_USER} HOME=/var/lib/openclaw openclaw onboard --install-daemon || {
        log_warning "Onboarding may have been partially completed. You can run 'openclaw onboard' later."
    }
fi

log_info "OpenClaw installation complete"

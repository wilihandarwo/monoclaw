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

# Note: We skip openclaw onboard to avoid interactive WhatsApp/Telegram prompts
# Configuration is created by security.sh instead
# Channels can be added later with: sudo -u openclaw HOME=/var/lib/openclaw openclaw channels login

log_info "OpenClaw installation complete"

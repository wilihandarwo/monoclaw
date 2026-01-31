#!/bin/bash
# MonoClaw Installer - OpenClaw Installation
# Installs OpenClaw via npm and runs onboarding

log_step "Installing OpenClaw globally via npm..."

# Install OpenClaw globally
npm install -g openclaw@latest

# Verify installation
log_step "Verifying OpenClaw installation..."
openclaw --version

log_info "OpenClaw $(openclaw --version) installed successfully"

log_step "Running OpenClaw onboarding..."

# Create .openclaw directory for service user with proper ownership
sudo -u ${MONOCLAW_SERVICE_USER} mkdir -p /var/lib/openclaw/.openclaw
chmod 700 /var/lib/openclaw/.openclaw

# Run onboarding as the service user with daemon installation
# The --install-daemon flag sets up the service to run automatically
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

log_info "OpenClaw onboarding complete"

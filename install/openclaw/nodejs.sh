#!/bin/bash
# MonoClaw Installer - Node.js Installation
# Installs Node.js 22 LTS via NodeSource

log_step "Installing Node.js 22 LTS..."

# Install Node.js 22 via NodeSource
# https://github.com/nodesource/distributions
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Verify installation
log_step "Verifying Node.js installation..."
node --version
npm --version

log_info "Node.js $(node --version) installed successfully"

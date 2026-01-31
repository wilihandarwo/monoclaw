#!/bin/bash
# MonoClaw Installer - Node.js Installation
# Installs Node.js 22 LTS via NodeSource

log_step "Installing Node.js 22 LTS..."

# Check if Node.js 22 is already installed
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -ge 22 ] 2>/dev/null; then
        log_info "Node.js $(node --version) already installed, skipping"
    else
        log_info "Node.js $NODE_VERSION found, upgrading to Node.js 22..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt install -y nodejs
    fi
else
    # Install Node.js 22 via NodeSource
    # https://github.com/nodesource/distributions
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
fi

# Verify installation
log_step "Verifying Node.js installation..."
node --version
npm --version

log_info "Node.js $(node --version) installed successfully"

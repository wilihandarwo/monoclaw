#!/bin/bash
# MonoClaw Installer - Firewall Configuration
# Sets up UFW firewall rules

log_step "Configuring firewall (UFW)..."

# Allow custom SSH port
ufw allow ${MONOCLAW_SSH_PORT}/tcp

# Note: HTTP/HTTPS ports are NOT opened because:
# - OpenClaw binds to 127.0.0.1:18789 (loopback only)
# - Dashboard access is via Tailscale Serve (which uses outbound connections)
# - Tailscale does not require any inbound ports to be opened

# Enable firewall
ufw --force enable
ufw status

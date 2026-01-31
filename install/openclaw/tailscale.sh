#!/bin/bash
# MonoClaw Installer - Tailscale Installation and Configuration
# Installs Tailscale and configures Tailscale Serve for secure dashboard access

log_step "Installing Tailscale..."

# Check if Tailscale is already installed
if command -v tailscale &>/dev/null; then
    log_info "Tailscale already installed, skipping installation"
else
    # Install Tailscale using the official install script
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Verify installation
log_step "Verifying Tailscale installation..."
tailscale --version

log_info "Tailscale installed successfully"

# Check if Tailscale is already connected
if tailscale status &>/dev/null; then
    log_info "Tailscale already connected"
else
    log_step "Authenticating Tailscale..."

    echo ""
    echo "======================================="
    echo "Tailscale Authentication"
    echo "======================================="
    echo ""
    echo "You need to authenticate this server with your Tailscale account."
    echo "This will display a URL that you need to visit in your browser."
    echo ""
    echo "If you don't have a Tailscale account, create one at: https://tailscale.com/"
    echo ""

    # Start Tailscale and authenticate
    tailscale up
fi

# Wait for Tailscale to connect
log_step "Waiting for Tailscale connection..."
sleep 3

# Initialize variables
TAILSCALE_IP=""

# Check Tailscale status
if tailscale status &>/dev/null; then
    log_info "Tailscale connected successfully"

    # Get the Tailscale IP (with error handling)
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null) || TAILSCALE_IP=""

    if [ -n "$TAILSCALE_IP" ]; then
        log_info "Tailscale IP: ${TAILSCALE_IP}"
    fi
else
    log_warning "Tailscale may not be connected. Run 'tailscale up' to authenticate."
fi

log_step "Configuring Tailscale Serve for OpenClaw dashboard..."

# Configure Tailscale Serve to proxy the OpenClaw dashboard
# This creates: https://<hostname>.<tailnet>.ts.net → localhost:18789
tailscale serve --bg 18789 || {
    log_warning "Tailscale Serve configuration may have failed."
    log_info "You can configure it manually later with: tailscale serve --bg 18789"
}

log_info "Tailscale Serve configured"

# Display access information
echo ""
print_box "Dashboard Access via Tailscale"
echo ""
echo "Your OpenClaw dashboard is now accessible via Tailscale!"
echo ""
echo "To find your exact URL, run: tailscale serve status"
echo ""
echo "Note: You must have Tailscale installed on your local device to access this URL."
echo "Install Tailscale at: https://tailscale.com/download"
echo ""

# Store Tailscale info for later reference
if [ -n "$TAILSCALE_IP" ]; then
    echo "$TAILSCALE_IP" > /etc/monoclaw/tailscale-ip
    chmod 644 /etc/monoclaw/tailscale-ip
fi

log_info "Tailscale setup complete"

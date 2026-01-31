#!/bin/bash
# MonoClaw Installer - monoclaw-tailscale Script Creator

log_step "Creating monoclaw-tailscale script..."

cat > /usr/local/vps-scripts/monoclaw-tailscale <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-tailscale - Tailscale Management for MonoClaw
# Usage: monoclaw-tailscale [option]

show_usage() {
    echo "monoclaw-tailscale - Tailscale Management for MonoClaw"
    echo ""
    echo "Usage: monoclaw-tailscale [option]"
    echo ""
    echo "Options:"
    echo "  status        Show Tailscale status and serve configuration"
    echo "  reconnect     Reconnect to Tailscale"
    echo "  serve-reset   Reset Tailscale Serve configuration"
    echo "  serve-setup   Set up Tailscale Serve for OpenClaw dashboard"
    echo "  url           Show the dashboard URL"
    echo "  help          Show this help"
}

check_tailscale() {
    if ! command -v tailscale >/dev/null 2>&1; then
        echo "Error: Tailscale is not installed"
        exit 1
    fi
}

show_status() {
    check_tailscale

    echo "=== Tailscale Status ==="
    echo ""
    tailscale status

    echo ""
    echo "=== Tailscale Serve Status ==="
    tailscale serve status 2>/dev/null || echo "No Tailscale Serve configured"
}

reconnect() {
    check_tailscale

    echo "Reconnecting to Tailscale..."
    tailscale up
}

serve_reset() {
    check_tailscale

    echo "Resetting Tailscale Serve configuration..."
    tailscale serve reset 2>/dev/null || echo "Nothing to reset"
    echo "Done."
}

serve_setup() {
    check_tailscale

    echo "Setting up Tailscale Serve for OpenClaw dashboard..."
    # Proxy HTTPS traffic to localhost:18789
    tailscale serve --bg 18789 || {
        echo "Warning: Tailscale Serve may have failed."
        echo "Try running: tailscale serve --bg 18789"
        return 1
    }

    echo ""
    echo "Tailscale Serve configured. Your dashboard URL:"
    show_url
}

show_url() {
    check_tailscale

    if ! tailscale status >/dev/null 2>&1; then
        echo "Error: Tailscale is not connected"
        exit 1
    fi

    # Try to get serve status for the URL
    echo ""
    echo "=== Dashboard URL ==="
    echo ""
    tailscale serve status 2>/dev/null || {
        echo "Tailscale Serve not configured."
        echo "Run 'monoclaw-tailscale serve-setup' to configure."
    }
    echo ""
    echo "Access this URL from any device on your Tailscale network."
}

case "${1:-help}" in
    status)
        show_status
        ;;
    reconnect)
        reconnect
        ;;
    serve-reset)
        serve_reset
        ;;
    serve-setup)
        serve_setup
        ;;
    url)
        show_url
        ;;
    help|--help)
        show_usage
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-tailscale
ln -sf /usr/local/vps-scripts/monoclaw-tailscale /usr/local/bin/monoclaw-tailscale

log_info "monoclaw-tailscale script created"

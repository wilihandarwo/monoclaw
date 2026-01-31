#!/bin/bash
# MonoClaw Installer - monoclaw-update Script Creator

log_step "Creating monoclaw-update script..."

cat > /usr/local/vps-scripts/monoclaw-update <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-update - Update OpenClaw to Latest Version
# Usage: monoclaw-update

set -e

echo "=== Updating OpenClaw ==="
echo ""

# Get current version
CURRENT_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
echo "Current version: $CURRENT_VERSION"

echo ""
echo "Stopping OpenClaw service..."
systemctl stop openclaw

echo ""
echo "Updating OpenClaw via npm..."
npm update -g openclaw@latest

# Get new version
NEW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")

echo ""
echo "Starting OpenClaw service..."
systemctl start openclaw

# Wait for service to start
sleep 3

echo ""
echo "=== Update Complete ==="
echo ""
echo "Previous version: $CURRENT_VERSION"
echo "New version: $NEW_VERSION"
echo ""
echo "Service status:"
systemctl status openclaw --no-pager
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-update
ln -sf /usr/local/vps-scripts/monoclaw-update /usr/local/bin/monoclaw-update

log_info "monoclaw-update script created"

#!/bin/bash
# MonoClaw Installer - monoclaw-logs Script Creator

log_step "Creating monoclaw-logs script..."

cat > /usr/local/vps-scripts/monoclaw-logs <<'SCRIPT_EOF'
#!/bin/bash
# monoclaw-logs - MonoClaw Log Viewer
# Usage: monoclaw-logs [lines] [-f|--follow]

LINES="${1:-50}"
FOLLOW=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        -f|--follow)
            FOLLOW="-f"
            ;;
        [0-9]*)
            LINES="$arg"
            ;;
    esac
done

if [ -n "$FOLLOW" ]; then
    echo "Following OpenClaw logs (Ctrl+C to stop)..."
    journalctl -u openclaw -f
else
    echo "=== OpenClaw Logs (last $LINES lines) ==="
    journalctl -u openclaw -n "$LINES" --no-pager
fi
SCRIPT_EOF

chmod +x /usr/local/vps-scripts/monoclaw-logs
ln -sf /usr/local/vps-scripts/monoclaw-logs /usr/local/bin/monoclaw-logs

log_info "monoclaw-logs script created"

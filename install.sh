#!/bin/bash
# MonoClaw Installer - Main Entry Point
# https://github.com/your-repo/monoclaw
#
# Usage: sudo bash install.sh [options]
#
# Options:
#   --config FILE       Load configuration from file
#   --help              Show this help message

# Exit immediately on errors, handle pipelines properly
set -eEo pipefail

# Show usage
show_usage() {
    echo "MonoClaw Installer - OpenClaw AI Assistant VPS Setup"
    echo ""
    echo "Usage: sudo bash install.sh [options]"
    echo ""
    echo "Options:"
    echo "  --config FILE       Load configuration from file (skip interactive prompts)"
    echo "  --help              Show this help message"
    echo ""
    echo "Configuration file format:"
    echo "  PRIMARY_USER=username"
    echo "  SSH_PORT=2222"
}

# Parse arguments
export MONOCLAW_CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            MONOCLAW_CONFIG_FILE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Define MonoClaw paths
export MONOCLAW_PATH="$(cd "$(dirname "$0")" && pwd)"
export MONOCLAW_INSTALL="$MONOCLAW_PATH/install"
export MONOCLAW_TEMPLATES="$MONOCLAW_PATH/templates"

# Load configuration file if provided
if [ -n "$MONOCLAW_CONFIG_FILE" ]; then
    if [ ! -f "$MONOCLAW_CONFIG_FILE" ]; then
        echo "ERROR: Configuration file not found: $MONOCLAW_CONFIG_FILE"
        exit 1
    fi
    echo "Loading configuration from: $MONOCLAW_CONFIG_FILE"
    source "$MONOCLAW_CONFIG_FILE"

    # Map config file variables to MONOCLAW_ prefix
    export MONOCLAW_PRIMARY_USER="${PRIMARY_USER:-}"
    export MONOCLAW_SSH_PORT="${SSH_PORT:-}"
fi

# Source all modules in order
source "$MONOCLAW_INSTALL/helpers/all.sh"
source "$MONOCLAW_INSTALL/config/all.sh"
source "$MONOCLAW_INSTALL/system/all.sh"
source "$MONOCLAW_INSTALL/openclaw/all.sh"
source "$MONOCLAW_INSTALL/security/all.sh"
source "$MONOCLAW_INSTALL/scripts/all.sh"
source "$MONOCLAW_INSTALL/finalize/all.sh"

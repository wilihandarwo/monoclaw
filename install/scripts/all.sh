#!/bin/bash
# MonoClaw Installer - Management Scripts Orchestrator
# Creates all MonoClaw management scripts

log_section "Creating Management Scripts"

# Ensure the scripts directory exists
log_step "Creating scripts directory..."
mkdir -p /usr/local/vps-scripts
chmod 755 /usr/local/vps-scripts

run_script "$MONOCLAW_INSTALL/scripts/monoclaw-config.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-status.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-logs.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-security.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-update.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-tailscale.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-repair.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-diagnose.sh"

log_info "Management Scripts Complete"

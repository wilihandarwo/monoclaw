#!/bin/bash
# MonoClaw Installer - Management Scripts Orchestrator
# Creates all MonoClaw management scripts

log_section "Creating Management Scripts"

run_script "$MONOCLAW_INSTALL/scripts/monoclaw-config.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-status.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-logs.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-security.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-update.sh"
run_script "$MONOCLAW_INSTALL/scripts/monoclaw-tailscale.sh"

log_info "Management Scripts Complete"

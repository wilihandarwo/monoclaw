#!/bin/bash
# MonoClaw Installer - OpenClaw Setup Orchestrator
# Section 2: OpenClaw Installation

log_section "Section 2: OpenClaw Installation"

run_script "$MONOCLAW_INSTALL/openclaw/nodejs.sh"
run_script "$MONOCLAW_INSTALL/openclaw/install.sh"
# Security config must be created BEFORE starting the service
run_script "$MONOCLAW_INSTALL/openclaw/security.sh"
run_script "$MONOCLAW_INSTALL/openclaw/systemd.sh"
run_script "$MONOCLAW_INSTALL/openclaw/tailscale.sh"

log_info "Section 2 Complete"

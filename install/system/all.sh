#!/bin/bash
# MonoClaw Installer - System Setup Orchestrator
# Section 1: Initial VPS Setup

log_section "Section 1: Initial VPS Setup"

run_script "$MONOCLAW_INSTALL/system/packages.sh"
run_script "$MONOCLAW_INSTALL/system/firewall.sh"
run_script "$MONOCLAW_INSTALL/system/user.sh"
run_script "$MONOCLAW_INSTALL/system/ssh.sh"

log_info "Section 1 Complete"
echo "IMPORTANT: For future logins, use: 'ssh ${MONOCLAW_PRIMARY_USER}@your_server_ip -p ${MONOCLAW_SSH_PORT}'"

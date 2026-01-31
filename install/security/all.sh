#!/bin/bash
# MonoClaw Installer - Security Orchestrator

log_section "Security Configuration"

run_script "$MONOCLAW_INSTALL/security/fail2ban.sh"

log_info "Security Configuration Complete"

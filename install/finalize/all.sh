#!/bin/bash
# MonoClaw Installer - Finalize Orchestrator
# Final configuration and summary

log_section "Finalizing Installation"

run_script "$MONOCLAW_INSTALL/finalize/directories.sh"
run_script "$MONOCLAW_INSTALL/finalize/summary.sh"

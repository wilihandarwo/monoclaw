# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MonoClaw is a modular bash-based VPS installer that configures a fresh Ubuntu 24.04 server for hosting OpenClaw AI Assistant. It sets up:

- SSH hardening (custom port, key-only auth, non-root user)
- Node.js 22 runtime
- OpenClaw AI Assistant daemon
- Tailscale Serve for secure dashboard access
- Systemd service management
- fail2ban protection for SSH

## Architecture

### Modular Installer

The installer follows the Omarchy pattern with a single entry point that sources module orchestrators in sequence:

```
install.sh                        # Entry point: sudo bash install.sh
└── sources modules in order:
    ├── install/helpers/all.sh    # Logging & utility functions
    ├── install/config/all.sh     # User prompts (gathers config)
    ├── install/system/all.sh     # SSH, UFW, user creation
    ├── install/openclaw/all.sh   # Node.js, OpenClaw, Tailscale
    ├── install/security/all.sh   # fail2ban configuration
    ├── install/scripts/all.sh    # Management script creation
    └── install/finalize/all.sh   # Summary
```

Each module's `all.sh` orchestrates its sub-scripts via `run_script()`:
```bash
# Example: install/openclaw/all.sh
run_script "$MONOCLAW_INSTALL/openclaw/nodejs.sh"
run_script "$MONOCLAW_INSTALL/openclaw/install.sh"
run_script "$MONOCLAW_INSTALL/openclaw/security.sh"  # Config before service
run_script "$MONOCLAW_INSTALL/openclaw/systemd.sh"   # Start service after config
run_script "$MONOCLAW_INSTALL/openclaw/tailscale.sh"
```

### Key Environment Variables

Set by `install.sh` and available to all modules:
- `MONOCLAW_PATH` - Repository root
- `MONOCLAW_INSTALL` - Path to `install/` directory
- `MONOCLAW_TEMPLATES` - Path to `templates/` directory

Set by `install/config/all.sh` from user prompts:
- `MONOCLAW_PRIMARY_USER` - Admin SSH user
- `MONOCLAW_SSH_PORT` - Custom SSH port
- `MONOCLAW_PRIMARY_USER_PASS` - Password for sudo (strongly recommended to avoid lockout)
- `MONOCLAW_SERVICE_USER` - OpenClaw service user (default: openclaw)

### Management Scripts Created on Target VPS

The `install/scripts/` modules generate these scripts in `/usr/local/vps-scripts/` (symlinked to `/usr/local/bin/`):
- `monoclaw-config` - Configuration management
- `monoclaw-status` - Service status and dashboard URL
- `monoclaw-logs` - Log viewer
- `monoclaw-security` - Security audit wrapper
- `monoclaw-update` - Update OpenClaw
- `monoclaw-tailscale` - Tailscale management

### Directory Structure on Target VPS

```
/var/lib/openclaw/           # OpenClaw service home
├── .openclaw/               # OpenClaw config directory
│   └── openclaw.json        # Main configuration
/etc/monoclaw/               # MonoClaw persistent config
├── primary-user             # Primary admin username
├── service-user             # Service username
├── auth-token               # Gateway auth token (mode 600)
└── tailscale-ip             # Tailscale IP address
/usr/local/vps-scripts/      # Management scripts
```

## Key Technical Details

- OpenClaw runs as dedicated `openclaw` system user (no shell, home at /var/lib/openclaw)
- Default permissions: `~/.openclaw/` mode 700, config files mode 600
- OpenClaw binds to loopback only (127.0.0.1:18789) for security
- Dashboard access via Tailscale Serve (WireGuard encrypted)
- Gateway authentication token auto-generated and stored in `/etc/monoclaw/auth-token`
- Systemd service includes security hardening (NoNewPrivileges, ProtectSystem, PrivateTmp)
- Only SSH port opened in firewall (Tailscale uses outbound connections)

## Security Implementation

Based on OpenClaw security documentation (https://docs.openclaw.ai/gateway/security):

1. **Loopback binding** - OpenClaw never exposed directly to network
2. **Token authentication** - Gateway requires auth token
3. **Dedicated service user** - Minimal privileges, no shell
4. **File permissions** - Strict mode 700/600 on config
5. **Tailscale Serve** - Dashboard only accessible via encrypted tailnet
6. **Defense in depth** - Multiple security layers

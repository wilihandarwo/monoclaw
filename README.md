# MonoClaw - OpenClaw AI Assistant VPS Installer

This script automates the setup of a production-ready VPS for hosting [OpenClaw](https://docs.openclaw.ai/), an AI Assistant gateway that bridges WhatsApp, Telegram, Discord, and iMessage to AI coding agents.

It handles server hardening, Node.js installation, OpenClaw setup, and secure dashboard access via Tailscale Serve.

Designed for **a fresh Ubuntu 24.04 VPS**.

## Prerequisites

1. **Fresh VPS**
   - Ubuntu 24.04 (64-bit)
   - Public IP address
   - Minimum 2GB RAM recommended

2. **Root SSH access**
   - You must be able to SSH as `root` using an SSH key
   - Password authentication will be disabled by the installer

3. **Tailscale account**
   - Create a free account at [tailscale.com](https://tailscale.com/)
   - You'll authenticate during installation

4. **Anthropic API Key** (for OpenClaw)
   - Required for the AI agent functionality
   - Get one at [console.anthropic.com](https://console.anthropic.com/)

## Quick Start

```bash
# SSH into your VPS as root
ssh root@your_server_ip

# Clone the installer
git clone https://github.com/wilihandarwo/monoclaw.git
cd monoclaw

# Run the installer
sudo bash install.sh
```

> **Important:** When prompted for a password during installation, **always set one**. This password is used for `sudo` access and VPS console access. Without it, you can be locked out of administrative tasks.

### Installation Options

```bash
# Interactive installation (default)
sudo bash install.sh

# Use a configuration file (skip some prompts)
sudo bash install.sh --config monoclaw.conf

# Show help
sudo bash install.sh --help
```

### Configuration File Format

For faster installation, create a config file:

```bash
# monoclaw.conf
PRIMARY_USER=admin
SSH_PORT=2222
```

## What Gets Installed

### Server Hardening
- Custom SSH port with key-only authentication
- Root SSH login disabled
- UFW firewall (SSH port only)
- fail2ban for SSH brute-force protection
- Unattended security upgrades
- Idle session termination

### OpenClaw Stack
- Node.js 22 LTS
- OpenClaw (via npm)
- Systemd service with security hardening
- Gateway authentication token

### Secure Dashboard Access
- OpenClaw binds to loopback only (127.0.0.1:18789)
- Tailscale Serve for secure remote access
- Automatic HTTPS via Tailscale

## Accessing the Dashboard

### Via Tailscale (Recommended)

After installation, your dashboard is accessible from any device on your Tailscale network:

```
https://<hostname>.<tailnet>.ts.net/
```

Find your exact URL with:
```bash
sudo monoclaw-tailscale url
```

### Via SSH Tunnel (Backup Method)

```bash
# Create SSH tunnel
ssh -L 18789:127.0.0.1:18789 PRIMARY_USER@your_server_ip -p SSH_PORT

# Then open in browser
http://127.0.0.1:18789/
```

## Management Commands

All commands should be run with `sudo`:

| Command | Description |
|---------|-------------|
| `monoclaw-status` | Check service status and dashboard URL |
| `monoclaw-logs` | View OpenClaw logs |
| `monoclaw-logs -f` | Follow logs in real-time |
| `monoclaw-config` | Manage configuration |
| `monoclaw-config --show` | Show current configuration |
| `monoclaw-config --token` | Show gateway auth token |
| `monoclaw-security` | Run security audit |
| `monoclaw-update` | Update OpenClaw to latest version |
| `monoclaw-tailscale url` | Show Tailscale dashboard URL |

## Service Control

```bash
# Check service status
sudo systemctl status openclaw

# Restart service
sudo systemctl restart openclaw

# Stop service
sudo systemctl stop openclaw

# View logs
sudo journalctl -u openclaw -f
```

## Setting Up Channels

After installation, configure WhatsApp, Telegram, or other channels:

```bash
# Login to channels (shows QR code for WhatsApp)
sudo -u openclaw HOME=/var/lib/openclaw openclaw channels login
```

## Security Features

MonoClaw implements multiple layers of security based on [OpenClaw security best practices](https://docs.openclaw.ai/gateway/security):

### Server Level
- SSH key-only authentication, custom port, disabled root login
- UFW firewall with minimal open ports (SSH only)
- fail2ban for brute-force protection
- Unattended security updates

### OpenClaw Level
- Dedicated service user (`openclaw`) with no shell access
- Loopback binding only (127.0.0.1:18789)
- Gateway authentication token required
- File permissions: `~/.openclaw/` mode 700, config mode 600
- Systemd hardening: NoNewPrivileges, ProtectSystem, PrivateTmp

### Network Level
- Dashboard only accessible via Tailscale (WireGuard encryption)
- No HTTP/HTTPS ports opened on firewall
- Tailscale uses outbound connections only

### Defense in Depth
```
Internet → Firewall (SSH only) → Tailscale → OpenClaw (loopback + token auth)
```

## Directory Structure

```
/var/lib/openclaw/           # OpenClaw service home
├── .openclaw/               # OpenClaw config directory (mode 700)
│   └── openclaw.json        # Main configuration (mode 600)
/etc/monoclaw/               # MonoClaw persistent config (mode 700)
├── primary-user             # Primary admin username
├── service-user             # OpenClaw service username
├── auth-token               # Gateway auth token (mode 600)
└── tailscale-ip             # Tailscale IP address
/usr/local/vps-scripts/      # Management scripts
```

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u openclaw -n 100

# Check configuration
sudo monoclaw-config --show

# Restart service
sudo systemctl restart openclaw
```

### Service shows "running" but dashboard not accessible

```bash
# Check if port is actually listening
ss -tlnp | grep 18789

# If empty, the gateway isn't binding to the port
# Try running manually to see errors
sudo -u openclaw HOME=/var/lib/openclaw openclaw gateway --port 18789

# Check if config file exists
ls -la /var/lib/openclaw/.openclaw/

# View config
sudo cat /var/lib/openclaw/.openclaw/openclaw.json
```

### Can't access dashboard via Tailscale

```bash
# Check Tailscale status
sudo tailscale status

# Check Tailscale Serve status
sudo tailscale serve status

# Re-setup Tailscale Serve
sudo monoclaw-tailscale serve-setup
```

### Forgot gateway token

```bash
sudo cat /etc/monoclaw/auth-token
```

### Regenerate gateway token

```bash
sudo monoclaw-config --token-regenerate
```

## Updating OpenClaw

```bash
sudo monoclaw-update
```

This will:
1. Stop the OpenClaw service
2. Update via npm
3. Restart the service
4. Show the new version

## Uninstalling

To remove MonoClaw:

```bash
# Stop and disable service
sudo systemctl stop openclaw
sudo systemctl disable openclaw
sudo rm /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload

# Remove OpenClaw
sudo npm uninstall -g openclaw

# Remove service user and data
sudo userdel -r openclaw

# Remove configuration
sudo rm -rf /etc/monoclaw

# Remove management scripts
sudo rm -f /usr/local/bin/monoclaw-*
sudo rm -rf /usr/local/vps-scripts

# Optionally remove Tailscale
sudo tailscale down
sudo apt remove tailscale
```

## License

MIT

## Documentation

- [OpenClaw Documentation](https://docs.openclaw.ai/)
- [OpenClaw Security Guide](https://docs.openclaw.ai/gateway/security)
- [Tailscale Documentation](https://tailscale.com/kb/)

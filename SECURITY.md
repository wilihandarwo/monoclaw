# Security Practices

MonoClaw implements a defense-in-depth security architecture with multiple protective layers. This document details all security measures configured during installation.

## Security Architecture

```
                        Internet
                            |
                    [Firewall: UFW]
                    Only SSH port open
                            |
                    +-------+-------+
                    |               |
              [SSH Server]    [Tailscale]
              Key-only auth   WireGuard VPN
              fail2ban        Outbound only
                    |               |
              [Primary User]        |
              Restricted sudo       |
                    |               |
                    +-------+-------+
                            |
                    [Loopback Only]
                    127.0.0.1:18789
                            |
                    [OpenClaw Gateway]
                    Token authentication
                    Systemd hardened
                    Dedicated user
```

## Network Security

### Firewall (UFW)

Only the custom SSH port is opened to external traffic. OpenClaw is never directly exposed to the network.

**Implementation:** `install/system/firewall.sh`

```bash
ufw --force enable
ufw allow ${MONOCLAW_SSH_PORT}/tcp
# HTTP/HTTPS ports intentionally NOT opened
```

### Loopback Binding

OpenClaw binds exclusively to the loopback interface, preventing any direct network access.

**Implementation:** `install/openclaw/security.sh`

```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "trustedProxies": ["127.0.0.1", "::1"]
  }
}
```

### Tailscale Serve

Dashboard access is provided through Tailscale Serve, which creates a WireGuard-encrypted tunnel.

**Implementation:** `install/openclaw/tailscale.sh`

- Routes `127.0.0.1:18789` through encrypted Tailscale connection
- Accessible via `https://<hostname>.<tailnet>.ts.net`
- No inbound ports required (outbound-only connection)
- End-to-end WireGuard encryption

## SSH Hardening

**Implementation:** `install/system/ssh.sh`
**Configuration:** `/etc/ssh/sshd_config.d/99-custom.conf`

### Authentication

| Setting | Value | Purpose |
|---------|-------|---------|
| `AuthenticationMethods` | `publickey` | Only public key authentication allowed |
| `PasswordAuthentication` | `no` | Password login disabled |
| `PubkeyAuthentication` | `yes` | Public key auth enabled |
| `ChallengeResponseAuthentication` | `no` | Challenge-response disabled |
| `PermitRootLogin` | `no` | Root cannot login via SSH |
| `AllowUsers` | `${PRIMARY_USER}` | Only the primary user can connect |

### Connection Limits

| Setting | Value | Purpose |
|---------|-------|---------|
| `MaxAuthTries` | `3` | Maximum authentication attempts per connection |
| `LoginGraceTime` | `20` | Seconds before unauthenticated connection is dropped |
| `ClientAliveInterval` | `300` | Keepalive sent every 5 minutes |
| `ClientAliveCountMax` | `2` | Disconnect after 2 missed keepalives (10 min idle max) |

### Forwarding Restrictions

| Setting | Value | Purpose |
|---------|-------|---------|
| `AllowTcpForwarding` | `yes` | Allow SSH tunnels for backup dashboard access |
| `AllowAgentForwarding` | `no` | Prevent SSH agent hijacking |
| `X11Forwarding` | `no` | No graphical forwarding |

### Custom Port

SSH runs on a user-specified port (not 22) to avoid automated scanning.

## User Isolation

**Implementation:** `install/system/user.sh`

### Service User

OpenClaw runs as a dedicated system user with minimal privileges:

```bash
useradd --system \
        --home-dir /var/lib/openclaw \
        --shell /usr/sbin/nologin \
        --create-home \
        openclaw
```

| Property | Value | Purpose |
|----------|-------|---------|
| Username | `openclaw` | Dedicated service account |
| Home | `/var/lib/openclaw` | Isolated from `/home` |
| Shell | `/usr/sbin/nologin` | Cannot login interactively |
| UID | System (< 1000) | Identified as system user |

### Restricted Sudo

The primary user has passwordless sudo only for specific management commands:

**Configuration:** `/etc/sudoers.d/010_${PRIMARY_USER}-limited`

```
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-config
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-status
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-logs
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-security
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-update
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/monoclaw-tailscale
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart openclaw
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start openclaw
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop openclaw
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status openclaw
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/bin/tailscale status
${PRIMARY_USER} ALL=(ALL) NOPASSWD: /usr/bin/tailscale serve *
```

## Authentication & Secrets

**Implementation:** `install/openclaw/security.sh`

### Gateway Token

A 256-bit cryptographically secure token protects the OpenClaw gateway:

```bash
openssl rand -hex 32  # 64 hex characters = 256 bits
```

**Storage Locations:**
- `/etc/monoclaw/auth-token` (mode 600)
- `/var/lib/openclaw/.openclaw/openclaw.json` (mode 600)

**Configuration:**

```json
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "<256-bit-hex-token>"
    }
  }
}
```

### Token Regeneration

Tokens can be regenerated using the management script:

```bash
monoclaw-config regenerate-token
```

This generates a new token, updates both storage locations, and restarts the service.

## Intrusion Prevention (fail2ban)

**Implementation:** `install/security/fail2ban.sh`
**Configuration:** `/etc/fail2ban/jail.d/sshd.local`

### SSH Jail

```ini
[sshd]
enabled  = true
port     = ${MONOCLAW_SSH_PORT}
logpath  = /var/log/auth.log
maxretry = 5
findtime = 600
bantime  = 3600
```

| Setting | Value | Effect |
|---------|-------|--------|
| `maxretry` | 5 | Failed attempts before ban |
| `findtime` | 600 | 10-minute window for counting failures |
| `bantime` | 3600 | 1-hour ban duration |

An IP address making 5 failed SSH login attempts within 10 minutes is banned for 1 hour.

## Systemd Service Hardening

**Implementation:** `install/openclaw/systemd.sh`
**Template:** `templates/openclaw.service`
**Configuration:** `/etc/systemd/system/openclaw.service`

### Security Directives

```ini
[Service]
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ReadWritePaths=/var/lib/openclaw
ReadWritePaths=/tmp/openclaw
```

| Directive | Effect |
|-----------|--------|
| `NoNewPrivileges=yes` | Process cannot gain new privileges (blocks setuid/setgid) |
| `ProtectSystem=strict` | Root filesystem is read-only |
| `ProtectHome=read-only` | `/home` and `/root` are read-only |
| `PrivateTmp=yes` | Private `/tmp` namespace (isolated from other processes) |
| `ProtectKernelTunables=yes` | Cannot modify kernel parameters via `/proc` or `/sys` |
| `ProtectKernelModules=yes` | Cannot load kernel modules |
| `ProtectControlGroups=yes` | Cannot modify cgroups |
| `ReadWritePaths` | Explicit write-allowed directories |

### Resource Limits

```ini
MemoryMax=2G
TasksMax=100
```

### Container/VPS Compatibility

The installer detects container environments where namespace isolation may not be supported:

```bash
systemd-detect-virt --container
```

If running in a container without namespace support, security hardening gracefully degrades to a basic configuration while preserving user isolation.

## File Permissions

**Implementation:** `install/finalize/directories.sh`

### Permission Matrix

| Path | Mode | Owner | Purpose |
|------|------|-------|---------|
| `/etc/monoclaw/` | 700 | root:root | MonoClaw configuration directory |
| `/etc/monoclaw/auth-token` | 600 | root:root | Gateway authentication token |
| `/var/lib/openclaw/` | 700 | openclaw:openclaw | Service home directory |
| `/var/lib/openclaw/.openclaw/` | 700 | openclaw:openclaw | OpenClaw config directory |
| `/var/lib/openclaw/.openclaw/openclaw.json` | 600 | openclaw:openclaw | Main configuration file |
| `/usr/local/vps-scripts/` | 755 | root:root | Management scripts |
| `~/.ssh/` | 700 | user:user | SSH directory |
| `~/.ssh/authorized_keys` | 600 | user:user | SSH public keys |

## Automatic Updates

**Implementation:** `install/system/packages.sh`

### Unattended Upgrades

Security updates are automatically applied via `unattended-upgrades`:

**Configuration:** `/etc/apt/apt.conf.d/50unattended-upgrades`

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
```

**Schedule:** `/etc/apt/apt.conf.d/20auto-upgrades`

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Only security packages from the `-security` repository are automatically updated. Feature updates require manual intervention.

## Security Audit

**Script:** `/usr/local/bin/monoclaw-security`
**Implementation:** `install/scripts/monoclaw-security.sh`

Run a comprehensive security audit:

```bash
monoclaw-security
```

This checks:
- OpenClaw security configuration (`openclaw security audit`)
- File and directory permissions
- Firewall status (`ufw status`)
- fail2ban SSH jail status
- SSH configuration
- Tailscale connectivity

## Security Best Practices for Operators

### Token Rotation

Regenerate the gateway token periodically:

```bash
monoclaw-config regenerate-token
```

### SSH Key Management

- Use strong key types (Ed25519 or RSA 4096-bit)
- Protect private keys with passphrases
- Rotate keys if compromise is suspected
- Remove old keys from `authorized_keys` when no longer needed

### Monitoring

- Review `/var/log/auth.log` for failed login attempts
- Check fail2ban status: `fail2ban-client status sshd`
- Monitor OpenClaw logs: `monoclaw-logs`
- Run periodic security audits: `monoclaw-security`

### Backup Considerations

When backing up, include:
- `/etc/monoclaw/` (contains auth token)
- `/var/lib/openclaw/.openclaw/` (OpenClaw configuration)
- `/home/${PRIMARY_USER}/.ssh/authorized_keys` (SSH access)

Ensure backups are encrypted and stored securely.

### Tailscale Security

- Keep Tailscale authenticated to your tailnet
- Use Tailscale ACLs to restrict which devices can access the dashboard
- Enable MagicDNS for easier, verified access

## References

- [OpenClaw Gateway Security](https://docs.openclaw.ai/gateway/security)
- [Ubuntu Security Guide](https://ubuntu.com/security)
- [fail2ban Documentation](https://www.fail2ban.org/)
- [systemd Security Features](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Sandboxing)
- [Tailscale Security Model](https://tailscale.com/security)

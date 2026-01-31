#!/bin/bash
# MonoClaw Installer - User Creation
# Creates primary user and OpenClaw service user

log_step "Creating primary user: ${MONOCLAW_PRIMARY_USER}"

# Check if user already exists
if id "${MONOCLAW_PRIMARY_USER}" &>/dev/null; then
    log_info "User ${MONOCLAW_PRIMARY_USER} already exists, skipping creation"
else
    # Create user without password, expecting SSH key usage
    adduser --disabled-password --gecos "" ${MONOCLAW_PRIMARY_USER}
    usermod -aG sudo ${MONOCLAW_PRIMARY_USER}
fi

# If a password was supplied, set it now (for sudo/console use only).
# SSH password logins remain disabled by sshd_config (PasswordAuthentication no).
if [ -n "${MONOCLAW_PRIMARY_USER_PASS:-}" ]; then
    echo "${MONOCLAW_PRIMARY_USER}:${MONOCLAW_PRIMARY_USER_PASS}" | chpasswd
    log_info "Local password set for ${MONOCLAW_PRIMARY_USER} (SSH remains key-only)."
fi

log_step "Creating OpenClaw service user: ${MONOCLAW_SERVICE_USER}"

# Check if service user already exists
if id "${MONOCLAW_SERVICE_USER}" &>/dev/null; then
    log_info "Service user ${MONOCLAW_SERVICE_USER} already exists, skipping creation"
else
    # Create dedicated service user for OpenClaw daemon
    # - System user (no login shell, no home directory in /home)
    # - Home directory at /var/lib/openclaw for OpenClaw data
    useradd --system \
        --shell /usr/sbin/nologin \
        --home-dir /var/lib/openclaw \
        --create-home \
        ${MONOCLAW_SERVICE_USER}
fi

# Ensure proper permissions on service user home (always run this)
mkdir -p /var/lib/openclaw
chmod 700 /var/lib/openclaw
chown ${MONOCLAW_SERVICE_USER}:${MONOCLAW_SERVICE_USER} /var/lib/openclaw

log_step "Configuring restricted sudo for ${MONOCLAW_PRIMARY_USER}..."

# Allow PRIMARY_USER to run only specific management commands without a password.
# For any other sudo usage, they must authenticate normally via membership in the sudo group.
SYSTEMCTL_PATH="$(command -v systemctl || echo /usr/bin/systemctl)"
TAILSCALE_PATH="$(command -v tailscale || echo /usr/bin/tailscale)"

cat > /etc/sudoers.d/010_${MONOCLAW_PRIMARY_USER}-limited <<EOF
${MONOCLAW_PRIMARY_USER} ALL=(root) NOPASSWD: /usr/local/bin/monoclaw-config, \\
    /usr/local/bin/monoclaw-status, \\
    /usr/local/bin/monoclaw-logs, \\
    /usr/local/bin/monoclaw-security, \\
    /usr/local/bin/monoclaw-update, \\
    /usr/local/bin/monoclaw-tailscale, \\
    ${SYSTEMCTL_PATH} restart openclaw, \\
    ${SYSTEMCTL_PATH} start openclaw, \\
    ${SYSTEMCTL_PATH} stop openclaw, \\
    ${SYSTEMCTL_PATH} status openclaw, \\
    ${TAILSCALE_PATH} status, \\
    ${TAILSCALE_PATH} serve *
EOF
chmod 440 /etc/sudoers.d/010_${MONOCLAW_PRIMARY_USER}-limited

# Validate sudoers syntax to avoid locking out sudo
visudo -cf /etc/sudoers.d/010_${MONOCLAW_PRIMARY_USER}-limited

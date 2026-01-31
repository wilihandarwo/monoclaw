#!/bin/bash
# MonoClaw Installer - SSH Hardening
# Configures secure SSH settings and copies keys

log_step "Setting up SSH key for ${MONOCLAW_PRIMARY_USER}..."

if [ ! -f "/root/.ssh/authorized_keys" ] || [ ! -s "/root/.ssh/authorized_keys" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! ERROR: /root/.ssh/authorized_keys is empty or does not exist.          !!!"
    echo "!!! The new user '${MONOCLAW_PRIMARY_USER}' will not be able to log in with an SSH key. !!!"
    echo "!!! Please add your public SSH key to /root/.ssh/authorized_keys and rerun. !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi

print_divider
echo "INFO: Installing the following public key from /root/.ssh/authorized_keys for '${MONOCLAW_PRIMARY_USER}':"
echo ""
cat "/root/.ssh/authorized_keys"
echo ""
echo "Please verify that your local machine is using the corresponding private key."
print_divider
sleep 5 # Give user time to read

# Copy SSH keys from root
mkdir -p /home/${MONOCLAW_PRIMARY_USER}/.ssh
rsync --archive --chown=${MONOCLAW_PRIMARY_USER}:${MONOCLAW_PRIMARY_USER} /root/.ssh/ /home/${MONOCLAW_PRIMARY_USER}/.ssh/
chmod 700 /home/${MONOCLAW_PRIMARY_USER}/.ssh
chmod 600 /home/${MONOCLAW_PRIMARY_USER}/.ssh/authorized_keys

print_divider
echo "INFO: Verifying final ownership and permissions for SSH files:"
ls -ld /home/${MONOCLAW_PRIMARY_USER} /home/${MONOCLAW_PRIMARY_USER}/.ssh /home/${MONOCLAW_PRIMARY_USER}/.ssh/authorized_keys
print_divider
sleep 2

log_step "Securing SSH with a dedicated configuration file..."

# Create a custom SSH config file to override defaults.
cat > /etc/ssh/sshd_config.d/99-custom.conf <<EOF
# --- Custom SSH Configuration from MonoClaw Installer ---
# Set the listening port
Port ${MONOCLAW_SSH_PORT}

# Disable root login
PermitRootLogin no

# Enforce public key authentication ONLY
AuthenticationMethods publickey
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# Harden authentication
UsePAM yes
MaxAuthTries 3
LoginGraceTime 20

# Allow TCP forwarding for SSH tunnels (backup access to OpenClaw dashboard)
AllowTcpForwarding yes
AllowAgentForwarding no
X11Forwarding no
PrintMotd no

# Terminate idle sessions to prevent hijacking
ClientAliveInterval 300
ClientAliveCountMax 2

# Only allow the primary user to log in
AllowUsers ${MONOCLAW_PRIMARY_USER}
EOF

# Test the new configuration
log_step "Validating SSH configuration..."

# Ensure privilege separation directory exists
if [ ! -d /run/sshd ]; then
    mkdir -p /run/sshd
    chmod 755 /run/sshd
fi

sshd -t
if [ $? -ne 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! ERROR: sshd configuration is invalid. Removing custom config. !!!"
    echo "!!! SSH server may not restart correctly.                       !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    rm /etc/ssh/sshd_config.d/99-custom.conf
    exit 1
fi

# Restart SSH service to apply changes
log_step "Restarting SSH service..."
systemctl restart ssh

# Verify that sshd is listening on the custom port
if command -v ss >/dev/null 2>&1; then
    if ss -tulpn 2>/dev/null | grep -q ":${MONOCLAW_SSH_PORT} "; then
        log_info "Verified sshd is listening on port ${MONOCLAW_SSH_PORT}."
        log_step "Removing default SSH port 22 from firewall..."
        ufw delete allow 22/tcp >/dev/null 2>&1 || true
    else
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!! WARNING: sshd is not listening on port ${MONOCLAW_SSH_PORT}.       !!!"
        echo "!!! Keeping firewall on port 22/tcp as a safety fallback.    !!!"
        echo "!!! Please investigate sshd logs and configuration.          !!!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        ufw allow 22/tcp
    fi
else
    log_warning "Command 'ss' not found; skipping verification of sshd port."
    log_info "For safety, leaving port 22/tcp firewall rule untouched."
fi

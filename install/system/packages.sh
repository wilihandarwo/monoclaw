#!/bin/bash
# MonoClaw Installer - System Packages
# Updates system and installs base packages

log_step "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

log_step "Installing base packages..."
apt install -y ufw unattended-upgrades fail2ban logrotate curl ca-certificates gnupg

log_step "Configuring unattended upgrades..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Package-Blacklist {
    //
};
Unattended-Upgrade::DevRelease "auto";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

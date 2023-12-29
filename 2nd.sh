#!/bin/bash

# Function to prompt user to continue
function prompt_continue {
    read -p "Press Enter to continue..."
}

# Install git
echo "Installing git..."
prompt_continue
apt update && apt install git -y

# Get the correct download link for the latest version
echo "Downloading Gitea..."
prompt_continue
wget https://dl.gitea.com/gitea/1.20.3/gitea-1.20.3-linux-amd64

# Move the binary to bin
echo "Moving Gitea binary..."
prompt_continue
mv gitea* /usr/local/bin/gitea

# Make executable
echo "Setting Gitea as executable..."
prompt_continue
chmod +x /usr/local/bin/gitea

# Ensure it works
echo "Checking Gitea version..."
prompt_continue
gitea --version

# Create the user/group for Gitea to operate as
echo "Creating user/group for Gitea..."
prompt_continue
adduser --system --group --disabled-password --home /etc/gitea gitea

# Config directory was created by adduser
echo "Creating directory structure..."
prompt_continue
mkdir -p /var/lib/gitea/{custom,data,log}
chown -R gitea:gitea /var/lib/gitea/
chmod -R 750 /var/lib/gitea/
chown root:gitea /etc/gitea
chmod 770 /etc/gitea

# Systemd Service (/etc/systemd/system/gitea.service)
echo "Configuring Systemd Service..."
prompt_continue
cat <<EOF > /etc/systemd/system/gitea.service
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=notify
User=gitea
Group=gitea
WorkingDirectory=/var/lib/gitea
RuntimeDirectory=gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=gitea HOME=/var/lib/gitea/data GITEA_WORK_DIR=/var/lib/gitea
WatchdogSec=30s
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Restart daemon and enable Gitea service
echo "Restarting Systemd daemon and enabling Gitea service..."
prompt_continue
systemctl daemon-reload
systemctl enable --now gitea

# Configure HTTPS (Self-Signed)
echo "Configuring HTTPS (Self-Signed)..."
prompt_continue
cd /etc/gitea
gitea cert --host gitea.palnet.net
chown root:gitea cert.pem key.pem
chmod 640 cert.pem key.pem
systemctl restart gitea

# Configure HTTPS (Let’s Encrypt)
echo "Configuring HTTPS (Let’s Encrypt)..."
prompt_continue
cat <<EOF >> /etc/gitea/app.ini
[server]
PROTOCOL=https
REDIRECT_OTHER_PORT=true
ENABLE_ACME=true
ACME_ACCEPTTOS=true
ACME_DIRECTORY=https
ACME_URL=https://acme-staging-v02.api.letsencrypt.org/directory
ACME_EMAIL=adventure@apalrd.net
SSH_DOMAIN=gitea.palnet.net
DOMAIN=gitea.palnet.net
HTTP_PORT=443
ROOT_URL=https://gitea.palnet.net/
APP_DATA_PATH=/var/lib/gitea/data
DISABLE_SSH=false
EOF

# Restart Gitea
echo "Restarting Gitea..."
prompt_continue
systemctl restart gitea

echo "Gitea setup completed successfully!"

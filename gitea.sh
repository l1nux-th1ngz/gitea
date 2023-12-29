#!/bin/bash

# Install git
echo "Updating packages..."
apt update
echo "Installing git..."
apt install git -y

# Get the correct download link for the latest version
echo "Downloading Gitea..."
wget https://dl.gitea.com/gitea/1.20.3/gitea-1.20.3-linux-amd64

# Move the binary to bin
echo "Moving Gitea binary to /usr/local/bin..."
mv gitea* /usr/local/bin/gitea

# Make executable
echo "Making Gitea executable..."
chmod +x /usr/local/bin/gitea

# Ensure it works
echo "Checking Gitea version..."
gitea --version

# Create the user/group for gitea to operate as
echo "Creating Gitea user and group..."
adduser --system --group --disabled-password --home /etc/gitea gitea

# Config directory was created by adduser
# Create directory structure (mountpoint should be /var/lib/gitea)
echo "Creating Gitea directories..."
mkdir -p /var/lib/gitea/{custom,data,log}
chown -R gitea:gitea /var/lib/gitea/
chmod -R 750 /var/lib/gitea/
chown root:gitea /etc/gitea
chmod 770 /etc/gitea

# After that, we need a Systemd Service: (/etc/systemd/system/gitea.service)
echo "Creating Gitea service file..."
cat << EOF > /etc/systemd/system/gitea.service
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
# Uncomment the next line if you have repos with lots of files and get a HTTP 500 error because of that
# LimitNOFILE=524288:524288
RestartSec=2s
Type=notify
User=gitea
Group=gitea
#The mount point we added to the container
WorkingDirectory=/var/lib/gitea
#Create directory in /run
RuntimeDirectory=gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=gitea HOME=/var/lib/gitea/data GITEA_WORK_DIR=/var/lib/gitea
WatchdogSec=30s
#Capabilities to bind to low-numbered ports
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Then run it:
echo "Reloading systemd daemon and starting Gitea service..."
systemctl daemon-reload
systemctl enable --now gitea

# Configure HTTPS (Self-Signed)
echo "Configuring Gitea for HTTPS with self-signed certificate..."
# Navigate to the gitea directory
cd /etc/gitea
# Sign cert
gitea cert --host teapot.apalrd.net
# Give gitea user read permissions
chown root:gitea cert.pem key.pem
chmod 640 cert.pem key.pem
# Restart gitea
systemctl restart gitea

# To temporarily ignore certificates in Git (for testing), you can use the option -c http.sslVerify=false to git.

# Configure HTTPS (Let’s Encrypt)
echo "Configuring Gitea for HTTPS with Let's Encrypt..."
# Edit /etc/gitea/app.ini with the necessary changes
sed -i 's/^PROTOCOL=.*/PROTOCOL=https/' /etc/gitea/app.ini
sed -i 's/^REDIRECT_OTHER_PORT=.*/REDIRECT_OTHER_PORT=true/' /etc/gitea/app.ini
sed -i 's/^ENABLE_ACME=.*/ENABLE_ACME=true/' /etc/gitea/app.ini
sed -i 's/^ACME_ACCEPTTOS=.*/ACME_ACCEPTTOS=true/' /etc/gitea/app.ini
sed -i 's/^ACME_DIRECTORY=.*/ACME_DIRECTORY=https/' /etc/gitea/app.ini
sed -i 's/^ACME_URL=.*/ACME_URL=https:\/\/acme-staging-v02.api.letsencrypt.org\/directory/' /etc/gitea/app.ini
sed -i 's/^ACME_EMAIL=.*/ACME_EMAIL=adventure@apalrd.net/' /etc/gitea/app.ini
sed -i 's/^HTTP_PORT=.*/HTTP_PORT=443/' /etc/gitea/app.ini

# Restart gitea
systemctl restart gitea

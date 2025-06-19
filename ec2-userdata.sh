#!/bin/bash

# EC2 User Data Script for Email Analytics Dashboard
# This script runs on instance startup to configure the environment

# Update system
yum update -y

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Git, PostgreSQL client, and other dependencies
yum install -y git postgresql15 nginx

# Install PM2 for process management
npm install -g pm2

# Create application directory
mkdir -p /opt/email-analytics
cd /opt/email-analytics

# Clone the application (we'll copy files via deployment)
# For now, create placeholder structure
mkdir -p server client shared

# Create systemd service file
cat > /etc/systemd/system/email-analytics.service << 'EOF'
[Unit]
Description=Email Analytics Dashboard
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/email-analytics
Environment=NODE_ENV=production
Environment=PORT=5000
ExecStart=/usr/bin/npm run start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/email-analytics

# Configure Nginx as reverse proxy
cat > /etc/nginx/conf.d/email-analytics.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Remove default Nginx config
rm -f /etc/nginx/conf.d/default.conf

# Enable and start services
systemctl enable nginx
systemctl start nginx
systemctl enable email-analytics

# Log completion
echo "EC2 setup completed at $(date)" >> /var/log/email-analytics-setup.log
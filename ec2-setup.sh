#!/bin/bash

# Email Analytics Dashboard - EC2 Setup Script
# Run this script on the EC2 instance to deploy the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up Email Analytics Dashboard on EC2..."

# Check if running as ec2-user
if [ "$USER" != "ec2-user" ]; then
    print_error "This script should be run as ec2-user"
    exit 1
fi

# Update system
print_status "Updating system packages..."
sudo yum update -y

# Install Node.js 18
print_status "Installing Node.js 18..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install Git and other dependencies
print_status "Installing dependencies..."
sudo yum install -y git postgresql15 nginx

# Install PM2 globally
print_status "Installing PM2..."
sudo npm install -g pm2

# Create application directory
print_status "Creating application directory..."
sudo mkdir -p /opt/email-analytics
sudo chown ec2-user:ec2-user /opt/email-analytics
cd /opt/email-analytics

# Copy application files (assuming they're uploaded to /tmp)
if [ -f "/tmp/email-analytics.tar.gz" ]; then
    print_status "Extracting application files..."
    tar -xzf /tmp/email-analytics.tar.gz
else
    print_warning "Application files not found. Please upload email-analytics.tar.gz to /tmp/"
    print_status "Creating placeholder package.json..."
    cat > package.json << 'EOF'
{
  "name": "email-analytics",
  "version": "1.0.0",
  "description": "Email Analytics Dashboard",
  "main": "server/index.js",
  "scripts": {
    "start": "NODE_ENV=production node server/index.js",
    "dev": "NODE_ENV=development tsx server/index.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "@neondatabase/serverless": "^0.9.0",
    "drizzle-orm": "^0.29.0"
  }
}
EOF
fi

# Install dependencies
if [ -f "package.json" ]; then
    print_status "Installing Node.js dependencies..."
    npm install --production
fi

# Set environment variables
print_status "Setting up environment..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
# Add your environment variables here:
# DATABASE_URL=your_database_url
# OPENAI_API_KEY=your_openai_key
# VITE_AZURE_CLIENT_ID=your_azure_client_id
# VITE_AZURE_TENANT_ID=your_azure_tenant_id
EOF

# Create PM2 ecosystem file
print_status "Creating PM2 configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'email-analytics',
    script: 'server/index.js',
    cwd: '/opt/email-analytics',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/var/log/email-analytics-error.log',
    out_file: '/var/log/email-analytics-out.log',
    log_file: '/var/log/email-analytics.log',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    autorestart: true,
    max_restarts: 10,
    restart_delay: 5000
  }]
};
EOF

# Configure Nginx
print_status "Configuring Nginx..."
sudo tee /etc/nginx/conf.d/email-analytics.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    
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
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://localhost:5000;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Remove default Nginx config
sudo rm -f /etc/nginx/conf.d/default.conf

# Test Nginx configuration
print_status "Testing Nginx configuration..."
sudo nginx -t

# Create log directories
sudo mkdir -p /var/log
sudo chown ec2-user:ec2-user /var/log/email-analytics*.log 2>/dev/null || true

# Enable and start Nginx
print_status "Starting Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# Start application with PM2
if [ -f "server/index.js" ] || [ -f "server/index.ts" ]; then
    print_status "Starting application with PM2..."
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup
else
    print_warning "Application entry point not found. Skipping PM2 startup."
fi

# Setup PM2 to start on boot
print_status "Configuring PM2 to start on boot..."
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user

print_status "Setup completed!"
print_status "Application should be available on port 80 (HTTP)"
print_status "Check application status: pm2 status"
print_status "View logs: pm2 logs email-analytics"
print_status "Restart application: pm2 restart email-analytics"
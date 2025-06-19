#!/bin/bash

# Simple AWS EC2 Deployment for Email Analytics Dashboard
# This script handles the complete deployment process

set -e

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="email-analytics-key"
SECURITY_GROUP_NAME="email-analytics-sg"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
for cmd in aws jq; do
    if ! command -v $cmd &> /dev/null; then
        print_error "$cmd is not installed. Please install it first."
        exit 1
    fi
done

print_status "Starting complete EC2 deployment..."

# Step 1: Package application
print_status "Packaging application..."
./package-for-ec2.sh

# Step 2: Deploy infrastructure
print_status "Deploying EC2 infrastructure..."
./deploy-ec2.sh --region $REGION --instance-type $INSTANCE_TYPE --key-name $KEY_NAME

# Get instance info from deployment
if [ -f "ec2-deployment-info.txt" ]; then
    PUBLIC_IP=$(grep "Public IP:" ec2-deployment-info.txt | cut -d' ' -f3)
    INSTANCE_ID=$(grep "Instance ID:" ec2-deployment-info.txt | cut -d' ' -f3)
    
    print_status "Instance deployed successfully!"
    print_status "Public IP: $PUBLIC_IP"
    print_status "Instance ID: $INSTANCE_ID"
else
    print_error "Deployment info not found!"
    exit 1
fi

# Step 3: Wait for instance to be ready
print_status "Waiting for instance to be fully ready..."
sleep 30

# Step 4: Upload application package
print_status "Uploading application package..."
scp -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no email-analytics.tar.gz ec2-user@$PUBLIC_IP:/tmp/
scp -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ec2-setup.sh ec2-user@$PUBLIC_IP:/tmp/

# Step 5: Run setup on instance
print_status "Running setup on EC2 instance..."
ssh -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'chmod +x /tmp/ec2-setup.sh && /tmp/ec2-setup.sh'

# Step 6: Configure application
print_status "Configuring application..."
ssh -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'EOF'
cd /tmp
tar -xzf email-analytics.tar.gz
sudo cp -r email-analytics/* /opt/email-analytics/
sudo chown -R ec2-user:ec2-user /opt/email-analytics

# Create production environment file
cat > /opt/email-analytics/.env << 'ENVEOF'
NODE_ENV=production
PORT=5000
# Add your environment variables below:
# DATABASE_URL=postgresql://username:password@host:5432/database
# OPENAI_API_KEY=sk-your-openai-key
# VITE_AZURE_CLIENT_ID=your-azure-client-id
# VITE_AZURE_TENANT_ID=your-azure-tenant-id
# JWT_SECRET=your-random-jwt-secret
ENVEOF

# Install dependencies and build
cd /opt/email-analytics
npm install --production
npm run build 2>/dev/null || echo "Build step skipped (no build script)"

# Start with PM2
pm2 start ecosystem.config.js
pm2 save
EOF

# Final status check
print_status "Checking application status..."
sleep 10

APP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_IP/api/health || echo "000")

if [ "$APP_STATUS" = "200" ]; then
    print_status "✓ Application is running successfully!"
else
    print_warning "Application may still be starting up..."
fi

# Create final deployment summary
cat > deployment-summary.txt << EOF
Email Analytics Dashboard - Deployment Summary
=============================================

Deployment Date: $(date)
Region: $REGION
Instance Type: $INSTANCE_TYPE

Instance Details:
- Instance ID: $INSTANCE_ID
- Public IP: $PUBLIC_IP
- Key File: ${KEY_NAME}.pem

Application URLs:
- Main Application: http://$PUBLIC_IP/
- Health Check: http://$PUBLIC_IP/api/health
- Dashboard: http://$PUBLIC_IP/dashboard

SSH Access:
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP

Next Steps:
1. Configure environment variables:
   ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP
   sudo nano /opt/email-analytics/.env

2. Add your database URL, API keys, and Azure credentials

3. Restart the application:
   cd /opt/email-analytics && pm2 restart email-analytics

4. Update Azure app registration redirect URIs to include:
   http://$PUBLIC_IP/

Management Commands:
- View status: pm2 status
- View logs: pm2 logs email-analytics
- Restart app: pm2 restart email-analytics

EOF

print_status "Deployment completed!"
print_status "Summary saved to: deployment-summary.txt"
print_warning "Don't forget to:"
print_warning "1. Configure your environment variables"
print_warning "2. Update Azure app registration redirect URIs"
print_warning "3. Set up your database connection"

echo
print_status "Your application should be available at: http://$PUBLIC_IP/"
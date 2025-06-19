#!/bin/bash

# Simple AWS EC2 Deployment for Email Analytics Dashboard
set -e

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="email-analytics"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2023

echo "🚀 Deploying Email Analytics Dashboard to AWS EC2..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install it first: https://aws.amazon.com/cli/"
    exit 1
fi

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
    echo "🔑 Creating key pair..."
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "✅ Key saved as ${KEY_NAME}.pem"
fi

# Create security group
echo "🛡️ Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name email-analytics \
    --description "Email Analytics Dashboard" \
    --region $REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups --group-names email-analytics --region $REGION --query 'SecurityGroups[0].GroupId' --output text)

# Add rules
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true

# Create user data script
cat > userdata.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y git

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install PM2
npm install -g pm2

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create simple Express server
cat > server.js << 'JSEOF'
const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 80;

app.use(express.json());
app.use(express.static('public'));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Serve app
app.get('*', (req, res) => {
  res.send(`
    <html>
      <head><title>Email Analytics Dashboard</title></head>
      <body style="font-family: Arial; margin: 40px; text-align: center;">
        <h1>🚀 Email Analytics Dashboard</h1>
        <p>Your application is running on EC2!</p>
        <p>Server time: ${new Date().toISOString()}</p>
        <a href="/health">Health Check</a>
      </body>
    </html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
JSEOF

# Create package.json
cat > package.json << 'JSONEOF'
{
  "name": "email-analytics",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
JSONEOF

# Install dependencies
npm install

# Start with PM2
pm2 start server.js --name email-analytics
pm2 startup
pm2 save

echo "✅ Application deployed and running on port 80"
EOF

# Launch instance
echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --region $REGION \
    --user-data file://userdata.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=email-analytics}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "⏳ Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# Cleanup
rm -f userdata.sh

echo "✅ Deployment completed!"
echo
echo "🌐 Your application is available at: http://$PUBLIC_IP"
echo "🔍 Health check: http://$PUBLIC_IP/health"
echo "📱 SSH access: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Key file: ${KEY_NAME}.pem"
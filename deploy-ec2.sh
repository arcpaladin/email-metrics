#!/bin/bash

# Email Analytics Dashboard - AWS EC2 Deployment Script
# This script sets up a simple EC2 deployment for the email analytics application

set -e

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2023
KEY_NAME="email-analytics-key"
SECURITY_GROUP_NAME="email-analytics-sg"
INSTANCE_NAME="email-analytics-server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --key-name)
            KEY_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --region REGION           AWS region (default: us-east-1)"
            echo "  --instance-type TYPE      EC2 instance type (default: t3.micro)"
            echo "  --key-name NAME           Key pair name (default: email-analytics-key)"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "Starting AWS EC2 deployment for Email Analytics Dashboard"
print_status "Region: $REGION"
print_status "Instance Type: $INSTANCE_TYPE"
print_status "Key Name: $KEY_NAME"

# Check if key pair exists, create if not
print_status "Checking if key pair exists..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &> /dev/null; then
    print_status "Key pair '$KEY_NAME' already exists"
else
    print_status "Creating key pair '$KEY_NAME'..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    print_status "Key pair created and saved to ${KEY_NAME}.pem"
fi

# Create security group
print_status "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Security group for Email Analytics Dashboard" \
    --region "$REGION" \
    --query 'GroupId' \
    --output text 2>/dev/null || aws ec2 describe-security-groups \
    --group-names "$SECURITY_GROUP_NAME" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

print_status "Security Group ID: $SECURITY_GROUP_ID"

# Add security group rules
print_status "Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 5000 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

# Launch EC2 instance
print_status "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --region "$REGION" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data file://ec2-userdata.sh \
    --query 'Instances[0].InstanceId' \
    --output text)

print_status "Instance ID: $INSTANCE_ID"

# Wait for instance to be running
print_status "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

print_status "Instance is running!"
print_status "Public IP: $PUBLIC_IP"

# Wait a bit for the user data script to run
print_status "Waiting for application setup to complete (this may take a few minutes)..."
sleep 60

# Save deployment info
cat > ec2-deployment-info.txt << EOF
Email Analytics Dashboard - EC2 Deployment Information
=====================================================

Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
Region: $REGION
Key File: ${KEY_NAME}.pem

Application URLs:
- HTTP: http://$PUBLIC_IP:5000
- Dashboard: http://$PUBLIC_IP:5000/dashboard

SSH Access:
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP

To check application status:
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'sudo systemctl status email-analytics'

To view application logs:
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'sudo journalctl -u email-analytics -f'

Generated on: $(date)
EOF

print_status "Deployment completed successfully!"
print_status "Application should be available at: http://$PUBLIC_IP:5000"
print_status "Deployment info saved to: ec2-deployment-info.txt"
print_warning "Note: It may take a few more minutes for the application to fully start up."
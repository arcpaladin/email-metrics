#!/bin/bash

# Simple AWS Deployment Script for Email Analytics Dashboard
set -e

# Configuration
REGION="us-east-1"
APP_NAME="email-analytics"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting deployment for $APP_NAME..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}✗ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Step 1: Create RDS PostgreSQL Database
echo "Creating RDS PostgreSQL database..."

# Generate random password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier "${APP_NAME}-db" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username dbadmin \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage 20 \
    --db-name emailanalytics \
    --publicly-accessible \
    --region $REGION \
    --backup-retention-period 7 \
    --storage-encrypted \
    2>/dev/null || echo "Database may already exist"

# Wait for database to be available
echo "Waiting for database to be available..."
aws rds wait db-instance-available \
    --db-instance-identifier "${APP_NAME}-db" \
    --region $REGION

# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "${APP_NAME}-db" \
    --region $REGION \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

echo -e "${GREEN}✓ Database created at: $DB_ENDPOINT${NC}"

# Step 2: Create ECR Repository and Push Docker Image
echo "Setting up container registry..."

# Create ECR repository
aws ecr create-repository \
    --repository-name "${APP_NAME}-backend" \
    --region $REGION \
    2>/dev/null || echo "Repository may already exist"

# Get ECR login
aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and push Docker image
echo "Building Docker image..."
docker build -t "${APP_NAME}-backend" .
docker tag "${APP_NAME}-backend:latest" "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
docker push "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"

echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"

# Step 3: Create App Runner Service Configuration
cat > apprunner-service.json << EOF
{
    "ServiceName": "${APP_NAME}-backend",
    "SourceConfiguration": {
        "ImageRepository": {
            "ImageIdentifier": "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest",
            "ImageConfiguration": {
                "Port": "5000",
                "RuntimeEnvironmentVariables": {
                    "NODE_ENV": "production",
                    "PORT": "5000",
                    "DATABASE_URL": "postgresql://dbadmin:$DB_PASSWORD@$DB_ENDPOINT:5432/emailanalytics",
                    "JWT_SECRET": "production-jwt-secret-2024"
                }
            },
            "ImageRepositoryType": "ECR"
        },
        "AutoDeploymentsEnabled": true
    },
    "InstanceConfiguration": {
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    },
    "HealthCheckConfiguration": {
        "Protocol": "HTTP",
        "Path": "/api/health",
        "Interval": 20,
        "Timeout": 10,
        "HealthyThreshold": 1,
        "UnhealthyThreshold": 5
    }
}
EOF

# Create App Runner service
echo "Creating App Runner service..."
SERVICE_ARN=$(aws apprunner create-service \
    --cli-input-json file://apprunner-service.json \
    --region $REGION \
    --query 'Service.ServiceArn' \
    --output text)

echo "Waiting for App Runner service to be running..."
aws apprunner wait service-created \
    --service-arn "$SERVICE_ARN" \
    --region $REGION

# Get service URL
SERVICE_URL=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --query 'Service.ServiceUrl' \
    --output text)

echo -e "${GREEN}✓ Backend API deployed at: https://$SERVICE_URL${NC}"

# Step 4: Deploy Frontend to Amplify
echo "Setting up Amplify frontend deployment..."

# Create Amplify app
APP_ID=$(aws amplify create-app \
    --name "${APP_NAME}-frontend" \
    --repository "https://github.com/your-repo/email-analytics" \
    --region $REGION \
    --environment-variables "VITE_API_URL=https://$SERVICE_URL" \
    --query 'app.appId' \
    --output text 2>/dev/null || echo "App may already exist")

if [ "$APP_ID" != "App may already exist" ]; then
    # Create branch
    aws amplify create-branch \
        --app-id "$APP_ID" \
        --branch-name "main" \
        --region $REGION

    # Start deployment
    aws amplify start-job \
        --app-id "$APP_ID" \
        --branch-name "main" \
        --job-type "RELEASE" \
        --region $REGION

    echo -e "${GREEN}✓ Amplify frontend deployment started${NC}"
fi

# Output deployment information
cat << EOF

${GREEN}=== DEPLOYMENT COMPLETE ===${NC}

🗄️  Database: 
   Endpoint: $DB_ENDPOINT
   Database: emailanalytics
   Username: dbadmin
   Password: $DB_PASSWORD

🚀 Backend API: https://$SERVICE_URL
   Health Check: https://$SERVICE_URL/api/health

🌐 Frontend: Check Amplify console for URL

📝 Next Steps:
1. Configure your Azure app registration redirect URIs to include the Amplify frontend URL
2. Set up environment variables in Amplify console:
   - VITE_API_URL=https://$SERVICE_URL
   - VITE_AZURE_CLIENT_ID=your-client-id
   - VITE_AZURE_TENANT_ID=your-tenant-id
3. Add OPENAI_API_KEY to App Runner environment variables if needed

EOF

# Clean up temporary files
rm -f apprunner-service.json

echo -e "${GREEN}✓ Deployment script completed successfully!${NC}"
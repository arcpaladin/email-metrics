#!/bin/bash

# AWS Deployment Script for Email Analytics Dashboard
# This script automates the deployment of both frontend and backend to AWS

set -e

echo "🚀 Starting AWS deployment..."

# Configuration
APP_NAME="email-analytics"
REGION="us-east-1"
DB_INSTANCE_CLASS="db.t3.micro"
DB_ALLOCATED_STORAGE="20"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is logged in to AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Please configure AWS CLI credentials first: aws configure${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI configured${NC}"

# Function to create RDS instance
create_database() {
    echo -e "${YELLOW}Creating RDS PostgreSQL instance...${NC}"
    
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    aws rds create-db-instance \
        --db-instance-identifier "${APP_NAME}-db" \
        --db-instance-class $DB_INSTANCE_CLASS \
        --engine postgres \
        --engine-version 15.4 \
        --allocated-storage $DB_ALLOCATED_STORAGE \
        --storage-type gp2 \
        --db-name emailanalytics \
        --master-username dbadmin \
        --master-user-password "$DB_PASSWORD" \
        --backup-retention-period 7 \
        --storage-encrypted \
        --publicly-accessible \
        --region $REGION
    
    echo -e "${GREEN}✓ RDS instance creation initiated${NC}"
    echo -e "${YELLOW}Database password: $DB_PASSWORD${NC}"
    echo -e "${YELLOW}Save this password securely!${NC}"
    
    # Wait for database to be available
    echo "Waiting for database to be available..."
    aws rds wait db-instance-available --db-instance-identifier "${APP_NAME}-db" --region $REGION
    
    # Get database endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${APP_NAME}-db" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text \
        --region $REGION)
    
    echo -e "${GREEN}✓ Database is ready at: $DB_ENDPOINT${NC}"
}

# Function to deploy backend to App Runner
deploy_backend() {
    echo -e "${YELLOW}Deploying backend to AWS App Runner...${NC}"
    
    # Create ECR repository
    aws ecr create-repository \
        --repository-name "${APP_NAME}-backend" \
        --region $REGION || true
    
    # Get ECR login
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com
    
    # Build and push Docker image
    docker build -t "${APP_NAME}-backend" .
    docker tag "${APP_NAME}-backend:latest" "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    
    echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"
    
    # Create App Runner service
    cat > apprunner-config.json << EOF
{
    "ServiceName": "${APP_NAME}-backend",
    "SourceConfiguration": {
        "ImageRepository": {
            "ImageIdentifier": "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest",
            "ImageConfiguration": {
                "Port": "5000",
                "RuntimeEnvironmentVariables": {
                    "NODE_ENV": "production",
                    "PORT": "5000"
                }
            },
            "ImageRepositoryType": "ECR"
        },
        "AutoDeploymentsEnabled": false
    },
    "InstanceConfiguration": {
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    }
}
EOF
    
    aws apprunner create-service --cli-input-json file://apprunner-config.json --region $REGION
    rm apprunner-config.json
    
    echo -e "${GREEN}✓ App Runner service created${NC}"
}

# Function to deploy frontend to Amplify
deploy_frontend() {
    echo -e "${YELLOW}Setting up Amplify for frontend deployment...${NC}"
    
    # Create Amplify app
    aws amplify create-app \
        --name "${APP_NAME}-frontend" \
        --description "Email Analytics Dashboard Frontend" \
        --repository "https://github.com/YOUR_USERNAME/YOUR_REPO" \
        --platform WEB \
        --region $REGION
    
    echo -e "${GREEN}✓ Amplify app created${NC}"
    echo -e "${YELLOW}Please connect your GitHub repository in the AWS Amplify console${NC}"
}

# Function to setup environment variables
setup_environment() {
    echo -e "${YELLOW}Setting up environment variables...${NC}"
    
    cat << EOF

🔧 ENVIRONMENT VARIABLES NEEDED:

For App Runner (Backend):
- DATABASE_URL=postgresql://dbadmin:$DB_PASSWORD@$DB_ENDPOINT:5432/emailanalytics
- OPENAI_API_KEY=your-openai-api-key
- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id
- JWT_SECRET=your-jwt-secret

For Amplify (Frontend):
- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id
- VITE_REDIRECT_URI=https://your-app-domain.amplifyapp.com

EOF
}

# Main deployment flow
main() {
    echo -e "${GREEN}Starting deployment of $APP_NAME to AWS${NC}"
    
    # Ask user what to deploy
    echo "What would you like to deploy?"
    echo "1) Full deployment (Database + Backend + Frontend)"
    echo "2) Database only"
    echo "3) Backend only"
    echo "4) Frontend only"
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            create_database
            deploy_backend
            deploy_frontend
            setup_environment
            ;;
        2)
            create_database
            ;;
        3)
            deploy_backend
            ;;
        4)
            deploy_frontend
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment completed!${NC}"
    echo -e "${YELLOW}Don't forget to:${NC}"
    echo "1. Set environment variables in AWS services"
    echo "2. Configure custom domain names"
    echo "3. Set up monitoring and alerts"
    echo "4. Configure backup strategies"
}

# Run main function
main "$@"
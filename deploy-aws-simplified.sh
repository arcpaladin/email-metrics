#!/bin/bash

# Simplified AWS Deployment Script - Works with Limited Permissions
# This version uses existing database and minimal AWS services

set -e

# Configuration
APP_NAME="email-analytics"
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting simplified AWS deployment...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}AWS credentials not configured. Run: aws configure${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI configured${NC}"

# Function to create ECR repository and push image
deploy_backend() {
    echo -e "${YELLOW}Deploying backend to AWS App Runner...${NC}"
    
    # Get AWS account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Create ECR repository (ignore if exists)
    aws ecr create-repository \
        --repository-name "${APP_NAME}-backend" \
        --region $REGION 2>/dev/null || echo "ECR repository already exists"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Please install Docker to build and push images.${NC}"
        echo -e "${YELLOW}Alternative: Use GitHub Actions or AWS CodeBuild for automated builds${NC}"
        return 1
    fi
    
    # Get ECR login
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Build Docker image
    echo "Building Docker image..."
    docker build -t "${APP_NAME}-backend" .
    
    # Tag and push image
    docker tag "${APP_NAME}-backend:latest" "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    docker push "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    
    echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"
    
    # App Runner service configuration
    cat > /tmp/apprunner-config.json << EOF
{
    "ServiceName": "${APP_NAME}-backend",
    "SourceConfiguration": {
        "ImageRepository": {
            "ImageIdentifier": "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest",
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
    
    # Create App Runner service
    if aws apprunner create-service --cli-input-json file:///tmp/apprunner-config.json --region $REGION; then
        echo -e "${GREEN}✓ App Runner service created${NC}"
        
        # Get service URL
        sleep 10
        SERVICE_URL=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceUrl" --output text)
        echo -e "${GREEN}Backend deployed at: $SERVICE_URL${NC}"
    else
        echo -e "${RED}Failed to create App Runner service${NC}"
    fi
    
    rm -f /tmp/apprunner-config.json
}

# Function to setup Amplify
deploy_frontend() {
    echo -e "${YELLOW}Setting up Amplify for frontend...${NC}"
    
    # Check if git repository exists
    if [ ! -d ".git" ]; then
        echo -e "${RED}No git repository found. Please initialize git and push to GitHub first:${NC}"
        echo "git init"
        echo "git add ."
        echo "git commit -m 'Initial commit'"
        echo "git remote add origin YOUR_GITHUB_REPO_URL"
        echo "git push -u origin main"
        return 1
    fi
    
    # Get git remote URL
    GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -z "$GIT_REMOTE" ]; then
        echo -e "${RED}No git remote found. Please add GitHub remote:${NC}"
        echo "git remote add origin YOUR_GITHUB_REPO_URL"
        return 1
    fi
    
    echo -e "${YELLOW}Git repository: $GIT_REMOTE${NC}"
    echo -e "${YELLOW}Please manually connect this repository to AWS Amplify:${NC}"
    echo "1. Go to AWS Amplify Console"
    echo "2. Click 'New app' > 'Host web app'"
    echo "3. Connect your GitHub repository: $GIT_REMOTE"
    echo "4. Use the provided amplify.yml configuration"
    echo "5. Set environment variables for Azure credentials"
}

# Function to display environment variables
show_environment_setup() {
    echo -e "${YELLOW}📝 Required Environment Variables:${NC}"
    
    cat << EOF

For App Runner Backend Service:
================================
Set these in AWS App Runner environment variables:

- DATABASE_URL=your-current-database-url
- OPENAI_API_KEY=your-openai-api-key  
- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id
- JWT_SECRET=your-jwt-secret-key
- NODE_ENV=production

For Amplify Frontend:
=====================
Set these in AWS Amplify environment variables:

- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id

Next Steps:
===========
1. Set environment variables in AWS console
2. Update Azure AD redirect URIs to include your new domains
3. Test the deployment
4. Monitor logs in CloudWatch

EOF
}

# Main deployment flow
main() {
    echo "Choose deployment option:"
    echo "1) Deploy backend only (App Runner)"
    echo "2) Setup frontend only (Amplify guidance)"
    echo "3) Both backend and frontend"
    echo "4) Show environment variable setup"
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            deploy_backend
            show_environment_setup
            ;;
        2)
            deploy_frontend
            ;;
        3)
            deploy_backend
            deploy_frontend
            show_environment_setup
            ;;
        4)
            show_environment_setup
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Deployment process completed!${NC}"
    echo -e "${YELLOW}Remember to:${NC}"
    echo "- Set environment variables in AWS services"
    echo "- Update Azure AD redirect URIs"
    echo "- Monitor application logs"
    echo "- Set up custom domain names if needed"
}

# Run main function
main "$@"
#!/bin/bash

# Docker-free AWS Deployment Script
# Uses GitHub Actions or manual source code deployment

set -e

# Configuration
APP_NAME="email-analytics"
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Docker-free AWS deployment...${NC}"

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

# Function to create GitHub Actions workflow
create_github_actions() {
    echo -e "${YELLOW}Creating GitHub Actions workflow for automated deployment...${NC}"
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy to AWS

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2
    
    - name: Build, tag, and push image to Amazon ECR
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: email-analytics-backend
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
    
    - name: Deploy to App Runner
      run: |
        # Update App Runner service with new image
        SERVICE_ARN=$(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='email-analytics-backend'].ServiceArn" --output text)
        if [ -n "$SERVICE_ARN" ]; then
          aws apprunner start-deployment --service-arn $SERVICE_ARN
        fi
EOF
    
    echo -e "${GREEN}✓ GitHub Actions workflow created${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Push this repository to GitHub"
    echo "2. Add AWS credentials to GitHub Secrets:"
    echo "   - AWS_ACCESS_KEY_ID"
    echo "   - AWS_SECRET_ACCESS_KEY"
    echo "3. Push to main branch to trigger deployment"
}

# Function to deploy using App Runner source code
deploy_with_source_code() {
    echo -e "${YELLOW}Deploying directly from source code...${NC}"
    
    # Check if git repository exists
    if [ ! -d ".git" ]; then
        echo -e "${RED}No git repository found. Please initialize git first:${NC}"
        echo "git init"
        echo "git add ."
        echo "git commit -m 'Initial commit'"
        return 1
    fi
    
    # Create apprunner.yaml configuration
    cat > apprunner.yaml << 'EOF'
version: 1.0
runtime: nodejs18
build:
  commands:
    build:
      - echo "Installing dependencies..."
      - npm install
      - echo "Building application..."
      - npm run build
run:
  runtime-version: 18
  command: npm start
  network:
    port: 5000
    env: PORT
  env:
    - name: NODE_ENV
      value: production
EOF
    
    echo -e "${GREEN}✓ App Runner configuration created${NC}"
    
    # Create a tarball of the source code
    echo "Creating source code archive..."
    tar -czf source-code.tar.gz \
        --exclude=node_modules \
        --exclude=.git \
        --exclude=client/dist \
        --exclude=dist \
        --exclude='*.log' \
        .
    
    # Upload to S3 (create bucket if needed)
    BUCKET_NAME="${APP_NAME}-source-$(date +%s)"
    aws s3 mb s3://$BUCKET_NAME --region $REGION
    aws s3 cp source-code.tar.gz s3://$BUCKET_NAME/
    
    # Create App Runner service with source code
    cat > apprunner-source-config.json << EOF
{
    "ServiceName": "${APP_NAME}-backend",
    "SourceConfiguration": {
        "CodeRepository": {
            "RepositoryUrl": "s3://$BUCKET_NAME/source-code.tar.gz",
            "SourceCodeVersion": {
                "Type": "BRANCH",
                "Value": "main"
            },
            "CodeConfiguration": {
                "ConfigurationSource": "REPOSITORY"
            }
        }
    },
    "InstanceConfiguration": {
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    }
}
EOF
    
    # Create or update App Runner service
    if aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend']" --output text | grep -q "${APP_NAME}-backend"; then
        echo -e "${YELLOW}Updating existing App Runner service...${NC}"
        SERVICE_ARN=$(aws apprunner list-services \
            --region $REGION \
            --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
            --output text)
        aws apprunner start-deployment --service-arn "$SERVICE_ARN" --region $REGION
    else
        echo "Creating App Runner service..."
        aws apprunner create-service --cli-input-json file://apprunner-source-config.json --region $REGION
    fi
    
    # Cleanup
    rm -f source-code.tar.gz apprunner-source-config.json
    
    echo -e "${GREEN}✓ Source code deployment initiated${NC}"
}

# Main menu
main() {
    echo "Choose deployment method:"
    echo "1) GitHub Actions (automated CI/CD)"
    echo "2) Direct source code deployment"
    echo "3) Setup database only"
    echo "4) Manual deployment guidance"
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            create_github_actions
            ;;
        2)
            deploy_with_source_code
            ;;
        3)
            # Use the database function from main script
            echo "Please run the main deploy-aws.sh script and choose option 2 (Database only)"
            ;;
        4)
            echo -e "${YELLOW}Manual Deployment Steps:${NC}"
            echo ""
            echo "1. Install Docker Desktop and start it"
            echo "2. Run: ./deploy-aws.sh"
            echo "3. Choose option 3 (Backend only)"
            echo ""
            echo "Alternative using AWS CodeBuild:"
            echo "1. Create CodeBuild project in AWS Console"
            echo "2. Connect to your GitHub repository"
            echo "3. Use the provided Dockerfile"
            echo "4. Set up automatic builds on push"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

main "$@"
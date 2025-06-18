#!/bin/bash

# AWS Deployment Script for Email Analytics Dashboard
# This script automates the deployment of both frontend and backend to AWS

set -e

echo "🚀 Starting AWS deployment..."

# Configuration
APP_NAME="email-analytics"
REGION="us-east-2"
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
    echo -e "${YELLOW}Setting up RDS PostgreSQL instance...${NC}"
    
    # Check if database instance already exists
    if aws rds describe-db-instances --db-instance-identifier "${APP_NAME}-db" --region $REGION &>/dev/null; then
        echo -e "${YELLOW}Database instance ${APP_NAME}-db already exists.${NC}"
        
        # Get current database status
        DB_STATUS=$(aws rds describe-db-instances \
            --db-instance-identifier "${APP_NAME}-db" \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text \
            --region $REGION)
        
        echo "Database status: $DB_STATUS"
        
        if [ "$DB_STATUS" = "available" ]; then
            echo -e "${GREEN}✓ Using existing database instance${NC}"
            
            # Get database endpoint
            DB_ENDPOINT=$(aws rds describe-db-instances \
                --db-instance-identifier "${APP_NAME}-db" \
                --query 'DBInstances[0].Endpoint.Address' \
                --output text \
                --region $REGION)
            
            echo -e "${GREEN}✓ Database is ready at: $DB_ENDPOINT${NC}"
            echo -e "${YELLOW}Note: You'll need the master password from the previous deployment${NC}"
            return 0
        else
            echo "Waiting for existing database to become available..."
            aws rds wait db-instance-available --db-instance-identifier "${APP_NAME}-db" --region $REGION
        fi
    else
        # Create new database instance
        echo "Creating new RDS PostgreSQL instance..."
        
        # Get the latest PostgreSQL 15.x version available
        POSTGRES_VERSION=$(aws rds describe-db-engine-versions \
            --engine postgres \
            --query 'DBEngineVersions[?starts_with(EngineVersion, `15.`)].EngineVersion' \
            --output text \
            --region $REGION | tr '\t' '\n' | sort -V | tail -1)
        
        if [ -z "$POSTGRES_VERSION" ]; then
            POSTGRES_VERSION="15.5"  # Fallback to known working version
        fi
        
        echo "Using PostgreSQL version: $POSTGRES_VERSION"
        
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        aws rds create-db-instance \
            --db-instance-identifier "${APP_NAME}-db" \
            --db-instance-class $DB_INSTANCE_CLASS \
            --engine postgres \
            --engine-version $POSTGRES_VERSION \
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
    fi
    
    # Get database endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${APP_NAME}-db" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text \
        --region $REGION)
    
    echo -e "${GREEN}✓ Database is ready at: $DB_ENDPOINT${NC}"
}

# Function to wait for App Runner service to be ready
wait_for_service_ready() {
    local service_arn=$1
    local max_wait=600  # 10 minutes
    local wait_time=0
    
    echo "Waiting for App Runner service to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        SERVICE_STATUS=$(aws apprunner describe-service \
            --service-arn "$service_arn" \
            --region $REGION \
            --query 'Service.Status' \
            --output text 2>/dev/null)
        
        case $SERVICE_STATUS in
            "RUNNING")
                echo -e "${GREEN}✓ Service is running${NC}"
                return 0
                ;;
            "CREATE_FAILED"|"DELETE_FAILED"|"UPDATE_FAILED_ROLLBACK_COMPLETE")
                echo -e "${RED}Service failed: $SERVICE_STATUS${NC}"
                return 1
                ;;
            "OPERATION_IN_PROGRESS"|"CREATING"|"UPDATING")
                echo "Service status: $SERVICE_STATUS (waiting...)"
                sleep 30
                wait_time=$((wait_time + 30))
                ;;
            *)
                echo "Unknown status: $SERVICE_STATUS"
                sleep 15
                wait_time=$((wait_time + 15))
                ;;
        esac
    done
    
    echo -e "${YELLOW}Timeout waiting for service. Check AWS Console for status.${NC}"
    return 1
}

# Function to deploy with GitHub Actions
deploy_with_github_actions() {
    echo -e "${YELLOW}Setting up GitHub Actions deployment...${NC}"
    
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

# Function to deploy with source code
deploy_with_source_code() {
    echo -e "${YELLOW}Deploying with source code...${NC}"
    
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
    echo -e "${YELLOW}Manual steps required:${NC}"
    echo "1. Create a GitHub repository for this project"
    echo "2. Push the code to GitHub"
    echo "3. In AWS Console, create App Runner service from GitHub source"
    echo "4. Connect to your repository and use the apprunner.yaml file"
}

# Function to deploy backend to App Runner
deploy_backend() {
    echo -e "${YELLOW}Deploying backend to AWS App Runner...${NC}"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Docker daemon is not running!${NC}"
        echo -e "${YELLOW}Choose an alternative deployment method:${NC}"
        echo "1) Start Docker and continue with container deployment"
        echo "2) Use GitHub Actions for automated deployment"
        echo "3) Use direct source code deployment"
        echo "4) Exit and start Docker manually"
        read -p "Enter your choice (1-4): " docker_choice
        
        case $docker_choice in
            1)
                echo -e "${YELLOW}Please start Docker first:${NC}"
                echo "- On macOS: Open Docker Desktop application"
                echo "- On Linux: sudo systemctl start docker"
                echo "- On Windows: Start Docker Desktop"
                echo ""
                read -p "Press Enter after starting Docker..."
                if ! docker info >/dev/null 2>&1; then
                    echo -e "${RED}Docker still not running. Exiting.${NC}"
                    return 1
                fi
                ;;
            2)
                deploy_with_github_actions
                return 0
                ;;
            3)
                deploy_with_source_code
                return 0
                ;;
            4)
                echo "Please start Docker and run this script again."
                return 1
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                return 1
                ;;
        esac
    fi
    
    # Create ECR repository (handle existing repository)
    if aws ecr describe-repositories --repository-names "${APP_NAME}-backend" --region $REGION >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ECR repository already exists${NC}"
    else
        echo "Creating ECR repository..."
        aws ecr create-repository \
            --repository-name "${APP_NAME}-backend" \
            --region $REGION
        echo -e "${GREEN}✓ ECR repository created${NC}"
    fi
    
    # Get AWS account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Get ECR login
    echo "Logging into ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Build and push Docker image
    echo "Building Docker image..."
    docker build -t "${APP_NAME}-backend" .
    
    echo "Tagging and pushing image..."
    docker tag "${APP_NAME}-backend:latest" "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    docker push "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
    
    echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"
    
    # Check if App Runner service already exists
    if aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend']" --output text | grep -q "${APP_NAME}-backend"; then
        echo -e "${YELLOW}App Runner service already exists. Checking status...${NC}"
        
        # Get service ARN and status
        SERVICE_ARN=$(aws apprunner list-services \
            --region $REGION \
            --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
            --output text)
        
        SERVICE_STATUS=$(aws apprunner describe-service \
            --service-arn "$SERVICE_ARN" \
            --region $REGION \
            --query 'Service.Status' \
            --output text)
        
        echo "Current service status: $SERVICE_STATUS"
        
        if [ "$SERVICE_STATUS" = "RUNNING" ]; then
            echo "Starting deployment update..."
            aws apprunner start-deployment \
                --service-arn "$SERVICE_ARN" \
                --region $REGION
            echo -e "${GREEN}✓ App Runner service update initiated${NC}"
        elif [ "$SERVICE_STATUS" = "CREATE_FAILED" ] || [ "$SERVICE_STATUS" = "OPERATION_IN_PROGRESS" ]; then
            echo -e "${YELLOW}Service is in $SERVICE_STATUS state. Waiting for completion...${NC}"
            echo "You can check the service status in AWS Console or run this script again later."
        else
            echo -e "${YELLOW}Service is in $SERVICE_STATUS state. Waiting for it to become available...${NC}"
            echo "This may take a few minutes. The service will be ready shortly."
        fi
        
        return 0
    fi
    
    # Create IAM role for App Runner
    echo "Creating IAM role for App Runner..."
    
    # Create trust policy for App Runner
    cat > apprunner-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "build.apprunner.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    
    # Create the IAM role
    ROLE_NAME="${APP_NAME}-apprunner-role"
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://apprunner-trust-policy.json \
        --region $REGION 2>/dev/null || echo "Role already exists"
    
    # Attach ECR access policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess" \
        --region $REGION 2>/dev/null || echo "Policy already attached"
    
    # Wait for role to be available (IAM propagation delay)
    echo "Waiting for IAM role propagation..."
    sleep 10
    
    # Get the role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text --region $REGION)
    
    echo "Using IAM role: $ROLE_ARN"
    
    # Create App Runner service
    echo "Creating App Runner service..."
    cat > apprunner-config.json << EOF
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
        "AuthenticationConfiguration": {
            "AccessRoleArn": "$ROLE_ARN"
        },
        "AutoDeploymentsEnabled": false
    },
    "InstanceConfiguration": {
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    }
}
EOF
    
    # Clean up temporary files
    rm -f apprunner-trust-policy.json
    
    # Create App Runner service with error handling
    if aws apprunner create-service --cli-input-json file://apprunner-config.json --region $REGION; then
        echo -e "${GREEN}✓ App Runner service created successfully${NC}"
        
        # Wait for service to be running
        echo "Waiting for App Runner service to start..."
        SERVICE_ARN=$(aws apprunner list-services \
            --region $REGION \
            --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
            --output text)
        
        # Get service URL
        sleep 30
        SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "$SERVICE_ARN" \
            --region $REGION \
            --query 'Service.ServiceUrl' \
            --output text 2>/dev/null)
        
        if [ -n "$SERVICE_URL" ]; then
            echo -e "${GREEN}✓ Backend deployed at: https://$SERVICE_URL${NC}"
        else
            echo -e "${YELLOW}Service created but URL not yet available. Check AWS Console.${NC}"
        fi
    else
        echo -e "${RED}Failed to create App Runner service${NC}"
        echo -e "${YELLOW}Check the following:${NC}"
        echo "1. IAM permissions for App Runner and ECR"
        echo "2. ECR image exists and is accessible"
        echo "3. AWS region is correct"
        echo ""
        echo "You can also create the service manually in AWS Console:"
        echo "- Go to AWS App Runner"
        echo "- Create service from ECR"
        echo "- Use image: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
        echo "- Set port to 5000"
    fi
    
    rm -f apprunner-config.json
}

# Function to deploy frontend to Amplify
deploy_frontend() {
    echo -e "${YELLOW}Setting up Amplify for frontend deployment...${NC}"
    
    # Check if git repository is connected to GitHub
    GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -z "$GIT_REMOTE" ]; then
        echo -e "${YELLOW}No git remote found. Manual setup required:${NC}"
        echo ""
        echo "Steps to deploy frontend:"
        echo "1. Push your code to GitHub:"
        echo "   git init"
        echo "   git add ."
        echo "   git commit -m 'Deploy to AWS'"
        echo "   git remote add origin YOUR_GITHUB_REPO_URL"
        echo "   git push -u origin main"
        echo ""
        echo "2. Go to AWS Amplify Console"
        echo "3. Click 'New app' > 'Host web app'"
        echo "4. Connect your GitHub repository"
        echo "5. Use build settings from amplify.yml"
        return 0
    fi
    
    echo "Found git repository: $GIT_REMOTE"
    echo -e "${YELLOW}Manual Amplify setup required (GitHub token needed for automation):${NC}"
    echo ""
    echo "1. Go to AWS Amplify Console: https://console.aws.amazon.com/amplify/"
    echo "2. Click 'New app' > 'Host web app'"
    echo "3. Select GitHub and authorize AWS Amplify"
    echo "4. Choose repository: $GIT_REMOTE"
    echo "5. Build settings will use amplify.yml automatically"
    echo "6. Set environment variables in Amplify console:"
    echo "   - VITE_AZURE_CLIENT_ID"
    echo "   - VITE_AZURE_TENANT_ID"
    echo ""
    echo -e "${GREEN}✓ Frontend setup guidance provided${NC}"
}

# Function to setup environment variables
setup_environment() {
    echo -e "${YELLOW}Setting up environment variables...${NC}"
    
    # Get service details
    SERVICE_ARN=$(aws apprunner list-services \
        --region $REGION \
        --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
        --output text 2>/dev/null)
    
    SERVICE_URL=$(aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION \
        --query 'Service.ServiceUrl' \
        --output text 2>/dev/null)
    
    # Get database endpoint if available
    DB_ENDPOINT_CURRENT=$(aws rds describe-db-instances \
        --db-instance-identifier "${APP_NAME}-db" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text \
        --region $REGION 2>/dev/null || echo "your-db-endpoint")
    
    cat << EOF

🔧 ENVIRONMENT VARIABLES NEEDED:

DEPLOYMENT SUMMARY:
==================
✅ Backend URL: https://$SERVICE_URL
✅ Database: $DB_ENDPOINT_CURRENT
✅ Region: $REGION
✅ Service ARN: $SERVICE_ARN

REQUIRED ENVIRONMENT VARIABLES:
==============================

For App Runner Backend Service:
-------------------------------
Set these in AWS App Runner Console:
https://console.aws.amazon.com/apprunner/home?region=$REGION#/services

Required Variables:
- NODE_ENV=production
- PORT=5000
- DATABASE_URL=postgresql://dbadmin:YOUR_DB_PASSWORD@$DB_ENDPOINT_CURRENT:5432/emailanalytics
- OPENAI_API_KEY=your-openai-api-key
- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id
- JWT_SECRET=your-jwt-secret-key

For Amplify Frontend:
--------------------
Set these in AWS Amplify Console:
https://console.aws.amazon.com/amplify/home?region=$REGION

Required Variables:
- VITE_AZURE_CLIENT_ID=your-azure-client-id
- VITE_AZURE_TENANT_ID=your-azure-tenant-id

NEXT STEPS:
===========
1. Set environment variables in App Runner:
   • Go to: https://console.aws.amazon.com/apprunner/home?region=$REGION#/services
   • Click on: $APP_NAME-backend
   • Go to: Configuration tab → Environment variables
   • Add all required variables listed above

2. Deploy frontend to Amplify:
   • Go to: https://console.aws.amazon.com/amplify/home?region=$REGION
   • Create new app from GitHub repository
   • Set frontend environment variables

3. Update Azure AD redirect URIs:
   • Add backend URL: https://$SERVICE_URL
   • Add frontend URL when Amplify is deployed

4. Test your deployment:
   • Backend: https://$SERVICE_URL/api/dashboard/metrics
   • Check logs: aws logs tail /aws/apprunner/$APP_NAME-backend/application --region $REGION --follow

IMPORTANT NOTES:
===============
• Replace YOUR_DB_PASSWORD with the database password shown during deployment
• Get your Azure credentials from Azure Portal
• Generate a strong JWT_SECRET (32+ random characters)
• Update redirect URIs in Azure AD after frontend deployment

EOF
}

# Function to cleanup existing resources
cleanup_resources() {
    echo -e "${YELLOW}Cleaning up existing AWS resources...${NC}"
    
    echo "What would you like to clean up?"
    echo "1) Database only"
    echo "2) Backend (App Runner) only"
    echo "3) Both database and backend"
    echo "4) Cancel cleanup"
    read -p "Enter your choice (1-4): " cleanup_choice
    
    case $cleanup_choice in
        1|3)
            echo -e "${RED}⚠️  This will permanently delete your database and all data!${NC}"
            read -p "Type 'DELETE' to confirm: " confirm
            if [ "$confirm" = "DELETE" ]; then
                aws rds delete-db-instance \
                    --db-instance-identifier "${APP_NAME}-db" \
                    --skip-final-snapshot \
                    --region $REGION
                echo -e "${GREEN}✓ Database deletion initiated${NC}"
            else
                echo "Database cleanup cancelled"
            fi
            ;;
    esac
    
    case $cleanup_choice in
        2|3)
            # Get App Runner service ARN
            SERVICE_ARN=$(aws apprunner list-services \
                --region $REGION \
                --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
                --output text)
            
            if [ -n "$SERVICE_ARN" ]; then
                aws apprunner delete-service \
                    --service-arn "$SERVICE_ARN" \
                    --region $REGION
                echo -e "${GREEN}✓ App Runner service deletion initiated${NC}"
            else
                echo "No App Runner service found to delete"
            fi
            
            # Clean up IAM role
            ROLE_NAME="${APP_NAME}-apprunner-role"
            aws iam detach-role-policy \
                --role-name "$ROLE_NAME" \
                --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess" \
                --region $REGION 2>/dev/null || echo "Policy not attached"
            
            aws iam delete-role \
                --role-name "$ROLE_NAME" \
                --region $REGION 2>/dev/null || echo "Role not found"
            
            echo -e "${GREEN}✓ IAM role cleanup completed${NC}"
            ;;
    esac
}

# Main deployment flow
main() {
    echo -e "${GREEN}Starting deployment of $APP_NAME to AWS${NC}"
    
    # Ask user what to deploy
    echo "What would you like to do?"
    echo "1) Full deployment (Database + Backend + Frontend)"
    echo "2) Database only"
    echo "3) Backend only"
    echo "4) Frontend only"
    echo "5) Cleanup existing resources"
    read -p "Enter your choice (1-5): " choice
    
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
        5)
            cleanup_resources
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
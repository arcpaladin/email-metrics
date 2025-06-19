#!/bin/bash

# AWS Deployment Script for Email Analytics Dashboard
set -e

# Default configuration
REGION="us-east-2"
APP_NAME="email-analytics"
SKIP_DATABASE=false
SKIP_BACKEND=false
SKIP_FRONTEND=false
FORCE_RECREATE=false

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Help function
show_help() {
    cat << EOF
AWS Deployment Script for Email Analytics Dashboard

Usage: $0 [OPTIONS]

OPTIONS:
    -r, --region REGION         AWS region (default: us-east-2)
    -n, --name APP_NAME         Application name (default: email-analytics)
    --skip-database            Skip RDS database creation
    --skip-backend             Skip App Runner backend deployment
    --skip-frontend            Skip Amplify frontend setup
    --force-recreate           Delete and recreate existing resources
    -h, --help                 Show this help message

EXAMPLES:
    $0                         # Full deployment with defaults
    $0 --region us-east-1      # Deploy to different region
    $0 --skip-database         # Skip database, deploy only backend
    $0 --skip-frontend         # Deploy database and backend only
    $0 --force-recreate        # Delete and recreate all resources

ENVIRONMENT VARIABLES:
    GITHUB_REPO_URL           GitHub repository URL for Amplify
    OPENAI_API_KEY           OpenAI API key for AI features
    VITE_AZURE_CLIENT_ID     Azure client ID for frontend
    VITE_AZURE_TENANT_ID     Azure tenant ID for frontend

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -n|--name)
            APP_NAME="$2"
            shift 2
            ;;
        --skip-database)
            SKIP_DATABASE=true
            shift
            ;;
        --skip-backend)
            SKIP_BACKEND=true
            shift
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        --force-recreate)
            FORCE_RECREATE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Starting deployment for $APP_NAME in region $REGION...${NC}"
echo "Options: Database=$([ "$SKIP_DATABASE" = true ] && echo "SKIP" || echo "DEPLOY") Backend=$([ "$SKIP_BACKEND" = true ] && echo "SKIP" || echo "DEPLOY") Frontend=$([ "$SKIP_FRONTEND" = true ] && echo "SKIP" || echo "DEPLOY")"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}✗ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Step 1: Create RDS PostgreSQL Database
if [ "$SKIP_DATABASE" = false ]; then
    echo "Creating RDS PostgreSQL database..."
    
    # Check if database exists
    if aws rds describe-db-instances --db-instance-identifier "${APP_NAME}-db" --region $REGION >/dev/null 2>&1; then
        if [ "$FORCE_RECREATE" = true ]; then
            echo "Deleting existing database..."
            aws rds delete-db-instance \
                --db-instance-identifier "${APP_NAME}-db" \
                --skip-final-snapshot \
                --region $REGION
            
            echo "Waiting for database deletion..."
            aws rds wait db-instance-deleted \
                --db-instance-identifier "${APP_NAME}-db" \
                --region $REGION
        else
            echo -e "${YELLOW}Database already exists, using existing instance${NC}"
            DB_ENDPOINT=$(aws rds describe-db-instances \
                --db-instance-identifier "${APP_NAME}-db" \
                --region $REGION \
                --query 'DBInstances[0].Endpoint.Address' \
                --output text)
            # Use default password for existing database
            DB_PASSWORD="defaultpassword123"
        fi
    fi
    
    # Create database if it doesn't exist or was deleted
    if ! aws rds describe-db-instances --db-instance-identifier "${APP_NAME}-db" --region $REGION >/dev/null 2>&1; then
        # Generate random password
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
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
            --storage-encrypted
        
        echo "Waiting for database to be available..."
        aws rds wait db-instance-available \
            --db-instance-identifier "${APP_NAME}-db" \
            --region $REGION
        
        DB_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "${APP_NAME}-db" \
            --region $REGION \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
    fi
    
    echo -e "${GREEN}✓ Database ready at: $DB_ENDPOINT${NC}"
else
    echo -e "${YELLOW}Skipping database creation${NC}"
    # Use environment variable or prompt for database URL
    if [ -z "$DATABASE_URL" ]; then
        echo "Please provide DATABASE_URL environment variable when skipping database creation"
        exit 1
    fi
    # Extract components from DATABASE_URL for App Runner config
    DB_ENDPOINT=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PASSWORD="from-environment"
fi

# Step 2: Create IAM Role for App Runner (if backend deployment enabled)
if [ "$SKIP_BACKEND" = false ]; then
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
aws iam create-role \
    --role-name "${APP_NAME}-apprunner-access-role" \
    --assume-role-policy-document file://apprunner-trust-policy.json \
    2>/dev/null || echo "Role may already exist"

# Attach the App Runner service policy
aws iam attach-role-policy \
    --role-name "${APP_NAME}-apprunner-access-role" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess \
    2>/dev/null || echo "Policy may already be attached"

# Get the role ARN
APPRUNNER_ROLE_ARN=$(aws iam get-role \
    --role-name "${APP_NAME}-apprunner-access-role" \
    --query 'Role.Arn' \
    --output text)

echo -e "${GREEN}✓ App Runner IAM role created: $APPRUNNER_ROLE_ARN${NC}"

# Step 3: Create ECR Repository and Push Docker Image
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
echo "Building Docker image (this may take a few minutes)..."
if docker build -t "${APP_NAME}-backend" . --progress=plain; then
    echo -e "${GREEN}✓ Docker build successful${NC}"
else
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
fi

docker tag "${APP_NAME}-backend:latest" "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"
docker push "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest"

echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"

# Step 4: Create App Runner Service Configuration
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
                    "JWT_SECRET": "production-jwt-secret-2024",
                    "OPENAI_API_KEY": "${OPENAI_API_KEY:-}"
                }
            },
            "ImageRepositoryType": "ECR"
        },
        "AuthenticationConfiguration": {
            "AccessRoleArn": "$APPRUNNER_ROLE_ARN"
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

# Check if App Runner service already exists
SERVICE_ARN=$(aws apprunner list-services \
    --region $REGION \
    --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$SERVICE_ARN" ]; then
    echo "App Runner service already exists. Updating..."
    
    # Update existing service
    cat > apprunner-update.json << EOF
{
    "SourceConfiguration": {
        "ImageRepository": {
            "ImageIdentifier": "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/${APP_NAME}-backend:latest",
            "ImageConfiguration": {
                "Port": "5000",
                "RuntimeEnvironmentVariables": {
                    "NODE_ENV": "production",
                    "PORT": "5000",
                    "DATABASE_URL": "postgresql://dbadmin:$DB_PASSWORD@$DB_ENDPOINT:5432/emailanalytics",
                    "JWT_SECRET": "production-jwt-secret-2024",
                    "OPENAI_API_KEY": "${OPENAI_API_KEY:-}"
                }
            },
            "ImageRepositoryType": "ECR"
        },
        "AuthenticationConfiguration": {
            "AccessRoleArn": "$APPRUNNER_ROLE_ARN"
        }
    }
}
EOF
    
    aws apprunner update-service \
        --service-arn "$SERVICE_ARN" \
        --cli-input-json file://apprunner-update.json \
        --region $REGION
    
    rm -f apprunner-update.json
else
    echo "Creating new App Runner service..."
    SERVICE_ARN=$(aws apprunner create-service \
        --cli-input-json file://apprunner-service.json \
        --region $REGION \
        --query 'Service.ServiceArn' \
        --output text)
fi

if [ -n "$SERVICE_ARN" ]; then
    echo "Waiting for App Runner service to be running..."
    
    # Wait for service to be ready with timeout
    TIMEOUT=1200  # 20 minutes
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        SERVICE_STATUS=$(aws apprunner describe-service \
            --service-arn "$SERVICE_ARN" \
            --region $REGION \
            --query 'Service.Status' \
            --output text)
        
        if [ "$SERVICE_STATUS" = "RUNNING" ]; then
            echo -e "${GREEN}✓ App Runner service is running${NC}"
            break
        elif [ "$SERVICE_STATUS" = "CREATE_FAILED" ] || [ "$SERVICE_STATUS" = "DELETE_FAILED" ]; then
            echo -e "${RED}✗ App Runner service failed: $SERVICE_STATUS${NC}"
            exit 1
        fi
        
        echo "Service status: $SERVICE_STATUS - waiting... ($ELAPSED seconds elapsed)"
        sleep 30
        ELAPSED=$((ELAPSED + 30))
    done
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "${YELLOW}⚠ Timeout waiting for service to start. Check AWS console for status.${NC}"
    fi
else
    echo -e "${RED}✗ Failed to create or find App Runner service${NC}"
    exit 1
fi

# Get service URL
SERVICE_URL=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --query 'Service.ServiceUrl' \
    --output text)

    echo -e "${GREEN}✓ Backend API deployed at: https://$SERVICE_URL${NC}"

    # Test health endpoint
    echo "Testing backend health endpoint..."
    sleep 10
    if curl -s -o /dev/null -w "%{http_code}" "https://$SERVICE_URL/api/health" | grep -q "200"; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${YELLOW}⚠ Health check failed - service may still be starting${NC}"
    fi
else
    echo -e "${YELLOW}Skipping backend deployment${NC}"
    if [ -z "$SERVICE_URL" ]; then
        SERVICE_URL="your-existing-backend-url.com"
        echo "Note: Set SERVICE_URL environment variable for existing backend"
    fi
fi

# Step 5: Create Amplify app (if frontend deployment enabled)
if [ "$SKIP_FRONTEND" = false ]; then
    if [ -n "${GITHUB_REPO_URL:-}" ]; then
        echo "Setting up Amplify frontend deployment..."
        
        # Check if Amplify app exists
        EXISTING_APP_ID=$(aws amplify list-apps \
            --region $REGION \
            --query "apps[?name=='${APP_NAME}-frontend'].appId" \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$EXISTING_APP_ID" ] && [ "$FORCE_RECREATE" = true ]; then
            echo "Deleting existing Amplify app..."
            aws amplify delete-app \
                --app-id "$EXISTING_APP_ID" \
                --region $REGION
            EXISTING_APP_ID=""
        fi
        
        if [ -z "$EXISTING_APP_ID" ]; then
            APP_ID=$(aws amplify create-app \
                --name "${APP_NAME}-frontend" \
                --repository "$GITHUB_REPO_URL" \
                --region $REGION \
                --environment-variables "VITE_API_URL=https://$SERVICE_URL,VITE_AZURE_CLIENT_ID=${VITE_AZURE_CLIENT_ID:-},VITE_AZURE_TENANT_ID=${VITE_AZURE_TENANT_ID:-}" \
                --query 'app.appId' \
                --output text)
            
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
        else
            echo -e "${YELLOW}Using existing Amplify app: $EXISTING_APP_ID${NC}"
            APP_ID="$EXISTING_APP_ID"
        fi
    else
        echo -e "${YELLOW}⚠ GITHUB_REPO_URL not set - skipping Amplify deployment${NC}"
        echo "   Deploy manually through Amplify console with these environment variables:"
        echo "   VITE_API_URL=https://$SERVICE_URL"
        echo "   VITE_AZURE_CLIENT_ID=${VITE_AZURE_CLIENT_ID:-your-client-id}"
        echo "   VITE_AZURE_TENANT_ID=${VITE_AZURE_TENANT_ID:-your-tenant-id}"
    fi
else
    echo -e "${YELLOW}Skipping frontend deployment${NC}"
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

🌐 Frontend: Deploy via Amplify console or set GITHUB_REPO_URL

📝 Next Steps:
1. Configure your Azure app registration redirect URIs to include the frontend URL
2. Set up environment variables in Amplify console (if not using automated deployment)
3. Add OPENAI_API_KEY to your environment if AI features are needed

EOF

# Clean up temporary files
rm -f apprunner-service.json apprunner-trust-policy.json

echo -e "${GREEN}✓ Deployment script completed successfully!${NC}"
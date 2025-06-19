#!/bin/bash

# Deployment Status Checker for Email Analytics Dashboard
set -e

REGION="us-east-1"
APP_NAME="email-analytics"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking deployment status for $APP_NAME..."

# Check AWS CLI configuration
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}✗ AWS CLI not configured${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS CLI configured (Account: $ACCOUNT_ID)${NC}"

# Check RDS Database
echo "Checking RDS database..."
DB_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "${APP_NAME}-db" \
    --region $REGION \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [ "$DB_STATUS" = "available" ]; then
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "${APP_NAME}-db" \
        --region $REGION \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    echo -e "${GREEN}✓ Database available at: $DB_ENDPOINT${NC}"
elif [ "$DB_STATUS" = "not-found" ]; then
    echo -e "${YELLOW}⚠ Database not found - needs to be created${NC}"
else
    echo -e "${YELLOW}⚠ Database status: $DB_STATUS${NC}"
fi

# Check ECR Repository
echo "Checking ECR repository..."
if aws ecr describe-repositories --repository-names "${APP_NAME}-backend" --region $REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✓ ECR repository exists${NC}"
    
    # Check for images
    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name "${APP_NAME}-backend" \
        --region $REGION \
        --query 'length(imageIds)' \
        --output text)
    
    if [ "$IMAGE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Docker images found ($IMAGE_COUNT)${NC}"
    else
        echo -e "${YELLOW}⚠ No Docker images found in repository${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ECR repository not found${NC}"
fi

# Check App Runner Service
echo "Checking App Runner service..."
SERVICE_ARN=$(aws apprunner list-services \
    --region $REGION \
    --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$SERVICE_ARN" ]; then
    SERVICE_STATUS=$(aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION \
        --query 'Service.Status' \
        --output text)
    
    SERVICE_URL=$(aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION \
        --query 'Service.ServiceUrl' \
        --output text)
    
    echo -e "${GREEN}✓ App Runner service status: $SERVICE_STATUS${NC}"
    echo -e "${GREEN}✓ Service URL: https://$SERVICE_URL${NC}"
    
    # Test health endpoint
    if curl -s -o /dev/null -w "%{http_code}" "https://$SERVICE_URL/api/health" | grep -q "200"; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${RED}✗ Health check failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ App Runner service not found${NC}"
fi

# Check Amplify App
echo "Checking Amplify application..."
AMPLIFY_APPS=$(aws amplify list-apps \
    --region $REGION \
    --query "apps[?name=='${APP_NAME}-frontend'].appId" \
    --output text 2>/dev/null || echo "")

if [ -n "$AMPLIFY_APPS" ]; then
    APP_ID=$(echo $AMPLIFY_APPS | cut -d' ' -f1)
    AMPLIFY_URL=$(aws amplify get-app \
        --app-id "$APP_ID" \
        --region $REGION \
        --query 'app.defaultDomain' \
        --output text)
    
    echo -e "${GREEN}✓ Amplify app found${NC}"
    echo -e "${GREEN}✓ Frontend URL: https://$APP_ID.$AMPLIFY_URL${NC}"
else
    echo -e "${YELLOW}⚠ Amplify app not found${NC}"
fi

# Summary
echo ""
echo "=== DEPLOYMENT SUMMARY ==="
echo "Database: ${DB_STATUS:-not-found}"
echo "Backend API: ${SERVICE_STATUS:-not-found}"
echo "Frontend: ${AMPLIFY_APPS:+found}"

if [ "$DB_STATUS" = "available" ] && [ "$SERVICE_STATUS" = "RUNNING" ] && [ -n "$AMPLIFY_APPS" ]; then
    echo -e "${GREEN}✓ Full deployment appears to be running${NC}"
else
    echo -e "${YELLOW}⚠ Deployment incomplete - run deploy-simple.sh to complete setup${NC}"
fi
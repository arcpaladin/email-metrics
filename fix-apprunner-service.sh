#!/bin/bash

# Fix App Runner Service Status
set -e

REGION="us-east-2"
SERVICE_ARN="arn:aws:apprunner:us-east-2:331409392797:service/email-analytics-backend/18b15e5bec244247ad6dfc6f84b19575"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking App Runner service status..."

# Check service status
SERVICE_STATUS=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --query 'Service.Status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

echo "Current service status: $SERVICE_STATUS"

if [ "$SERVICE_STATUS" = "NOT_FOUND" ]; then
    echo -e "${RED}✗ Service not found or access denied${NC}"
    exit 1
elif [ "$SERVICE_STATUS" = "CREATE_FAILED" ]; then
    echo -e "${RED}✗ Service creation failed${NC}"
    
    # Get failure reason
    aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION \
        --query 'Service.ServiceStatusMessage' \
        --output text
    
    echo "Deleting failed service..."
    aws apprunner delete-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION
    
    echo -e "${YELLOW}Service deleted. Re-run deployment script to create a new one.${NC}"
    
elif [ "$SERVICE_STATUS" = "OPERATION_IN_PROGRESS" ]; then
    echo -e "${YELLOW}⚠ Service operation in progress. Wait for completion before configuring Web ACL.${NC}"
    
elif [ "$SERVICE_STATUS" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Service is running${NC}"
    
    # Get service URL
    SERVICE_URL=$(aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region $REGION \
        --query 'Service.ServiceUrl' \
        --output text)
    
    echo "Service URL: https://$SERVICE_URL"
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if curl -s -o /dev/null -w "%{http_code}" "https://$SERVICE_URL/api/health" | grep -q "200"; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${RED}✗ Health check failed${NC}"
    fi
    
    echo -e "${GREEN}Service is ready for Web ACL configuration${NC}"
    
else
    echo -e "${YELLOW}Service status: $SERVICE_STATUS${NC}"
    echo "Wait for service to reach RUNNING state before configuring Web ACL"
fi

echo ""
echo "=== Web ACL Configuration Notes ==="
echo "• Web ACLs can only be associated with services in RUNNING state"
echo "• Ensure you're configuring the Web ACL in region: $REGION"
echo "• Service ARN: $SERVICE_ARN"
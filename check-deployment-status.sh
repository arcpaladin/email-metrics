#!/bin/bash

# Check AWS App Runner Service Status
APP_NAME="email-analytics"
REGION="us-east-2"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking App Runner service status..."

# Get service ARN
SERVICE_ARN=$(aws apprunner list-services \
    --region $REGION \
    --query "ServiceSummaryList[?ServiceName=='${APP_NAME}-backend'].ServiceArn" \
    --output text 2>/dev/null)

if [ -z "$SERVICE_ARN" ]; then
    echo -e "${RED}No App Runner service found${NC}"
    exit 1
fi

# Get detailed service information
SERVICE_INFO=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to get service information${NC}"
    exit 1
fi

# Extract key information
STATUS=$(echo "$SERVICE_INFO" | jq -r '.Service.Status')
SERVICE_URL=$(echo "$SERVICE_INFO" | jq -r '.Service.ServiceUrl // "Not available"')
CREATED_AT=$(echo "$SERVICE_INFO" | jq -r '.Service.CreatedAt')
UPDATED_AT=$(echo "$SERVICE_INFO" | jq -r '.Service.UpdatedAt')

# Display status with color coding
echo ""
echo "Service Details:"
echo "=================="
echo "Name: ${APP_NAME}-backend"
echo "ARN: $SERVICE_ARN"
echo "Region: $REGION"

case $STATUS in
    "RUNNING")
        echo -e "Status: ${GREEN}$STATUS${NC}"
        echo -e "URL: ${GREEN}https://$SERVICE_URL${NC}"
        ;;
    "CREATE_FAILED"|"DELETE_FAILED"|"UPDATE_FAILED_ROLLBACK_COMPLETE")
        echo -e "Status: ${RED}$STATUS${NC}"
        ;;
    "OPERATION_IN_PROGRESS"|"CREATING"|"UPDATING")
        echo -e "Status: ${YELLOW}$STATUS${NC}"
        echo "Service is still being processed. This may take several minutes."
        ;;
    *)
        echo -e "Status: ${YELLOW}$STATUS${NC}"
        ;;
esac

echo "Created: $CREATED_AT"
echo "Updated: $UPDATED_AT"

# Show recent operations if available
echo ""
echo "Recent Operations:"
echo "=================="
aws apprunner list-operations \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --max-items 3 \
    --query 'OperationSummaryList[*].[Type,Status,StartedAt]' \
    --output table 2>/dev/null || echo "No operation history available"

# If service is running, test connectivity
if [ "$STATUS" = "RUNNING" ] && [ "$SERVICE_URL" != "Not available" ]; then
    echo ""
    echo "Testing connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" "https://$SERVICE_URL" | grep -q "200\|302\|404"; then
        echo -e "${GREEN}✓ Service is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Service may not be fully ready${NC}"
    fi
fi

echo ""
echo "To view logs: aws logs tail /aws/apprunner/${APP_NAME}-backend/application --region $REGION --follow"
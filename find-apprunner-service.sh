#!/bin/bash

# Find App Runner Services
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Searching for App Runner services..."

# Check common regions
REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2")

for region in "${REGIONS[@]}"; do
    echo "Checking region: $region"
    
    services=$(aws apprunner list-services \
        --region $region \
        --query 'ServiceSummaryList[].{Name:ServiceName,Arn:ServiceArn,Status:Status}' \
        --output table 2>/dev/null || echo "No access or no services")
    
    if [[ "$services" != "No access or no services" && "$services" != *"---"* ]]; then
        echo -e "${GREEN}Found services in $region:${NC}"
        echo "$services"
        echo ""
        
        # Get detailed status for each service
        service_arns=$(aws apprunner list-services \
            --region $region \
            --query 'ServiceSummaryList[].ServiceArn' \
            --output text 2>/dev/null || echo "")
        
        for arn in $service_arns; do
            if [ -n "$arn" ]; then
                echo "Service ARN: $arn"
                status=$(aws apprunner describe-service \
                    --service-arn "$arn" \
                    --region $region \
                    --query 'Service.Status' \
                    --output text)
                
                url=$(aws apprunner describe-service \
                    --service-arn "$arn" \
                    --region $region \
                    --query 'Service.ServiceUrl' \
                    --output text)
                
                echo "Status: $status"
                if [ "$url" != "None" ]; then
                    echo "URL: https://$url"
                fi
                echo "---"
            fi
        done
    else
        echo "No services found in $region"
    fi
    echo ""
done

echo "=== Summary ==="
echo "If you found a service above:"
echo "1. Note the region and ARN"
echo "2. Ensure you're configuring Web ACL in the same region"
echo "3. Service must be in RUNNING status for Web ACL association"
echo ""
echo "If no services found:"
echo "1. Run ./deploy-aws.sh to create a new service"
echo "2. Ensure AWS CLI has proper permissions"
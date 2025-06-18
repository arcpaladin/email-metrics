#!/bin/bash

# Fix App Runner Service Issues
APP_NAME="email-analytics"
REGION="us-east-2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Diagnosing App Runner service issues...${NC}"

# Function to list all App Runner services
list_all_services() {
    echo "All App Runner services in region $REGION:"
    aws apprunner list-services --region $REGION --output table
}

# Function to check service health
check_service_health() {
    local service_arn=$1
    
    echo "Checking service health for: $service_arn"
    
    # Get service details
    SERVICE_INFO=$(aws apprunner describe-service \
        --service-arn "$service_arn" \
        --region $REGION \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Service does not exist or cannot be accessed${NC}"
        return 1
    fi
    
    STATUS=$(echo "$SERVICE_INFO" | jq -r '.Service.Status')
    SERVICE_URL=$(echo "$SERVICE_INFO" | jq -r '.Service.ServiceUrl // "Not available"')
    
    echo "Current status: $STATUS"
    echo "Service URL: $SERVICE_URL"
    
    case $STATUS in
        "CREATE_FAILED"|"DELETE_FAILED"|"UPDATE_FAILED_ROLLBACK_COMPLETE")
            echo -e "${RED}Service is in failed state: $STATUS${NC}"
            echo "This service needs to be deleted and recreated."
            return 1
            ;;
        "OPERATION_IN_PROGRESS"|"CREATING"|"UPDATING"|"DELETING")
            echo -e "${YELLOW}Service is busy: $STATUS${NC}"
            echo "Wait for the operation to complete before making changes."
            return 2
            ;;
        "RUNNING")
            echo -e "${GREEN}Service is healthy: $STATUS${NC}"
            return 0
            ;;
        *)
            echo -e "${YELLOW}Unknown status: $STATUS${NC}"
            return 3
            ;;
    esac
}

# Function to delete failed service
delete_failed_service() {
    local service_arn=$1
    
    echo -e "${YELLOW}Deleting failed service...${NC}"
    echo -e "${RED}⚠️  This will permanently delete the service!${NC}"
    read -p "Type 'DELETE' to confirm: " confirm
    
    if [ "$confirm" = "DELETE" ]; then
        aws apprunner delete-service \
            --service-arn "$service_arn" \
            --region $REGION
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Service deletion initiated${NC}"
            echo "Wait for deletion to complete, then redeploy using ./deploy-aws.sh"
        else
            echo -e "${RED}Failed to delete service${NC}"
        fi
    else
        echo "Deletion cancelled"
    fi
}

# Function to recreate service
recreate_service() {
    echo -e "${YELLOW}Recreating App Runner service...${NC}"
    echo "This will run the backend deployment from deploy-aws.sh"
    
    # Extract backend deployment function and run it
    if [ -f "deploy-aws.sh" ]; then
        echo "Running backend deployment..."
        ./deploy-aws.sh
    else
        echo -e "${RED}deploy-aws.sh not found${NC}"
        echo "Please run the deployment script manually"
    fi
}

# Main execution
main() {
    echo "Choose an action:"
    echo "1) List all App Runner services"
    echo "2) Check specific service health"
    echo "3) Delete failed service and recreate"
    echo "4) Check service logs"
    echo "5) Exit"
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            list_all_services
            ;;
        2)
            read -p "Enter service ARN: " service_arn
            check_service_health "$service_arn"
            ;;
        3)
            read -p "Enter service ARN to delete: " service_arn
            check_service_health "$service_arn"
            health_status=$?
            
            if [ $health_status -eq 1 ]; then
                delete_failed_service "$service_arn"
            else
                echo "Service is not in a failed state. Deletion not recommended."
            fi
            ;;
        4)
            echo "App Runner logs command:"
            echo "aws logs tail /aws/apprunner/$APP_NAME-backend/application --region $REGION --follow"
            echo ""
            echo "Run this command to view live logs"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# Check if specific service ARN provided as argument
if [ "$1" != "" ]; then
    echo "Checking service: $1"
    check_service_health "$1"
    exit $?
fi

main
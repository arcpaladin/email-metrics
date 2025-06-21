#!/bin/bash

# AWS EC2 Deployment for Email Analytics Dashboard with RDS
# Usage: ./deploy.sh [mode]
# Modes: full, database, backend, update, cleanup
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resource naming constants
DB_IDENTIFIER="email-analytics-db"
EC2_TAG_NAME="email-analytics-backend"
EC2_SG_NAME="email-analytics-ec2-sg"
RDS_SG_NAME="email-analytics-rds-sg"
SUBNET_GROUP_NAME="email-analytics-subnet-group"

# Print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "==============================="
}

# Check if .env file exists and load variables
load_environment() {
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Please create one with your configuration."
        exit 1
    fi

    # Load environment variables from .env file
    set -a
    while IFS='=' read -r key value; do
        if [[ $key != \#* ]] && [[ -n $key ]] && [[ -n $value ]]; then
            export "$key=$value"
        fi
    done < .env
    set +a

    print_info "Environment variables loaded from .env"
}

# Check AWS CLI and credentials
check_aws_setup() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Install it first: https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi

    print_info "AWS CLI configured and credentials valid"
}

# Check if RDS database exists
check_database_exists() {
    if aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --region $REGION &>/dev/null; then
        return 0  # exists
    else
        return 1  # doesn't exist
    fi
}

# Check if EC2 instance exists
check_backend_exists() {
    local instance_ids=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$EC2_TAG_NAME" "Name=instance-state-name,Values=running,pending,stopped,stopping" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region $REGION 2>/dev/null)
    
    if [ ! -z "$instance_ids" ] && [ "$instance_ids" != "None" ]; then
        return 0  # exists
    else
        return 1  # doesn't exist
    fi
}

# Get EC2 instance ID
get_backend_instance_id() {
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$EC2_TAG_NAME" "Name=instance-state-name,Values=running,pending,stopped,stopping" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region $REGION 2>/dev/null
}

# Get EC2 public IP
get_backend_public_ip() {
    local instance_id=$(get_backend_instance_id)
    if [ ! -z "$instance_id" ] && [ "$instance_id" != "None" ]; then
        aws ec2 describe-instances \
            --instance-ids $instance_id \
            --region $REGION \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text 2>/dev/null
    fi
}

# Deploy database
deploy_database() {
    print_header "Deploying Database"

    if check_database_exists; then
        print_warning "Database '$DB_IDENTIFIER' already exists, skipping creation..."
        local db_endpoint=$(aws rds describe-db-instances \
            --db-instance-identifier $DB_IDENTIFIER \
            --region $REGION \
            --query 'DBInstances[0].Endpoint.Address' --output text)
        print_info "Database endpoint: $db_endpoint"
        return 0
    fi

    print_info "Creating database infrastructure..."

    # Get VPC info for RDS
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --query 'Vpcs[0].VpcId' --output text)
    local subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --region $REGION --query 'Subnets[*].SubnetId' --output text)

    # Create RDS subnet group
    print_info "Creating RDS subnet group..."
    aws rds create-db-subnet-group \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --db-subnet-group-description "Subnet group for Email Analytics RDS" \
        --subnet-ids $subnet_ids \
        --region $REGION 2>/dev/null || print_warning "Subnet group may already exist"

    # Create RDS security group
    print_info "Creating RDS security group..."
    local rds_sg_id=$(aws ec2 create-security-group \
        --group-name $RDS_SG_NAME \
        --description "RDS PostgreSQL for Email Analytics" \
        --vpc-id $vpc_id \
        --region $REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --group-names $RDS_SG_NAME --region $REGION --query 'SecurityGroups[0].GroupId' --output text)

    # Allow PostgreSQL access
    aws ec2 authorize-security-group-ingress \
        --group-id $rds_sg_id \
        --protocol tcp \
        --port 5432 \
        --cidr 10.0.0.0/8 \
        --region $REGION 2>/dev/null || true

    # Create RDS instance
    print_info "Creating PostgreSQL database (this takes 5-10 minutes)..."
    aws rds create-db-instance \
        --db-instance-identifier $DB_IDENTIFIER \
        --db-instance-class $DB_INSTANCE_CLASS \
        --engine postgres \
        --engine-version 15.7 \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --storage-type gp2 \
        --vpc-security-group-ids $rds_sg_id \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --db-name $DB_NAME \
        --backup-retention-period 7 \
        --no-multi-az \
        --publicly-accessible \
        --region $REGION

    print_info "Waiting for database to be available..."
    aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER --region $REGION

    local db_endpoint=$(aws rds describe-db-instances \
        --db-instance-identifier $DB_IDENTIFIER \
        --region $REGION \
        --query 'DBInstances[0].Endpoint.Address' --output text)

    print_status "Database deployed successfully at: $db_endpoint"
}

# Deploy backend
deploy_backend() {
    print_header "Deploying Backend"

    if check_backend_exists; then
        print_warning "Backend instance '$EC2_TAG_NAME' already exists, skipping creation..."
        local public_ip=$(get_backend_public_ip)
        print_info "Backend public IP: $public_ip"
        return 0
    fi

    print_info "Creating backend infrastructure..."

    # Get the latest Ubuntu 22.04 LTS AMI ID
    print_info "Finding latest Ubuntu 22.04 LTS AMI..."
    local latest_ami=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text \
        --region $REGION)

    if [ "$latest_ami" != "None" ] && [ ! -z "$latest_ami" ]; then
        print_info "Using latest Ubuntu AMI: $latest_ami"
        AMI_ID=$latest_ami
    else
        print_info "Using configured AMI: $AMI_ID"
    fi

    # Get VPC info
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --query 'Vpcs[0].VpcId' --output text)

    # Create key pair if it doesn't exist
    if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
        print_info "Creating key pair..."
        aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
        chmod 400 ${KEY_NAME}.pem
        print_status "Key saved as ${KEY_NAME}.pem"
    else
        print_warning "Key pair '$KEY_NAME' already exists, skipping creation..."
    fi

    # Create EC2 security group
    print_info "Creating EC2 security group..."
    local sg_id=$(aws ec2 create-security-group \
        --group-name $EC2_SG_NAME \
        --description "Email Analytics Backend" \
        --region $REGION \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups --group-names $EC2_SG_NAME --region $REGION --query 'SecurityGroups[0].GroupId' --output text)

    # Add rules for web server
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true

    # Update RDS security group to allow access from EC2
    local rds_sg_id=$(aws ec2 describe-security-groups --group-names $RDS_SG_NAME --region $REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    if [ ! -z "$rds_sg_id" ]; then
        aws ec2 authorize-security-group-ingress \
            --group-id $rds_sg_id \
            --protocol tcp \
            --port 5432 \
            --source-group $sg_id \
            --region $REGION 2>/dev/null || true
    fi

    # Get database endpoint
    local db_endpoint=""
    if check_database_exists; then
        db_endpoint=$(aws rds describe-db-instances \
            --db-instance-identifier $DB_IDENTIFIER \
            --region $REGION \
            --query 'DBInstances[0].Endpoint.Address' --output text)
    else
        print_warning "Database not found. Deploy database first or use 'full' mode."
        return 1
    fi

    # Create user data script
    create_userdata_script "$db_endpoint"

    # Launch EC2 instance
    print_info "Launching EC2 instance..."
    local instance_id=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $sg_id \
        --region $REGION \
        --user-data file://userdata.sh \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$EC2_TAG_NAME}]" \
        --query 'Instances[0].InstanceId' --output text)

    print_info "Waiting for instance to start..."
    aws ec2 wait instance-running --instance-ids $instance_id --region $REGION

    # Get public IP
    local public_ip=$(aws ec2 describe-instances \
        --instance-ids $instance_id \
        --region $REGION \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

    # Cleanup
    rm -f userdata.sh

    print_status "Backend deployed successfully!"
    print_info "Instance ID: $instance_id"
    print_info "Public IP: $public_ip"
    print_info "Application URL: http://$public_ip"
}

# Update backend application
update_backend() {
    print_header "Updating Backend Application"

    if ! check_backend_exists; then
        print_error "Backend instance not found. Deploy backend first."
        return 1
    fi

    local instance_id=$(get_backend_instance_id)
    local public_ip=$(get_backend_public_ip)

    print_info "Updating application on instance: $instance_id"
    print_info "Public IP: $public_ip"

    # Create update script
    cat > update_app.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting application update..."

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd /home/ubuntu/app

# Pull latest code
echo "Pulling latest code..."
git pull origin main || git pull origin master || echo "Git pull failed, continuing..."

# Install/update dependencies
echo "Installing dependencies..."
yarn install

# Restart application with PM2
echo "Restarting application..."
pm2 restart email-analytics || pm2 start server.js --name email-analytics

echo "Application updated successfully!"
EOF

    # Copy and execute update script
    print_info "Copying update script to instance..."
    scp -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no update_app.sh ubuntu@$public_ip:/tmp/

    print_info "Executing update script..."
    ssh -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$public_ip 'chmod +x /tmp/update_app.sh && /tmp/update_app.sh'

    # Cleanup
    rm -f update_app.sh

    print_status "Backend application updated successfully!"
    print_info "Application URL: http://$public_ip"
}

# Create userdata script
create_userdata_script() {
    local db_endpoint=$1

    cat > userdata.sh << EOF
#!/bin/bash
set -e

# Enable logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user-data script at \$(date)"

# Update system
echo "Updating system packages..."
apt-get update -y
apt-get install -y git curl unzip awscli

# Install NVM (Node Version Manager)
echo "Installing NVM (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source NVM to make it available in current session
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# Install Node.js 18 via NVM
echo "Installing Node.js 18 via NVM..."
nvm install 18
nvm use 18
nvm alias default 18

# Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# Also install for ubuntu user
echo "Setting up NVM and tools for ubuntu user..."
sudo -u ubuntu bash -c '
export NVM_DIR="/home/ubuntu/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source /home/ubuntu/.nvm/nvm.sh
nvm install 18
nvm use 18
nvm alias default 18
npm install -g pm2
'

# Create app directory
echo "Creating application directory..."
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
chown -R ubuntu:ubuntu /home/ubuntu/app

# Clone repository to get deployment files
echo "Cloning repository..."
git clone https://github.com/arcpaladin/email-metrics.git temp-repo || true

# Copy deployment files
echo "Setting up deployment files..."
cp temp-repo/deploy/package.json . || echo "Warning: Could not copy package.json"
cp temp-repo/deploy/server.js . || echo "Warning: Could not copy server.js"
cp temp-repo/deploy/ecosystem.config.js . || echo "Warning: Could not copy ecosystem.config.js"
cp temp-repo/deploy/migrate.js . || echo "Warning: Could not copy migrate.js"

# Create environment file
cat > .env << ENVEOF
NODE_ENV=production
PORT=80
DATABASE_URL=$DATABASE_URL
JWT_SECRET=$JWT_SECRET
FRONTEND_URL=$FRONTEND_URL
API_URL=$API_URL
MICROSOFT_CLIENT_ID=$MICROSOFT_CLIENT_ID
MICROSOFT_CLIENT_SECRET=$MICROSOFT_CLIENT_SECRET
MICROSOFT_TENANT_ID=$MICROSOFT_TENANT_ID
OPENAI_API_KEY=$OPENAI_API_KEY
SESSION_SECRET=$SESSION_SECRET
ENVEOF

# Install dependencies
echo "Installing dependencies..."
npm install

# Run database migrations
echo "Running database migrations..."
npm run migrate || echo "Migration failed or not needed"

# Start application with PM2
echo "Starting application..."
pm2 start ecosystem.config.js
pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save

# Cleanup
rm -rf temp-repo

echo "✅ Application deployed successfully at \$(date)"
echo "🔗 API URL: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "📚 API Docs: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/api/docs"
EOF
}

# Cleanup all resources
cleanup_all() {
    print_header "Cleaning Up All Resources"

    print_warning "This will delete ALL Email Analytics resources. Are you sure? (y/N)"
    read -r confirmation
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled."
        return 0
    fi

    # Terminate EC2 instances
    print_info "Terminating EC2 instances..."
    local instance_ids=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$EC2_TAG_NAME" "Name=instance-state-name,Values=running,pending,stopped,stopping" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region $REGION 2>/dev/null)
    
    if [ ! -z "$instance_ids" ] && [ "$instance_ids" != "None" ]; then
        aws ec2 terminate-instances --instance-ids $instance_ids --region $REGION
        print_info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $instance_ids --region $REGION
        print_status "EC2 instances terminated"
    else
        print_warning "No EC2 instances found"
    fi

    # Delete RDS instance
    print_info "Deleting RDS database..."
    if check_database_exists; then
        aws rds delete-db-instance \
            --db-instance-identifier $DB_IDENTIFIER \
            --skip-final-snapshot \
            --region $REGION
        print_info "Waiting for database deletion..."
        aws rds wait db-instance-deleted --db-instance-identifier $DB_IDENTIFIER --region $REGION
        print_status "Database deleted"
    else
        print_warning "Database not found"
    fi

    # Delete security groups
    print_info "Deleting security groups..."
    aws ec2 delete-security-group --group-name $EC2_SG_NAME --region $REGION 2>/dev/null && print_status "EC2 security group deleted" || print_warning "EC2 security group not found"
    aws ec2 delete-security-group --group-name $RDS_SG_NAME --region $REGION 2>/dev/null && print_status "RDS security group deleted" || print_warning "RDS security group not found"

    # Delete RDS subnet group
    aws rds delete-db-subnet-group --db-subnet-group-name $SUBNET_GROUP_NAME --region $REGION 2>/dev/null && print_status "RDS subnet group deleted" || print_warning "RDS subnet group not found"

    print_status "Cleanup completed!"
}

# Check resource status
check_resources() {
    print_header "Resource Status Check"

    # Check database
    if check_database_exists; then
        local db_endpoint=$(aws rds describe-db-instances \
            --db-instance-identifier $DB_IDENTIFIER \
            --region $REGION \
            --query 'DBInstances[0].Endpoint.Address' --output text)
        print_status "Database: Running at $db_endpoint"
    else
        print_warning "Database: Not found"
    fi

    # Check backend
    if check_backend_exists; then
        local instance_id=$(get_backend_instance_id)
        local public_ip=$(get_backend_public_ip)
        print_status "Backend: Running (ID: $instance_id, IP: $public_ip)"
        print_info "Application URL: http://$public_ip"
    else
        print_warning "Backend: Not found"
    fi
}

# Show interactive menu
show_menu() {
    print_header "Email Analytics Deployment Tool"
    echo "1) Full deployment (database + backend)"
    echo "2) Database only"
    echo "3) Backend only"
    echo "4) Update backend application"
    echo "5) Check resource status"
    echo "6) Cleanup all resources"
    echo "7) Exit"
    echo
    echo -n "Please select an option (1-7): "
    read -r choice
    
    case $choice in
        1) deploy_full ;;
        2) deploy_database ;;
        3) deploy_backend ;;
        4) update_backend ;;
        5) check_resources ;;
        6) cleanup_all ;;
        7) exit 0 ;;
        *) print_error "Invalid option. Please try again." && show_menu ;;
    esac
}

# Deploy full stack
deploy_full() {
    print_header "Full Stack Deployment"
    deploy_database
    deploy_backend
    
    local public_ip=$(get_backend_public_ip)
    print_status "Full deployment completed!"
    print_info "Application URL: http://$public_ip"
    print_info "Health Check: http://$public_ip/health"
}

# Main execution
main() {
    load_environment
    check_aws_setup

    case "${1:-}" in
        "full")
            deploy_full
            ;;
        "database")
            deploy_database
            ;;
        "backend")
            deploy_backend
            ;;
        "update")
            update_backend
            ;;
        "cleanup")
            cleanup_all
            ;;
        "status")
            check_resources
            ;;
        "")
            show_menu
            ;;
        *)
            echo "Usage: $0 [full|database|backend|update|cleanup|status]"
            echo
            echo "Modes:"
            echo "  full      - Deploy complete stack (database + backend)"
            echo "  database  - Deploy only RDS database"
            echo "  backend   - Deploy only EC2 backend application"
            echo "  update    - Update existing backend application code"
            echo "  cleanup   - Delete all resources"
            echo "  status    - Check resource status"
            echo
            echo "Interactive mode: Run without arguments"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

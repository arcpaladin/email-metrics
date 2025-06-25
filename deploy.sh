#!/bin/bash

# AWS EC2 Deployment for Email Analytics Dashboard Backend API
# Usage: ./deploy.sh [mode]
# Modes: backend, update, cleanup, status
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resource naming constants
EC2_TAG_NAME="email-analytics-backend"
EC2_SG_NAME="email-analytics-ec2-sg"

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

# Update ecosystem.config.js with EC2 IP
update_ecosystem_config() {
    local public_ip=$1
    local ecosystem_file="deploy/ecosystem.config.js"
    
    if [ -f "$ecosystem_file" ]; then
        print_info "Updating ecosystem.config.js with EC2 IP: $public_ip"
        
        # Create backup
        cp "$ecosystem_file" "${ecosystem_file}.backup"
        
        # Update the placeholder with actual IP
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/PLACEHOLDER_EC2_IP/$public_ip/g" "$ecosystem_file"
        else
            # Linux
            sed -i "s/PLACEHOLDER_EC2_IP/$public_ip/g" "$ecosystem_file"
        fi
        
        print_status "Ecosystem config updated successfully"
        print_info "You can now use: pm2 deploy production"
    else
        print_warning "ecosystem.config.js not found at $ecosystem_file"
    fi
}

# Copy SSH key locally for PM2 deployment
copy_ssh_key_locally() {
    print_info "Copying SSH key locally for PM2 deployment..."
    
    # Check if key exists locally
    if [ -f "${KEY_NAME}.pem" ]; then
        print_warning "SSH key ${KEY_NAME}.pem already exists locally"
        return 0
    fi
    
    # Try to get the key from AWS if it exists
    if aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
        print_error "Key pair exists in AWS but private key is not available locally."
        print_info "AWS doesn't store private keys. You need to:"
        print_info "1. Delete the existing key pair: aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION"
        print_info "2. Redeploy to create a new key: ./deploy.sh backend"
        return 1
    else
        print_error "Key pair '$KEY_NAME' doesn't exist in AWS."
        print_info "Run './deploy.sh backend' to create the infrastructure and SSH key."
        return 1
    fi
}

# Setup PM2 deployment (copy key and update config)
setup_pm2_deployment() {
    print_header "Setting up PM2 Deployment"
    
    # Check if backend exists
    if ! check_backend_exists; then
        print_error "Backend instance not found. Deploy backend first with: ./deploy.sh backend"
        return 1
    fi
    
    # Get instance details
    local instance_id=$(get_backend_instance_id)
    local public_ip=$(get_backend_public_ip)
    
    print_info "Backend instance found:"
    print_info "Instance ID: $instance_id"
    print_info "Public IP: $public_ip"
    
    # Update ecosystem config with current IP
    update_ecosystem_config "$public_ip"
    
    # Check if SSH key exists locally
    if [ ! -f "${KEY_NAME}.pem" ]; then
        print_warning "SSH key not found locally. Attempting to resolve..."
        copy_ssh_key_locally
        
        if [ ! -f "${KEY_NAME}.pem" ]; then
            print_error "Cannot proceed with PM2 deployment without SSH key."
            print_info "Alternative: Use AWS Systems Manager for server access:"
            print_info "aws ssm start-session --target $instance_id --region $REGION"
            return 1
        fi
    fi
    
    print_status "PM2 deployment setup complete!"
    print_info "You can now run:"
    print_info "  pm2 deploy production setup    # First time setup"
    print_info "  pm2 deploy production          # Deploy application"
    print_info "  pm2 deploy production update   # Update application"
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

    # Create user data script
    create_userdata_script

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
    
    # Update ecosystem.config.js with the new IP
    update_ecosystem_config "$public_ip"
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

    # Check if SSH key exists
    if [ ! -f "${KEY_NAME}.pem" ]; then
        print_error "SSH key file '${KEY_NAME}.pem' not found."
        print_info "Alternative update methods:"
        print_info "1. Use AWS Systems Manager Session Manager:"
        print_info "   aws ssm start-session --target $instance_id --region $REGION"
        print_info "2. Recreate the key pair by running:"
        print_info "   aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION"
        print_info "   ./deploy.sh backend"
        print_info "3. Redeploy the backend completely:"
        print_info "   ./deploy.sh cleanup && ./deploy.sh backend"
        return 1
    fi

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
npm install

# Restart application with PM2
echo "Restarting application..."
pm2 restart email-analytics || pm2 start server.js --name email-analytics

echo "Application updated successfully!"
EOF

    # Copy and execute update script
    print_info "Copying update script to instance..."
    if scp -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no update_app.sh ubuntu@$public_ip:/tmp/ 2>/dev/null; then
        print_info "Executing update script..."
        if ssh -i ${KEY_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$public_ip 'chmod +x /tmp/update_app.sh && /tmp/update_app.sh' 2>/dev/null; then
            print_status "Backend application updated successfully!"
            print_info "Application URL: http://$public_ip"
        else
            print_error "Failed to execute update script via SSH."
            print_info "Try using AWS Systems Manager instead:"
            print_info "aws ssm start-session --target $instance_id --region $REGION"
        fi
    else
        print_error "Failed to copy update script via SCP."
        print_info "SSH connection failed. Alternative options:"
        print_info "1. Use AWS Systems Manager: aws ssm start-session --target $instance_id --region $REGION"
        print_info "2. Redeploy: ./deploy.sh cleanup && ./deploy.sh backend"
    fi

    # Cleanup
    rm -f update_app.sh
}

# Create userdata script
create_userdata_script() {
    cat > userdata.sh << EOF
#!/bin/bash
set -e

# Enable comprehensive logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Email Analytics Backend Deployment Log"
echo "Started at: \$(date)"
echo "Instance ID: \$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Public IP: \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================="

# Function to log with timestamp
log_info() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] INFO: \$1"
}

log_error() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] ERROR: \$1"
}

log_success() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: \$1"
}

# Update system
log_info "Updating system packages..."
if apt-get update -y && apt-get install -y git curl unzip awscli nginx; then
    log_success "System packages updated successfully"
else
    log_error "Failed to update system packages"
    exit 1
fi

# Install NVM (Node Version Manager)
log_info "Installing NVM (Node Version Manager)..."
if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash; then
    log_success "NVM installed successfully"
else
    log_error "Failed to install NVM"
    exit 1
fi

# Source NVM to make it available in current session
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# Install Node.js 18 via NVM
log_info "Installing Node.js 18 via NVM..."
if nvm install 18 && nvm use 18 && nvm alias default 18; then
    log_success "Node.js 18 installed successfully"
    node --version
    npm --version
else
    log_error "Failed to install Node.js 18"
    exit 1
fi

# Install PM2 globally
log_info "Installing PM2 globally..."
if npm install -g pm2; then
    log_success "PM2 installed successfully"
    pm2 --version
else
    log_error "Failed to install PM2"
    exit 1
fi

# Create app directory as ubuntu user
log_info "Creating application directory..."
sudo -u ubuntu mkdir -p /home/ubuntu/app

# Setup NVM and Node.js as ubuntu user
log_info "Setting up NVM and Node.js for ubuntu user..."
sudo -u ubuntu bash -c '
export NVM_DIR="/home/ubuntu/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source /home/ubuntu/.nvm/nvm.sh
nvm install 18
nvm use 18
nvm alias default 18
npm install -g pm2
echo "Ubuntu user NVM setup completed"
'

# Clone repository to get deployment files
log_info "Cloning repository for deployment files..."
if git clone https://github.com/arcpaladin/email-metrics.git /tmp/temp-repo; then
    log_success "Repository cloned successfully to /tmp/temp-repo"
    
    # List what we have in the repository
    echo "Repository contents:"
    ls -la /tmp/temp-repo/
    echo "Deploy directory contents:"
    ls -la /tmp/temp-repo/deploy/ || echo "Deploy directory not found"
else
    log_error "Failed to clone repository"
    exit 1
fi

# Change ownership of the cloned repo to ubuntu user
chown -R ubuntu:ubuntu /tmp/temp-repo

# Change to app directory and copy files as ubuntu user
log_info "Setting up application files..."
sudo -u ubuntu bash -c '
cd /home/ubuntu/app

# Copy deployment files from the correct path
if [ -f /tmp/temp-repo/deploy/package.json ]; then
    cp /tmp/temp-repo/deploy/package.json .
    echo "✅ Copied package.json"
else
    echo "❌ Warning: package.json not found at /tmp/temp-repo/deploy/"
fi

if [ -f /tmp/temp-repo/deploy/server.js ]; then
    cp /tmp/temp-repo/deploy/server.js .
    echo "✅ Copied server.js"
else
    echo "❌ Warning: server.js not found at /tmp/temp-repo/deploy/"
fi

if [ -f /tmp/temp-repo/deploy/ecosystem.config.js ]; then
    cp /tmp/temp-repo/deploy/ecosystem.config.js .
    echo "✅ Copied ecosystem.config.js"
else
    echo "❌ Warning: ecosystem.config.js not found at /tmp/temp-repo/deploy/"
fi

if [ -f /tmp/temp-repo/deploy/migrate.js ]; then
    cp /tmp/temp-repo/deploy/migrate.js .
    echo "✅ Copied migrate.js"
else
    echo "❌ Warning: migrate.js not found at /tmp/temp-repo/deploy/"
fi

# List files to verify what we copied
echo "📁 Files in app directory after copying:"
ls -la /home/ubuntu/app/

# Verify file contents
echo "📄 Checking if server.js has content:"
if [ -f /home/ubuntu/app/server.js ]; then
    echo "server.js size: \$(wc -c < /home/ubuntu/app/server.js) bytes"
    echo "First few lines of server.js:"
    head -5 /home/ubuntu/app/server.js
else
    echo "❌ server.js not found in app directory"
fi
'

# Create environment file as ubuntu user
log_info "Creating environment file..."
sudo -u ubuntu bash -c '
cd /home/ubuntu/app
cat > .env << ENVEOF
NODE_ENV=production
PORT=3000
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
echo "Environment file created"
'

# Install dependencies and start application as ubuntu user
log_info "Installing dependencies and starting application..."
sudo -u ubuntu bash -c '
cd /home/ubuntu/app
export NVM_DIR="/home/ubuntu/.nvm"
source /home/ubuntu/.nvm/nvm.sh

# Install dependencies
echo "Installing npm dependencies..."
if npm install; then
    echo "Dependencies installed successfully"
else
    echo "Failed to install dependencies"
    exit 1
fi

# Run database migrations
echo "Running database migrations..."
npm run migrate || echo "Migration failed or not needed"

# Start application with PM2
echo "Starting application with PM2..."
if pm2 start ecosystem.config.js; then
    echo "Application started successfully"
    pm2 status
else
    echo "Failed to start application with PM2, trying direct start..."
    pm2 start server.js --name email-analytics
fi

# Setup PM2 startup
pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save
'

# Configure Nginx
log_info "Configuring Nginx..."
PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create Nginx configuration for the application
cat > /etc/nginx/sites-available/email-analytics << NGINXEOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;

    # Main application proxy to port 3000
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:3000/api/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /50x.html {
        root /var/www/html;
    }
}
NGINXEOF

# Enable the site
ln -sf /etc/nginx/sites-available/email-analytics /etc/nginx/sites-enabled/

# Remove default nginx site
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
if nginx -t; then
    log_success "Nginx configuration is valid"
else
    log_error "Nginx configuration is invalid"
    exit 1
fi

# Update application to run on port 3000
log_info "Updating application to run on port 3000..."
sudo -u ubuntu bash -c '
cd /home/ubuntu/app
# Update the .env file to use port 3000
sed -i "s/PORT=80/PORT=3000/g" .env
echo "Updated PORT to 3000 in .env file"

# Restart the application with new port
export NVM_DIR="/home/ubuntu/.nvm"
source /home/ubuntu/.nvm/nvm.sh
pm2 restart email-analytics || pm2 start server.js --name email-analytics --env production
pm2 save
'

# Start and enable nginx
log_info "Starting Nginx..."
if systemctl start nginx && systemctl enable nginx; then
    log_success "Nginx started and enabled successfully"
else
    log_error "Failed to start Nginx"
    exit 1
fi

# Verify nginx is running
if systemctl is-active --quiet nginx; then
    log_success "Nginx is running"
else
    log_error "Nginx is not running"
fi

# Cleanup
log_info "Cleaning up temporary files..."
rm -rf /tmp/temp-repo

echo "✅ Application deployed successfully at \$(date)"
echo "🔗 API URL: http://\$PUBLIC_IP"
echo "📚 API Docs: http://\$PUBLIC_IP/api/docs"
echo "🏥 Health Check: http://\$PUBLIC_IP/health"
echo "🌐 Nginx Status: \$(systemctl is-active nginx)"
echo "📱 Application Port: 3000 (proxied through Nginx on port 80)"
EOF
}

# Cleanup all resources
cleanup_all() {
    print_header "Cleaning Up Backend Resources"

    print_warning "This will delete the Email Analytics backend EC2 instance. Are you sure? (y/N)"
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

    # Delete security groups
    print_info "Deleting security groups..."
    aws ec2 delete-security-group --group-name $EC2_SG_NAME --region $REGION 2>/dev/null && print_status "EC2 security group deleted" || print_warning "EC2 security group not found"

    print_status "Cleanup completed!"
}

# Check resource status
check_resources() {
    print_header "Backend Status Check"

    # Check backend
    if check_backend_exists; then
        local instance_id=$(get_backend_instance_id)
        local public_ip=$(get_backend_public_ip)
        print_status "Backend: Running (ID: $instance_id, IP: $public_ip)"
        print_info "Application URL: http://$public_ip"
        print_info "Health Check: http://$public_ip/api/health"
    else
        print_warning "Backend: Not found"
    fi
}

# Show interactive menu
show_menu() {
    print_header "Email Analytics Backend Deployment Tool"
    echo "1) Deploy backend"
    echo "2) Update backend application"
    echo "3) Check backend status"
    echo "4) Cleanup backend resources"
    echo "5) Exit"
    echo
    echo -n "Please select an option (1-5): "
    read -r choice
    
    case $choice in
        1) deploy_backend ;;
        2) update_backend ;;
        3) check_resources ;;
        4) cleanup_all ;;
        5) exit 0 ;;
        *) print_error "Invalid option. Please try again." && show_menu ;;
    esac
}

# Main execution
main() {
    load_environment
    check_aws_setup

    case "${1:-}" in
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
        "pm2")
            setup_pm2_deployment
            ;;
        "")
            show_menu
            ;;
        *)
            echo "Usage: $0 [backend|update|cleanup|status|pm2]"
            echo
            echo "Modes:"
            echo "  backend   - Deploy EC2 backend application"
            echo "  update    - Update existing backend application code"
            echo "  cleanup   - Delete backend resources"
            echo "  status    - Check backend status"
            echo "  pm2       - Setup PM2 deployment (copy SSH key and update config)"
            echo
            echo "Interactive mode: Run without arguments"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

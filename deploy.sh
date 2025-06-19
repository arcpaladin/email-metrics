#!/bin/bash

# AWS EC2 Deployment for Email Analytics Dashboard with RDS
# Usage: ./deploy.sh [deploy|cleanup]
set -e

COMMAND=${1:-deploy}

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please create one with your configuration."
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

# Function to cleanup resources
cleanup_resources() {
    echo "Cleaning up Email Analytics Dashboard resources..."
    echo "Region: $REGION"
    
    # Terminate EC2 instance
    echo "Finding and terminating EC2 instances..."
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=email-analytics-dashboard" "Name=instance-state-name,Values=running,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region $REGION)
    
    if [ ! -z "$INSTANCE_IDS" ]; then
        echo "Terminating instances: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
        echo "EC2 instances terminated successfully"
    else
        echo "No running EC2 instances found"
    fi
    
    # Delete RDS instance
    echo "Deleting RDS database..."
    aws rds delete-db-instance \
        --db-instance-identifier email-analytics-db \
        --skip-final-snapshot \
        --region $REGION 2>/dev/null || echo "RDS instance not found or already deleted"
    
    # Delete security groups
    echo "Deleting security groups..."
    aws ec2 delete-security-group --group-name email-analytics-web --region $REGION 2>/dev/null || echo "Web security group not found"
    aws ec2 delete-security-group --group-name email-analytics-db --region $REGION 2>/dev/null || echo "DB security group not found"
    
    echo "Cleanup completed!"
    exit 0
}

# Check command
if [ "$COMMAND" = "cleanup" ]; then
    cleanup_resources
fi

echo "Deploying Email Analytics Dashboard with PostgreSQL RDS..."
echo "Region: $REGION"
echo "Database: $DB_NAME"

# Get the latest Ubuntu 22.04 LTS AMI ID for the region
echo "Finding latest Ubuntu 22.04 LTS AMI..."
LATEST_AMI=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region $REGION)

if [ "$LATEST_AMI" != "None" ] && [ ! -z "$LATEST_AMI" ]; then
    echo "Using latest Ubuntu AMI: $LATEST_AMI"
    AMI_ID=$LATEST_AMI
else
    echo "Using configured AMI: $AMI_ID"
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Install it first: https://aws.amazon.com/cli/"
    exit 1
fi

echo "Step 1: Creating database infrastructure..."

# Get VPC info for RDS
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[*].SubnetId' --output text)

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name email-analytics-subnet-group \
    --db-subnet-group-description "Subnet group for Email Analytics RDS" \
    --subnet-ids $SUBNET_IDS \
    --region $REGION 2>/dev/null || true

# Create RDS security group
echo "Creating RDS security group..."
RDS_SG_ID=$(aws ec2 create-security-group \
    --group-name email-analytics-rds \
    --description "RDS PostgreSQL for Email Analytics" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups --group-names email-analytics-rds --region $REGION --query 'SecurityGroups[0].GroupId' --output text)

# Allow PostgreSQL access (will add EC2 security group later)
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --cidr 10.0.0.0/8 \
    --region $REGION 2>/dev/null || true

# Create RDS instance
echo "Creating PostgreSQL database (this takes 5-10 minutes)..."
DB_IDENTIFIER="email-analytics-db"

# Check if database already exists
if aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --region $REGION &>/dev/null; then
    echo "Database instance already exists, skipping creation..."
else
    echo "Creating new database instance..."
    aws rds create-db-instance \
        --db-instance-identifier $DB_IDENTIFIER \
        --db-instance-class $DB_INSTANCE_CLASS \
        --engine postgres \
        --engine-version 15.7 \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --storage-type gp2 \
        --vpc-security-group-ids $RDS_SG_ID \
        --db-subnet-group-name email-analytics-subnet-group \
        --db-name $DB_NAME \
        --backup-retention-period 7 \
        --no-multi-az \
        --publicly-accessible \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo "Database creation initiated successfully"
    else
        echo "Failed to create database instance"
        exit 1
    fi
fi

echo "Waiting for database to be available..."
aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER --region $REGION

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_IDENTIFIER \
    --region $REGION \
    --query 'DBInstances[0].Endpoint.Address' --output text)

echo "Database ready at: $DB_ENDPOINT"

echo "Step 2: Creating EC2 infrastructure..."

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &>/dev/null; then
    echo "Creating key pair..."
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "Key saved as ${KEY_NAME}.pem"
fi

# Create EC2 security group
echo "Creating EC2 security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name email-analytics \
    --description "Email Analytics Dashboard" \
    --region $REGION \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups --group-names email-analytics --region $REGION --query 'SecurityGroups[0].GroupId' --output text)

# Add rules for web server
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || true

# Update RDS security group to allow access from EC2
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --source-group $SG_ID \
    --region $REGION 2>/dev/null || true

echo "Step 3: Deploying application..."

# Create user data script with database connection
cat > userdata.sh << EOF
#!/bin/bash
apt-get update -y
apt-get install -y git postgresql-client-14 curl

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install PM2
npm install -g pm2

# Wait for RDS to be ready
sleep 60

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Set environment variables
export DATABASE_URL="postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/$DB_NAME"
export NODE_ENV=production
export PORT=80

# Create the email analytics application
git clone https://github.com/example/placeholder.git . || true

# Create package.json for the full application
cat > package.json << 'JSONEOF'
{
  "name": "email-analytics",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "build": "echo 'Build complete'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "@neondatabase/serverless": "^0.9.0",
    "drizzle-orm": "^0.29.4",
    "drizzle-zod": "^0.5.1",
    "jsonwebtoken": "^9.0.2",
    "openai": "^4.38.5",
    "ws": "^8.16.0",
    "zod": "^3.22.4",
    "dotenv": "^16.4.5"
  }
}
JSONEOF

# Create environment file with actual database connection
cat > .env << ENVEOF
DATABASE_URL=postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT:5432/$DB_NAME
NODE_ENV=$NODE_ENV
PORT=$PORT
JWT_SECRET=$JWT_SECRET
ENVEOF

# Create basic server with database health check
cat > server.js << 'JSEOF'
const express = require('express');
const { Pool } = require('@neondatabase/serverless');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 80;

// Database connection
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(express.json());
app.use(express.static('public'));

// Health check with database
app.get('/health', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      database: 'connected',
      db_time: result.rows[0].now
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'unhealthy', 
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message
    });
  }
});

// Database setup endpoint
app.post('/setup-db', async (req, res) => {
  try {
    // Create basic tables for email analytics
    await pool.query(\`
      CREATE TABLE IF NOT EXISTS organizations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        domain TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT NOW()
      );
      
      CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        organization_id INTEGER REFERENCES organizations(id),
        email TEXT NOT NULL UNIQUE,
        display_name TEXT,
        department TEXT,
        role TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );
      
      CREATE TABLE IF NOT EXISTS emails (
        id SERIAL PRIMARY KEY,
        message_id TEXT NOT NULL UNIQUE,
        sender_id INTEGER REFERENCES employees(id),
        subject TEXT,
        body_preview TEXT,
        received_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    \`);
    
    res.json({ status: 'Database tables created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Main application page
app.get('*', (req, res) => {
  res.send(\`
    <html>
      <head>
        <title>Email Analytics Dashboard</title>
        <style>
          body { font-family: Arial; margin: 40px; text-align: center; background: #f5f5f5; }
          .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
          .btn { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 10px; text-decoration: none; display: inline-block; }
          .btn:hover { background: #0056b3; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Email Analytics Dashboard</h1>
          <p>Your application is running on EC2 with PostgreSQL RDS!</p>
          <p>Server time: \${new Date().toISOString()}</p>
          <div>
            <a href="/health" class="btn">Health Check</a>
            <button onclick="setupDB()" class="btn">Setup Database</button>
          </div>
          <div id="status"></div>
        </div>
        <script>
          async function setupDB() {
            try {
              const response = await fetch('/setup-db', { method: 'POST' });
              const result = await response.json();
              document.getElementById('status').innerHTML = 
                '<p style="color: green;">Database setup: ' + JSON.stringify(result) + '</p>';
            } catch (error) {
              document.getElementById('status').innerHTML = 
                '<p style="color: red;">Error: ' + error.message + '</p>';
            }
          }
        </script>
      </body>
    </html>
  \`);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(\`Email Analytics Server running on port \${PORT}\`);
  console.log(\`Database: \${process.env.DATABASE_URL ? 'Connected' : 'Not configured'}\`);
});
JSEOF

# Install dependencies
npm install

# Start with PM2
pm2 start server.js --name email-analytics
pm2 startup
pm2 save

echo "✅ Email Analytics application deployed with PostgreSQL RDS"
EOF

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --region $REGION \
    --user-data file://userdata.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=email-analytics}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance ready at: $PUBLIC_IP"

# Cleanup
rm -f userdata.sh

# Save deployment information to .env for future reference
cat >> .env << ENVEOF

# Deployment Information (Generated)
DB_ENDPOINT=$DB_ENDPOINT
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
DEPLOYMENT_DATE=$(date)
ENVEOF

echo "Deployment completed!"
echo
echo "Application: http://$PUBLIC_IP"
echo "Health check: http://$PUBLIC_IP/health"
echo "SSH access: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo
echo "Database Info:"
echo "  Endpoint: $DB_ENDPOINT"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USERNAME"
echo
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Key file: ${KEY_NAME}.pem"
echo
echo "Configuration saved to .env file"
echo "Visit your application and click 'Setup Database' to initialize tables"
#!/bin/bash

# Package Email Analytics Dashboard for EC2 Deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Packaging Email Analytics Dashboard for EC2 deployment..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/email-analytics"

print_status "Creating package directory..."
mkdir -p "$PACKAGE_DIR"

# Copy application files
print_status "Copying application files..."
cp -r server "$PACKAGE_DIR/"
cp -r client "$PACKAGE_DIR/"
cp -r shared "$PACKAGE_DIR/"
cp package.json "$PACKAGE_DIR/"
cp package-lock.json "$PACKAGE_DIR/" 2>/dev/null || true
cp tsconfig.json "$PACKAGE_DIR/"
cp tsconfig.server.json "$PACKAGE_DIR/" 2>/dev/null || true
cp vite.config.ts "$PACKAGE_DIR/"
cp tailwind.config.ts "$PACKAGE_DIR/"
cp postcss.config.js "$PACKAGE_DIR/"
cp components.json "$PACKAGE_DIR/" 2>/dev/null || true
cp drizzle.config.ts "$PACKAGE_DIR/" 2>/dev/null || true

# Copy environment example
cp .env.example "$PACKAGE_DIR/" 2>/dev/null || echo "# Environment variables" > "$PACKAGE_DIR/.env.example"

# Create production package.json
print_status "Creating production package.json..."
cat > "$PACKAGE_DIR/package-prod.json" << 'EOF'
{
  "name": "email-analytics",
  "version": "1.0.0",
  "description": "Email Analytics Dashboard",
  "main": "dist/server/index.js",
  "scripts": {
    "start": "node dist/server/index.js",
    "build": "npm run build:client && npm run build:server",
    "build:client": "vite build",
    "build:server": "tsc --project tsconfig.server.json",
    "postinstall": "npm run build"
  },
  "dependencies": {
    "@azure/msal-browser": "^3.11.1",
    "@azure/msal-react": "^2.0.15",
    "@microsoft/microsoft-graph-client": "^3.0.7",
    "@neondatabase/serverless": "^0.9.0",
    "@radix-ui/react-alert-dialog": "^1.0.5",
    "@radix-ui/react-avatar": "^1.0.4",
    "@radix-ui/react-button": "^1.0.4",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-dropdown-menu": "^2.0.6",
    "@radix-ui/react-label": "^2.0.2",
    "@radix-ui/react-popover": "^1.0.7",
    "@radix-ui/react-select": "^2.0.0",
    "@radix-ui/react-separator": "^1.0.3",
    "@radix-ui/react-slot": "^1.0.2",
    "@radix-ui/react-tabs": "^1.0.4",
    "@radix-ui/react-toast": "^1.1.5",
    "@radix-ui/react-tooltip": "^1.0.7",
    "@tanstack/react-query": "^5.28.9",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "date-fns": "^3.6.0",
    "dotenv": "^16.4.5",
    "drizzle-orm": "^0.29.4",
    "drizzle-zod": "^0.5.1",
    "express": "^4.19.2",
    "express-session": "^1.18.0",
    "framer-motion": "^11.0.24",
    "jsonwebtoken": "^9.0.2",
    "lucide-react": "^0.365.0",
    "openai": "^4.38.5",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-hook-form": "^7.51.2",
    "recharts": "^2.12.6",
    "tailwind-merge": "^2.2.2",
    "tailwindcss-animate": "^1.0.7",
    "wouter": "^3.1.0",
    "ws": "^8.16.0",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/express-session": "^1.18.0",
    "@types/jsonwebtoken": "^9.0.6",
    "@types/node": "^20.12.7",
    "@types/react": "^18.2.79",
    "@types/react-dom": "^18.2.23",
    "@types/ws": "^8.5.10",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.3",
    "tsx": "^4.7.2",
    "typescript": "^5.4.5",
    "vite": "^5.2.8"
  }
}
EOF

# Create deployment scripts
print_status "Creating deployment scripts..."

# Create start script
cat > "$PACKAGE_DIR/start.sh" << 'EOF'
#!/bin/bash
cd /opt/email-analytics
export NODE_ENV=production
export PORT=5000
node dist/server/index.js
EOF

chmod +x "$PACKAGE_DIR/start.sh"

# Create PM2 ecosystem file
cat > "$PACKAGE_DIR/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [{
    name: 'email-analytics',
    script: './start.sh',
    cwd: '/opt/email-analytics',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: '/var/log/email-analytics-error.log',
    out_file: '/var/log/email-analytics-out.log',
    log_file: '/var/log/email-analytics.log',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    autorestart: true,
    max_restarts: 10,
    restart_delay: 5000
  }]
};
EOF

# Create deployment instructions
cat > "$PACKAGE_DIR/DEPLOYMENT.md" << 'EOF'
# Email Analytics Dashboard - EC2 Deployment

## Prerequisites
- AWS EC2 instance (t3.micro or larger)
- Node.js 18+
- PM2 process manager
- Nginx web server

## Deployment Steps

1. Upload this package to your EC2 instance:
   ```bash
   scp -i your-key.pem email-analytics.tar.gz ec2-user@your-instance-ip:/tmp/
   ```

2. SSH into your EC2 instance:
   ```bash
   ssh -i your-key.pem ec2-user@your-instance-ip
   ```

3. Run the setup script:
   ```bash
   bash /tmp/ec2-setup.sh
   ```

4. Configure environment variables in `/opt/email-analytics/.env`:
   ```
   DATABASE_URL=your_postgresql_database_url
   OPENAI_API_KEY=your_openai_api_key
   VITE_AZURE_CLIENT_ID=your_azure_client_id
   VITE_AZURE_TENANT_ID=your_azure_tenant_id
   JWT_SECRET=your_jwt_secret
   ```

5. Restart the application:
   ```bash
   cd /opt/email-analytics
   pm2 restart email-analytics
   ```

## Management Commands

- View application status: `pm2 status`
- View logs: `pm2 logs email-analytics`
- Restart application: `pm2 restart email-analytics`
- Stop application: `pm2 stop email-analytics`

## URLs
- Application: http://your-instance-ip/
- Dashboard: http://your-instance-ip/dashboard

## Troubleshooting

If the application doesn't start:
1. Check PM2 logs: `pm2 logs email-analytics`
2. Check Nginx status: `sudo systemctl status nginx`
3. Verify environment variables are set correctly
4. Ensure database is accessible from the EC2 instance
EOF

# Create tarball
print_status "Creating deployment package..."
cd "$TEMP_DIR"
tar -czf email-analytics.tar.gz email-analytics/

# Move to current directory
mv email-analytics.tar.gz "$(pwd)/email-analytics.tar.gz"

# Cleanup
rm -rf "$TEMP_DIR"

print_status "Package created: email-analytics.tar.gz"
print_warning "Don't forget to:"
print_warning "1. Set up your environment variables"
print_warning "2. Configure your database connection"
print_warning "3. Set up Azure app registration for the domain"

echo
print_status "To deploy to EC2:"
echo "1. Run: chmod +x deploy-ec2.sh && ./deploy-ec2.sh"
echo "2. Upload package: scp -i your-key.pem email-analytics.tar.gz ec2-user@your-instance-ip:/tmp/"
echo "3. Run setup: ssh -i your-key.pem ec2-user@your-instance-ip 'bash /tmp/ec2-setup.sh'"
# Email Analytics Dashboard - AWS EC2 Deployment Guide

## Overview
This guide walks you through deploying the Email Analytics Dashboard on AWS EC2 using a simple, cost-effective setup.

## Prerequisites

### AWS Requirements
- AWS CLI installed and configured
- AWS account with EC2 permissions
- jq installed for JSON parsing

### Application Requirements
- PostgreSQL database (recommend AWS RDS)
- OpenAI API key
- Microsoft Azure app registration

## Quick Deployment

### Step 1: Package the Application
```bash
./package-for-ec2.sh
```
This creates `email-analytics.tar.gz` with all necessary files.

### Step 2: Deploy EC2 Infrastructure
```bash
./deploy-ec2.sh
```

Optional parameters:
- `--region us-west-2` (default: us-east-1)
- `--instance-type t3.small` (default: t3.micro)
- `--key-name my-key` (default: email-analytics-key)

### Step 3: Upload Application Package
```bash
# Replace with your instance IP from deployment output
scp -i email-analytics-key.pem email-analytics.tar.gz ec2-user@YOUR_INSTANCE_IP:/tmp/
```

### Step 4: Setup Application
```bash
# SSH into instance
ssh -i email-analytics-key.pem ec2-user@YOUR_INSTANCE_IP

# Copy and run setup script
sudo cp /tmp/ec2-setup.sh /tmp/
chmod +x /tmp/ec2-setup.sh
/tmp/ec2-setup.sh
```

### Step 5: Configure Environment Variables
```bash
# Edit environment file
sudo nano /opt/email-analytics/.env
```

Add your configuration:
```env
DATABASE_URL=postgresql://username:password@your-rds-endpoint:5432/database
OPENAI_API_KEY=sk-your-openai-key
VITE_AZURE_CLIENT_ID=your-azure-client-id
VITE_AZURE_TENANT_ID=your-azure-tenant-id
JWT_SECRET=your-random-jwt-secret
NODE_ENV=production
PORT=5000
```

### Step 6: Start the Application
```bash
cd /opt/email-analytics
pm2 restart email-analytics
```

## Configuration Details

### Azure App Registration
Update your Azure app registration redirect URIs to include:
- `http://YOUR_INSTANCE_IP/`
- `https://YOUR_INSTANCE_IP/` (if using HTTPS)

### Database Setup
If using AWS RDS:
1. Create PostgreSQL instance
2. Configure security group to allow EC2 access
3. Note connection details for environment variables

### Security Group Configuration
The deployment script creates these inbound rules:
- Port 22 (SSH): 0.0.0.0/0
- Port 80 (HTTP): 0.0.0.0/0
- Port 443 (HTTPS): 0.0.0.0/0
- Port 5000 (App): 0.0.0.0/0

## Management Commands

### Application Management
```bash
# Check application status
pm2 status

# View logs
pm2 logs email-analytics

# Restart application
pm2 restart email-analytics

# Stop application
pm2 stop email-analytics
```

### System Management
```bash
# Check Nginx status
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx

# View system logs
sudo journalctl -u nginx -f
```

## Troubleshooting

### Application Won't Start
1. Check PM2 logs: `pm2 logs email-analytics`
2. Verify environment variables: `cat /opt/email-analytics/.env`
3. Check database connectivity
4. Ensure all dependencies are installed

### Authentication Issues
1. Verify Azure app registration redirect URIs
2. Check Azure client ID and tenant ID
3. Ensure HTTPS is properly configured for production

### Database Connection Issues
1. Verify DATABASE_URL format
2. Check security group allows database access
3. Test connection manually: `psql $DATABASE_URL`

### Nginx Issues
1. Check configuration: `sudo nginx -t`
2. View error logs: `sudo tail -f /var/log/nginx/error.log`
3. Ensure port 80/443 are open in security group

## Monitoring and Maintenance

### Health Checks
- Application health: `curl http://YOUR_INSTANCE_IP/api/health`
- PM2 monitoring: `pm2 monit`

### Log Rotation
PM2 handles log rotation automatically. Logs are stored in:
- `/var/log/email-analytics.log`
- `/var/log/email-analytics-error.log`
- `/var/log/email-analytics-out.log`

### Backup Strategy
1. Database: Use RDS automated backups
2. Application: Version control with Git
3. Configuration: Backup `.env` file securely

## Scaling Considerations

### Vertical Scaling
Upgrade instance type:
```bash
# Stop instance
aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID

# Modify instance type
aws ec2 modify-instance-attribute --instance-id YOUR_INSTANCE_ID --instance-type Value=t3.small

# Start instance
aws ec2 start-instances --instance-ids YOUR_INSTANCE_ID
```

### Horizontal Scaling
For high availability:
1. Use Application Load Balancer
2. Deploy multiple instances across AZs
3. Use RDS Multi-AZ for database
4. Consider Auto Scaling Groups

## Cost Optimization

### Instance Sizing
- t3.micro: Development/testing
- t3.small: Small production (<100 users)
- t3.medium: Medium production (<500 users)

### Reserved Instances
Consider 1-year reserved instances for production to save ~30% on costs.

## Security Best Practices

1. **Network Security**
   - Restrict SSH access to your IP only
   - Use VPC with private subnets for database
   - Enable VPC Flow Logs

2. **Application Security**
   - Use strong JWT secrets
   - Enable HTTPS in production
   - Regular security updates

3. **Access Management**
   - Use IAM roles instead of access keys
   - Enable CloudTrail logging
   - Regular access reviews

## Support

For issues:
1. Check application logs
2. Review troubleshooting section
3. Verify environment configuration
4. Test individual components
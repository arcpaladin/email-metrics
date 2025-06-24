# PM2 Deployment Troubleshooting Guide

## 🚨 **Problem: SSH Connection Timeout**

You're seeing this error when running `pm2 deploy production update`:
```
ssh: connect to host 3.129.68.100 port 22: Operation timed out
fetch failed
Deploy failed with exit code: 1
```

This indicates PM2 cannot connect to your EC2 instance via SSH.

## 🔍 **Root Causes**

### **1. EC2 Instance Issues**
- ✅ **Instance stopped/terminated**
- ✅ **Security group blocking SSH (port 22)**
- ✅ **Instance IP address changed**
- ✅ **Network connectivity issues**

### **2. SSH Key Issues**
- ✅ **Missing SSH key file locally**
- ✅ **Incorrect key permissions**
- ✅ **Key file path mismatch**

### **3. Network Issues**
- ✅ **Firewall blocking outbound SSH**
- ✅ **VPN/proxy interference**
- ✅ **Internet connectivity problems**

## ✅ **Quick Diagnostic Steps**

### **Step 1: Check EC2 Instance Status**
```bash
# Check if instance is running
./deploy.sh status

# Or check directly with AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=email-analytics-backend" \
  --region us-east-2 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```

### **Step 2: Test SSH Connection Manually**
```bash
# Test SSH connection directly
ssh -i email-analytics.pem ubuntu@3.129.68.100

# Test with verbose output for debugging
ssh -v -i email-analytics.pem ubuntu@3.129.68.100
```

### **Step 3: Check SSH Key**
```bash
# Verify key file exists and has correct permissions
ls -la email-analytics.pem
# Should show: -r-------- (400 permissions)

# Fix permissions if needed
chmod 400 email-analytics.pem
```

## 🛠️ **Solutions**

### **Solution 1: Restart EC2 Instance**
```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=email-analytics-backend" \
  --region us-east-2 \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

# Restart the instance
aws ec2 reboot-instances --instance-ids $INSTANCE_ID --region us-east-2

# Wait for it to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-east-2

# Get new IP address
NEW_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region us-east-2 \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text)

echo "New IP: $NEW_IP"
```

### **Solution 2: Update Ecosystem Config with New IP**
```bash
# Update ecosystem config with current IP
./deploy.sh pm2

# Or manually update deploy/ecosystem.config.js
# Replace the host IP with the current one
```

### **Solution 3: Check Security Group**
```bash
# Get security group ID
SG_ID=$(aws ec2 describe-security-groups \
  --group-names email-analytics-ec2-sg \
  --region us-east-2 \
  --query 'SecurityGroups[].GroupId' \
  --output text)

# Check SSH rule exists
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region us-east-2 \
  --query 'SecurityGroups[].IpPermissions[?FromPort==`22`]'

# Add SSH rule if missing
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region us-east-2
```

### **Solution 4: Recreate SSH Key**
```bash
# Delete existing key pair
aws ec2 delete-key-pair --key-name email-analytics --region us-east-2

# Remove local key file
rm -f email-analytics.pem

# Redeploy to create new key
./deploy.sh backend

# Setup PM2 deployment again
./deploy.sh pm2
```

### **Solution 5: Use Alternative Access Methods**

#### **AWS Systems Manager (No SSH needed)**
```bash
# Connect via Systems Manager
aws ssm start-session --target $INSTANCE_ID --region us-east-2

# Once connected, you can manage the app directly
sudo su - ubuntu
cd /home/ubuntu/app
pm2 status
pm2 restart email-analytics
```

#### **Manual Deployment via Systems Manager**
```bash
# Connect to instance
aws ssm start-session --target $INSTANCE_ID --region us-east-2

# Update application manually
sudo su - ubuntu
cd /home/ubuntu/app
git pull origin main
npm install
pm2 restart email-analytics
```

## 🔄 **Complete Recovery Procedure**

If all else fails, here's a complete recovery process:

### **Step 1: Clean Slate**
```bash
# Clean up everything
./deploy.sh cleanup

# Wait for cleanup to complete
sleep 30
```

### **Step 2: Redeploy**
```bash
# Deploy fresh infrastructure
./deploy.sh backend

# This will create:
# - New EC2 instance
# - New SSH key
# - Fresh application deployment
```

### **Step 3: Setup PM2**
```bash
# Setup PM2 deployment
./deploy.sh pm2

# Test PM2 deployment
pm2 deploy production setup
pm2 deploy production
```

## 📋 **Verification Steps**

After fixing the issue, verify everything works:

### **1. Test SSH Connection**
```bash
ssh -i email-analytics.pem ubuntu@$(./deploy.sh status | grep "Public IP" | awk '{print $3}')
```

### **2. Test PM2 Deployment**
```bash
pm2 deploy production update
```

### **3. Check Application**
```bash
# Get current IP
CURRENT_IP=$(./deploy.sh status | grep "Public IP" | awk '{print $3}')

# Test API
curl http://$CURRENT_IP/api/health
```

## 💡 **Prevention Tips**

### **1. Use Elastic IP**
Consider using an Elastic IP to prevent IP address changes:
```bash
# Allocate Elastic IP
aws ec2 allocate-address --region us-east-2

# Associate with instance
aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $ALLOCATION_ID \
  --region us-east-2
```

### **2. Regular Health Checks**
```bash
# Add to crontab for regular checks
echo "*/5 * * * * curl -s http://YOUR_IP/api/health || echo 'API Down'" | crontab -
```

### **3. Backup SSH Keys**
```bash
# Backup your SSH key
cp email-analytics.pem email-analytics.pem.backup
```

## 🆘 **Emergency Access**

If you can't access via SSH at all:

### **Option 1: AWS Console**
1. Go to EC2 Console
2. Select your instance
3. Actions → Connect → Session Manager
4. Connect directly through browser

### **Option 2: Instance Connect**
1. Go to EC2 Console
2. Select your instance
3. Actions → Connect → EC2 Instance Connect
4. Connect with temporary key

### **Option 3: Recovery Instance**
1. Stop the instance
2. Detach the EBS volume
3. Attach to a recovery instance
4. Fix issues and reattach

## 📞 **Getting Help**

If you're still stuck:

1. **Check AWS Status**: https://status.aws.amazon.com/
2. **Review CloudTrail logs** for any API errors
3. **Check VPC Flow Logs** for network issues
4. **Contact AWS Support** if it's an infrastructure issue

Remember: The deploy script (`./deploy.sh`) is your friend - it can recreate everything from scratch if needed!

# Deployment Monitoring Guide

## 📋 All Issues Fixed

### ✅ **1. Removed sudo from deploy.sh**
- Ubuntu user now properly owns all application files
- PM2 processes run under ubuntu user
- No permission issues with app files

### ✅ **2. Fixed 0.0.0.0 binding in deploy/server.js**
- Server now binds to `127.0.0.1` instead of `0.0.0.0`
- More secure deployment configuration
- Added comprehensive logging

### ✅ **3. Added comprehensive deployment logging**
- All deployment steps are logged with timestamps
- Logs saved to `/var/log/user-data.log` on EC2 instance
- Success/error tracking for each step

## 🔍 How to Monitor Deployment

### **1. Check Deployment Logs**
```bash
# Get your instance ID
./deploy.sh status

# Connect to instance
aws ssm start-session --target INSTANCE_ID --region us-east-2

# View deployment logs
sudo tail -f /var/log/user-data.log

# Or view complete log
sudo cat /var/log/user-data.log
```

### **2. Check Application Status**
```bash
# On the EC2 instance (as ubuntu user)
pm2 status
pm2 logs email-analytics
pm2 monit

# Check if app is responding
curl http://localhost/api/health
```

### **3. Check System Resources**
```bash
# Memory and CPU usage
htop

# Disk usage
df -h

# Network connections
netstat -tlnp
```

## 📊 Log Structure

The deployment log includes:

```
=========================================
Email Analytics Backend Deployment Log
Started at: [timestamp]
Instance ID: i-xxxxx
Public IP: x.x.x.x
=========================================

[timestamp] INFO: Updating system packages...
[timestamp] SUCCESS: System packages updated successfully
[timestamp] INFO: Installing NVM...
[timestamp] SUCCESS: NVM installed successfully
[timestamp] INFO: Installing Node.js 18...
[timestamp] SUCCESS: Node.js 18 installed successfully
[timestamp] INFO: Installing PM2...
[timestamp] SUCCESS: PM2 installed successfully
...
✅ Application deployed successfully at [timestamp]
🔗 API URL: http://x.x.x.x
📚 API Docs: http://x.x.x.x/api/docs
```

## 🚨 Troubleshooting

### **If deployment fails:**

1. **Check the logs:**
   ```bash
   sudo cat /var/log/user-data.log | grep ERROR
   ```

2. **Common issues and solutions:**
   - **NVM installation fails**: Network connectivity issue
   - **Node.js installation fails**: Try different Node version
   - **PM2 startup fails**: Check if app files exist
   - **Database connection fails**: Verify DATABASE_URL

3. **Manual recovery:**
   ```bash
   # Switch to ubuntu user
   sudo su - ubuntu
   
   # Navigate to app directory
   cd /home/ubuntu/app
   
   # Check if files exist
   ls -la
   
   # Manually start if needed
   source ~/.nvm/nvm.sh
   npm install
   pm2 start server.js --name email-analytics
   ```

## 🎯 Verification Steps

After deployment, verify:

1. **Instance is running:**
   ```bash
   ./deploy.sh status
   ```

2. **Application is responding:**
   ```bash
   curl http://YOUR_IP/api/health
   ```

3. **PM2 is managing the app:**
   ```bash
   # On EC2 instance
   pm2 status
   ```

4. **Logs are clean:**
   ```bash
   pm2 logs email-analytics --lines 50
   ```

## 📝 Access Your Applications

- **As ubuntu user**: All PM2 commands, app files, logs
- **File permissions**: Properly set for ubuntu user
- **No sudo needed**: For application management

The deployment is now fully monitored and all issues have been resolved!

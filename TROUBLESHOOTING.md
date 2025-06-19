# App Runner Deployment Troubleshooting

## Web ACL Association Error

**Error:** "Web ACLs are not available for the selected service arn:aws:apprunner:... because the service does not exist or is in an invalid state for association"

### Root Causes:
1. **Service in transitional state** - Service is being created/updated/deleted
2. **Service creation failed** - Authentication or configuration issues
3. **Wrong region** - Web ACL and service must be in same region
4. **Service deleted** - Service was removed but AWS console cached old data

### Resolution Steps:

#### 1. Check Service Status
```bash
./find-apprunner-service.sh
```

#### 2. If Service Exists but Status is Not RUNNING:
- Wait for service to reach RUNNING state
- If status is CREATE_FAILED or DELETE_FAILED, delete and recreate
- Check CloudWatch logs for detailed error messages

#### 3. If Service Not Found:
Run deployment to create new service:
```bash
./deploy-aws.sh
```

#### 4. Region Mismatch:
Ensure Web ACL configuration is in same region as App Runner service (us-east-2)

## Common App Runner Issues

### Authentication Configuration Invalid
**Fix:** IAM role with ECR access permissions automatically created by deployment script

### Docker Build Failures
**Symptoms:** Service stuck in CREATE_FAILED
**Fix:** 
- Check ECR repository exists
- Verify Docker image was pushed successfully
- Review build logs in deployment output

### Health Check Failures
**Symptoms:** Service starts but health checks fail
**Fix:**
- Verify `/api/health` endpoint responds with 200
- Check application logs in CloudWatch
- Ensure environment variables are set correctly

### Database Connection Issues
**Symptoms:** Application starts but crashes on database operations
**Fix:**
- Verify RDS instance is accessible
- Check DATABASE_URL format: `postgresql://dbadmin:password@endpoint:5432/emailanalytics`
- Ensure security groups allow App Runner access

## Deployment Best Practices

1. **Single Region:** Keep all resources (RDS, ECR, App Runner) in same region
2. **IAM Permissions:** Ensure deployment role has sufficient permissions
3. **Resource Cleanup:** Delete failed services before recreating
4. **Monitoring:** Check CloudWatch logs for detailed error information

## Quick Recovery

If deployment completely fails:
1. Delete all resources: RDS, ECR, App Runner, IAM roles
2. Wait 5 minutes for AWS eventual consistency
3. Re-run deployment script
4. Monitor each step for errors
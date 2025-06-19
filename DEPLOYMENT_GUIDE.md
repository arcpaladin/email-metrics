# Email Analytics Dashboard - AWS Deployment Guide

## Overview
This guide covers deploying the email analytics dashboard to AWS using Amplify for the frontend and App Runner for the backend API.

## Prerequisites
- AWS CLI configured with appropriate permissions
- Docker installed
- Azure App Registration configured
- OpenAI API key (optional, for AI features)

## Quick Deployment

### Option 1: Automated Deployment
```bash
./deploy-simple.sh
```

### Option 2: Manual Deployment Steps

#### 1. Database Setup (RDS PostgreSQL)
```bash
# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier email-analytics-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username dbadmin \
    --master-user-password [SECURE_PASSWORD] \
    --allocated-storage 20 \
    --db-name emailanalytics \
    --publicly-accessible \
    --region us-east-1

# Wait for availability
aws rds wait db-instance-available \
    --db-instance-identifier email-analytics-db \
    --region us-east-1
```

#### 2. Backend API (App Runner)
```bash
# Create ECR repository
aws ecr create-repository \
    --repository-name email-analytics-backend \
    --region us-east-1

# Build and push Docker image
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

docker build -t email-analytics-backend .
docker tag email-analytics-backend:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/email-analytics-backend:latest
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/email-analytics-backend:latest

# Create App Runner service
aws apprunner create-service \
    --cli-input-json file://apprunner-config.json \
    --region us-east-1
```

#### 3. Frontend (Amplify)
```bash
# Deploy using Amplify Console or CLI
amplify init
amplify add hosting
amplify publish
```

## Environment Variables

### Backend (App Runner)
Required environment variables for the backend service:

```json
{
    "NODE_ENV": "production",
    "PORT": "5000",
    "DATABASE_URL": "postgresql://dbadmin:[PASSWORD]@[RDS_ENDPOINT]:5432/emailanalytics",
    "JWT_SECRET": "production-jwt-secret-2024",
    "OPENAI_API_KEY": "[YOUR_OPENAI_KEY]"
}
```

### Frontend (Amplify)
Required environment variables for the frontend:

```
VITE_API_URL=https://[APP_RUNNER_URL]
VITE_AZURE_CLIENT_ID=[YOUR_AZURE_CLIENT_ID]
VITE_AZURE_TENANT_ID=[YOUR_AZURE_TENANT_ID]
```

## Post-Deployment Configuration

### 1. Azure App Registration
Update your Azure app registration with the deployed URLs:

**Redirect URIs:**
- `https://[AMPLIFY_URL]/`
- `https://[AMPLIFY_URL]`

**API Permissions:**
- Microsoft Graph > User.Read (Delegated)
- Microsoft Graph > Mail.Read (Delegated)

### 2. Database Migration
The database schema will be automatically created when the backend starts. No manual migration required.

### 3. Health Checks
Verify deployment:
- Backend health: `https://[APP_RUNNER_URL]/api/health`
- Frontend: `https://[AMPLIFY_URL]`

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Amplify       │    │   App Runner    │    │   RDS Postgres  │
│   (Frontend)    │───▶│   (Backend API) │───▶│   (Database)    │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │                       ▼
         │              ┌─────────────────┐
         │              │  Microsoft      │
         └─────────────▶│  Graph API      │
                        │  (Azure)        │
                        └─────────────────┘
```

## Troubleshooting

### Common Issues

1. **App Runner Health Check Failures**
   - Verify `/api/health` endpoint responds with 200 status
   - Check environment variables are properly set
   - Review CloudWatch logs for errors

2. **Frontend API Connection Issues**
   - Ensure `VITE_API_URL` points to correct App Runner URL
   - Verify CORS settings in backend
   - Check network connectivity

3. **Authentication Issues**
   - Confirm Azure redirect URIs match deployed URLs
   - Verify Azure app permissions are granted
   - Check MSAL configuration

4. **Database Connection Errors**
   - Verify RDS instance is publicly accessible
   - Check security group rules
   - Confirm DATABASE_URL format is correct

### Logs and Monitoring

- **Backend Logs:** AWS CloudWatch (App Runner service logs)
- **Frontend Logs:** Browser developer console
- **Database Logs:** RDS CloudWatch logs

## Cost Estimation

Monthly costs (approximate):
- RDS t3.micro: $15-20
- App Runner: $20-30 (depending on usage)
- Amplify: $1-5 (depending on traffic)
- **Total: ~$35-55/month**

## Security Considerations

1. **Database Security**
   - Use strong passwords
   - Enable encryption at rest
   - Restrict network access

2. **API Security**
   - JWT tokens with secure secrets
   - HTTPS only
   - Rate limiting (future enhancement)

3. **Frontend Security**
   - Azure MSAL for authentication
   - Secure token storage
   - HTTPS enforcement

## Support

For deployment issues:
1. Check CloudWatch logs
2. Verify environment variables
3. Test health endpoints
4. Review Azure configuration
# Fix AWS Permissions for Deployment

## Issue
Your AWS IAM user lacks the necessary permissions to create RDS instances and other AWS resources needed for deployment.

## Quick Fix Options

### Option 1: Create IAM Policy (Recommended)

1. **Create the policy:**
```bash
aws iam create-policy \
    --policy-name EmailAnalyticsDeploymentPolicy \
    --policy-document file://aws-iam-policy.json
```

2. **Attach policy to your user:**
```bash
aws iam attach-user-policy \
    --user-name Tim \
    --policy-arn arn:aws:iam::331409392797:policy/EmailAnalyticsDeploymentPolicy
```

### Option 2: Use AWS Console

1. Go to AWS IAM Console
2. Navigate to Policies → Create Policy
3. Copy the JSON from `aws-iam-policy.json`
4. Create policy named "EmailAnalyticsDeploymentPolicy"
5. Attach policy to user "Tim"

### Option 3: Use Administrator Access (Quick but Less Secure)

```bash
aws iam attach-user-policy \
    --user-name Tim \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## Alternative: Use Different AWS Services

If you can't get RDS permissions, modify the deployment to use:

### Option A: Use Neon Database (External)
- Keep your existing Neon PostgreSQL database
- Only deploy frontend to Amplify and backend to App Runner
- No RDS permissions needed

### Option B: Use DynamoDB Instead
- Replace PostgreSQL with DynamoDB (NoSQL)
- Requires code changes but simpler permissions
- Lower cost and serverless

## Modified Deployment Script

I'll create a version that skips RDS if permissions are missing:
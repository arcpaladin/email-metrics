# Email Analytics Dashboard - Deployment Guide

This guide covers the modern deployment setup for the Email Analytics Dashboard with separated frontend and backend deployments.

## Architecture Overview

- **Frontend**: Deployed on Vercel with automatic CI/CD
- **Backend**: Deployed on AWS EC2 with Swagger documentation
- **Database**: Neon PostgreSQL (serverless)

## Prerequisites

1. **GitHub Repository**: Your code should be in a GitHub repository
2. **Vercel Account**: For frontend deployment
3. **AWS Account**: For backend deployment
4. **Neon Database**: PostgreSQL database (you already have this)

## Quick Start

### 1. Frontend Deployment (Vercel)

1. **Connect to Vercel**:
   - Go to [vercel.com](https://vercel.com)
   - Import your GitHub repository
   - Select the `client` folder as the root directory

2. **Environment Variables**:
   Copy the variables from `.env.example.vercel` to your Vercel project settings:
   ```bash
   VITE_API_URL=http://your-ec2-public-ip
   VITE_MICROSOFT_CLIENT_ID=your-microsoft-client-id
   VITE_MICROSOFT_TENANT_ID=your-microsoft-tenant-id
   VITE_MICROSOFT_REDIRECT_URI=https://your-app.vercel.app/auth/callback
   ```

3. **Deploy**:
   - Vercel will automatically deploy on every push to main branch
   - Preview deployments are created for pull requests

### 2. Backend Deployment (AWS)

1. **Update Environment Variables**:
   Update your `.env` file with Neon database connection and other settings:
   ```bash
   # Copy from .env.example and update with your values
   DATABASE_URL=postgresql://username:password@ep-xxx.us-east-1.aws.neon.tech/dbname?sslmode=require
   JWT_SECRET=your-jwt-secret
   FRONTEND_URL=https://your-app.vercel.app
   # ... other variables
   ```

2. **Deploy Backend**:
   ```bash
   # Deploy complete infrastructure
   ./deploy.sh full
   
   # Or deploy only backend (if database exists)
   ./deploy.sh backend
   ```

3. **Access Your API**:
   - API URL: `http://your-ec2-public-ip`
   - API Documentation: `http://your-ec2-public-ip/api/docs`
   - Health Check: `http://your-ec2-public-ip/api/health`

## CI/CD Setup

### GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

#### Vercel Secrets
```
VERCEL_TOKEN=your-vercel-token
VERCEL_ORG_ID=your-vercel-org-id
VERCEL_PROJECT_ID=your-vercel-project-id
VITE_API_URL=http://your-ec2-public-ip
VITE_MICROSOFT_CLIENT_ID=your-microsoft-client-id
VITE_MICROSOFT_TENANT_ID=your-microsoft-tenant-id
VITE_MICROSOFT_REDIRECT_URI=https://your-app.vercel.app/auth/callback
```

#### AWS Secrets
```
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_REGION=us-east-1
S3_DEPLOYMENT_BUCKET=your-s3-bucket-name
DATABASE_URL=your-neon-database-url
JWT_SECRET=your-jwt-secret
FRONTEND_URL=https://your-app.vercel.app
API_URL=http://your-ec2-public-ip
MICROSOFT_CLIENT_ID=your-microsoft-client-id
MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret
MICROSOFT_TENANT_ID=your-microsoft-tenant-id
OPENAI_API_KEY=your-openai-api-key
SESSION_SECRET=your-session-secret
```

### Automatic Deployments

Once secrets are configured:

1. **Frontend**: Automatically deploys to Vercel on push to main
2. **Backend**: Automatically deploys to AWS on push to main
3. **Preview Deployments**: Created for pull requests

## File Structure

```
email-metrics/
├── client/                 # Frontend React app
├── server/                 # Backend TypeScript server
├── shared/                 # Shared types and utilities
├── deploy/                 # Production deployment files
│   ├── package.json        # Production dependencies
│   ├── server.js          # Production server entry point
│   ├── ecosystem.config.js # PM2 configuration
│   ├── migrate.js         # Database migration script
│   └── .env.production    # Environment template
├── .github/workflows/     # CI/CD pipelines
│   ├── frontend.yml       # Vercel deployment
│   └── backend.yml        # AWS deployment
├── vercel.json            # Vercel configuration
├── .env.example.vercel    # Frontend environment template
└── deploy.sh              # AWS deployment script
```

## Key Improvements

### ✅ What's Fixed

1. **No More Dynamic File Generation**: All files are now real, version-controlled files
2. **Swagger Documentation**: Professional API docs at `/api/docs`
3. **Proper Environment Management**: Separate frontend/backend configurations
4. **CI/CD Pipeline**: Automatic deployments on git push
5. **Neon Integration**: Uses your existing Neon database
6. **Production Ready**: PM2 process management, proper error handling

### 🚀 Benefits

- **Faster Deployments**: Vercel handles frontend optimization
- **Better Developer Experience**: Preview deployments for every PR
- **Cleaner Separation**: Frontend and backend deployed independently
- **Professional API**: Swagger documentation for your API
- **Easier Maintenance**: No more complex deploy script file generation

## Deployment Commands

```bash
# Check current status
./deploy.sh status

# Deploy everything (first time)
./deploy.sh full

# Deploy only backend
./deploy.sh backend

# Update existing backend
./deploy.sh update

# Clean up all resources
./deploy.sh cleanup
```

## Troubleshooting

### Frontend Issues
- Check Vercel deployment logs
- Verify environment variables in Vercel dashboard
- Ensure API URL is correct and accessible

### Backend Issues
- Check EC2 instance logs: `ssh -i key.pem ubuntu@ip "pm2 logs"`
- Verify database connection: `curl http://ip/api/health`
- Check API documentation: `http://ip/api/docs`

### Database Issues
- Verify Neon connection string
- Check database migrations: `npm run migrate`
- Test connection: `psql $DATABASE_URL`

## Support

For issues or questions:
1. Check the deployment logs
2. Verify all environment variables are set correctly
3. Test each component individually (database, backend, frontend)
4. Review the GitHub Actions workflow runs for CI/CD issues

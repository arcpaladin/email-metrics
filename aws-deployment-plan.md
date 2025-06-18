# AWS Deployment Plan - Email Analytics Dashboard

## Architecture Overview

### Frontend (React + Vite)
- **Service**: AWS Amplify or S3 + CloudFront
- **Domain**: Custom domain with SSL certificate
- **CDN**: CloudFront for global distribution

### Backend (Express.js + Node.js)
- **Service**: AWS App Runner or Elastic Beanstalk
- **Database**: Amazon RDS (PostgreSQL)
- **File Storage**: S3 (if needed for attachments)
- **Load Balancer**: Application Load Balancer (ALB)

### Additional Services
- **Authentication**: Existing MSAL integration
- **API Gateway**: Optional for rate limiting and monitoring
- **CloudWatch**: Logging and monitoring
- **Route 53**: DNS management
- **Certificate Manager**: SSL certificates

## Deployment Steps

### 1. Database Setup (Amazon RDS PostgreSQL)

```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
    --db-instance-identifier email-analytics-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --allocated-storage 20 \
    --storage-type gp2 \
    --db-name emailanalytics \
    --master-username dbadmin \
    --master-user-password YOUR_DB_PASSWORD \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --backup-retention-period 7 \
    --storage-encrypted \
    --publicly-accessible
```

### 2. Backend Deployment (AWS App Runner)

1. **Create apprunner.yaml**:
```yaml
version: 1.0
runtime: nodejs18
build:
  commands:
    build:
      - echo "Installing dependencies..."
      - npm ci --production
      - echo "Building application..."
      - npm run build
run:
  runtime-version: 18
  command: npm start
  network:
    port: 5000
    env: PORT
  env:
    - name: NODE_ENV
      value: production
```

2. **Deploy using AWS CLI**:
```bash
# Create App Runner service
aws apprunner create-service \
    --service-name email-analytics-backend \
    --source-configuration '{
        "ImageRepository": {
            "ImageIdentifier": "public.ecr.aws/aws-containers/hello-app-runner:latest",
            "ImageConfiguration": {
                "Port": "5000"
            },
            "ImageRepositoryType": "ECR_PUBLIC"
        },
        "AutoDeploymentsEnabled": true
    }' \
    --instance-configuration '{
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    }'
```

### 3. Frontend Deployment (AWS Amplify)

1. **Connect GitHub repository to Amplify**
2. **Configure build settings**:
```yaml
version: 1
applications:
  - frontend:
      phases:
        preBuild:
          commands:
            - cd client
            - npm ci
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: client/dist
        files:
          - '**/*'
      cache:
        paths:
          - client/node_modules/**/*
```

### 4. Environment Variables Setup

Set the following environment variables in App Runner:
- `DATABASE_URL`
- `OPENAI_API_KEY`
- `VITE_AZURE_CLIENT_ID`
- `VITE_AZURE_TENANT_ID`
- `JWT_SECRET`
- `NODE_ENV=production`

## Cost Estimation (Monthly)

| Service | Configuration | Estimated Cost |
|---------|---------------|----------------|
| RDS PostgreSQL | db.t3.micro | $15-20 |
| App Runner | 0.25 vCPU, 0.5 GB | $10-15 |
| Amplify | Standard tier | $5-10 |
| CloudFront | 1GB transfer | $1-2 |
| **Total** | | **$31-47/month** |

## Security Considerations

1. **VPC Configuration**: Place RDS in private subnets
2. **Security Groups**: Restrict database access to backend only
3. **IAM Roles**: Minimal permissions for each service
4. **Secrets Manager**: Store sensitive credentials
5. **WAF**: Web Application Firewall for frontend
6. **SSL/TLS**: End-to-end encryption

## Monitoring and Logging

1. **CloudWatch Logs**: Application and error logs
2. **CloudWatch Metrics**: Performance monitoring
3. **AWS X-Ray**: Distributed tracing
4. **Health Checks**: App Runner automatic health monitoring

## Backup Strategy

1. **RDS Automated Backups**: 7-day retention
2. **Point-in-time Recovery**: RDS feature
3. **Cross-region Backup**: For disaster recovery
4. **Application Data Export**: Regular exports to S3

## CI/CD Pipeline

1. **GitHub Actions** or **AWS CodePipeline**
2. **Automated Testing**: Unit and integration tests
3. **Environment Promotion**: Dev → Staging → Production
4. **Rollback Strategy**: Automatic rollback on failures

## Scalability Plan

1. **Auto Scaling**: App Runner automatic scaling
2. **Database Scaling**: RDS read replicas
3. **CDN Caching**: CloudFront edge locations
4. **API Rate Limiting**: Protect against abuse

## Domain and SSL

1. **Route 53**: DNS management
2. **Certificate Manager**: Free SSL certificates
3. **Custom Domain**: Connect to Amplify and App Runner
4. **HTTPS Redirect**: Force secure connections
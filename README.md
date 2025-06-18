# Email Analytics Dashboard

Enterprise-level email analytics dashboard with AI-powered task extraction using React, Express.js, PostgreSQL, and Microsoft Graph API integration.

## Features

- **Microsoft Graph API Integration**: Authentic email data synchronization
- **AI-Powered Analytics**: OpenAI GPT-4 for task extraction and sentiment analysis
- **Real-time Dashboard**: Interactive analytics with email volume trends
- **Task Management**: Automatic task identification from emails
- **Team Performance**: Analytics and productivity insights
- **Secure Authentication**: MSAL React for Microsoft OAuth 2.0

## Tech Stack

### Frontend
- React 18 with TypeScript
- Vite for fast development and building
- Tailwind CSS for styling
- Shadcn/ui components
- TanStack Query for data fetching
- Recharts for data visualization

### Backend
- Express.js with TypeScript
- PostgreSQL with Drizzle ORM
- Microsoft Graph SDK
- OpenAI GPT-4 integration
- JWT authentication

## Local Development Setup

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Microsoft Azure AD application
- OpenAI API key

### Environment Setup

1. Copy environment file:
```bash
cp .env.example .env
```

2. Configure your environment variables in `.env`:
```env
# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/emailanalytics

# Microsoft Graph API
VITE_AZURE_CLIENT_ID=your-azure-client-id
VITE_AZURE_TENANT_ID=your-azure-tenant-id

# OpenAI
OPENAI_API_KEY=your-openai-api-key

# JWT Secret
JWT_SECRET=your-jwt-secret-key
```

### Installation

1. Install dependencies:
```bash
npm install
```

2. Set up database:
```bash
npm run db:push
```

3. Start development server:
```bash
npm run dev
```

The application will be available at `http://localhost:5000`

## AWS Deployment

### Quick Deployment

Use the automated deployment script:
```bash
npm run deploy:aws
```

### Manual Deployment Steps

1. **Database Setup (RDS PostgreSQL)**:
```bash
aws rds create-db-instance \
  --db-instance-identifier email-analytics-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --allocated-storage 20 \
  --db-name emailanalytics \
  --master-username dbadmin \
  --master-user-password YOUR_PASSWORD
```

2. **Backend Deployment (App Runner)**:
```bash
# Build and push Docker image
docker build -t email-analytics .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker tag email-analytics:latest YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/email-analytics:latest
docker push YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/email-analytics:latest

# Create App Runner service
aws apprunner create-service --cli-input-json file://apprunner-config.json
```

3. **Frontend Deployment (Amplify)**:
- Connect GitHub repository to AWS Amplify
- Use provided `amplify.yml` configuration
- Set environment variables for Azure credentials

### Environment Variables for Production

Set these in AWS App Runner:
- `DATABASE_URL`: RDS PostgreSQL connection string
- `OPENAI_API_KEY`: Your OpenAI API key
- `VITE_AZURE_CLIENT_ID`: Azure AD application ID
- `VITE_AZURE_TENANT_ID`: Azure AD tenant ID
- `JWT_SECRET`: Strong random secret for JWT signing
- `NODE_ENV=production`

## Docker Development

Run with Docker Compose:
```bash
docker-compose up -d
```

This starts PostgreSQL and the application in containers.

## API Endpoints

### Authentication
- `POST /api/auth/microsoft` - Microsoft Graph authentication
- `POST /api/auth/logout` - Logout user

### Email Management
- `GET /api/emails/recent` - Get recent emails
- `POST /api/emails/sync` - Sync emails from Microsoft Graph

### Analytics
- `GET /api/dashboard/metrics` - Dashboard metrics
- `GET /api/dashboard/sentiment` - Sentiment analysis
- `GET /api/dashboard/email-volume` - Email volume trends

### Tasks
- `GET /api/tasks/recent` - Recent tasks
- `PUT /api/tasks/:id/status` - Update task status

## Microsoft Graph API Setup

1. Create Azure AD application at https://portal.azure.com
2. Add these API permissions:
   - `User.Read`
   - `Mail.Read`
   - `Mail.ReadWrite`
   - `Directory.Read.All`
   - `User.ReadBasic.All`
3. Configure redirect URIs for your domains
4. Copy Application (client) ID and Tenant ID to environment variables

## Security Features

- JWT-based authentication
- Microsoft OAuth 2.0 integration
- Environment variable protection
- Database connection encryption
- CORS configuration
- Rate limiting (production)

## Monitoring

### Local Development
- Console logging
- Error handling with stack traces

### Production (AWS)
- CloudWatch Logs integration
- Application performance monitoring
- Health check endpoints
- Error tracking and alerting

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
1. Check existing GitHub issues
2. Create new issue with detailed description
3. Include environment details and error logs

## Cost Estimation (AWS)

| Service | Monthly Cost |
|---------|-------------|
| RDS PostgreSQL (db.t3.micro) | $15-20 |
| App Runner (0.25 vCPU, 0.5 GB) | $10-15 |
| Amplify (Standard tier) | $5-10 |
| CloudFront | $1-2 |
| **Total** | **$31-47** |
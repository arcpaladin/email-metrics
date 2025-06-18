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
cp .env.example .env.local
```

2. Configure your environment variables in `.env.local`:
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

### Automated Deployment

Use the deployment script for complete AWS setup:

```bash
chmod +x deploy-aws.sh
./deploy-aws.sh
```

The script provides multiple deployment options:
1. **Full deployment** (Database + Backend + Frontend)
2. **Database only**
3. **Backend only** 
4. **Frontend only**
5. **Cleanup existing resources**

### Deployment Features

- **Database**: Automatic RDS PostgreSQL setup with latest version detection
- **Backend**: App Runner service with ECR container registry
- **Frontend**: Amplify deployment guidance with GitHub integration
- **Security**: IAM roles and policies automatically configured
- **Error Handling**: Existing resource detection and graceful updates

### Alternative Deployment Methods

If Docker isn't available, the script offers:
- **GitHub Actions**: Automated CI/CD pipeline generation
- **Source Code Deployment**: Direct code deployment to App Runner
- **Manual Setup**: Step-by-step AWS console guidance

### Environment Variables Setup

After deployment, configure these variables:

#### App Runner Backend
Set in AWS App Runner Console:
```env
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://dbadmin:PASSWORD@endpoint:5432/emailanalytics
OPENAI_API_KEY=your-openai-api-key
VITE_AZURE_CLIENT_ID=your-azure-client-id
VITE_AZURE_TENANT_ID=your-azure-tenant-id
JWT_SECRET=your-jwt-secret-key
```

#### Amplify Frontend
Set in AWS Amplify Console:
```env
VITE_AZURE_CLIENT_ID=your-azure-client-id
VITE_AZURE_TENANT_ID=your-azure-tenant-id
```

### Post-Deployment Steps

1. **Configure environment variables** in AWS consoles
2. **Update Azure AD redirect URIs** with your new domains
3. **Test backend endpoints** at your App Runner URL
4. **Deploy frontend** via Amplify console
5. **Monitor logs** using CloudWatch

## Microsoft Graph API Setup

1. Create Azure AD application at https://portal.azure.com
2. Add API permissions:
   - `User.Read`
   - `Mail.Read`
   - `Mail.ReadWrite`
   - `Directory.Read.All`
   - `User.ReadBasic.All`
3. Configure redirect URIs for your domains
4. Copy Application (client) ID and Tenant ID to environment variables

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

## Security Features

- JWT-based authentication
- Microsoft OAuth 2.0 integration
- Environment variable protection
- Database connection encryption
- CORS configuration
- Automatic IAM role management

## Monitoring and Troubleshooting

### Check Deployment Status
```bash
./check-deployment-status.sh
```

### View Application Logs
```bash
aws logs tail /aws/apprunner/email-analytics-backend/application --region us-east-2 --follow
```

### Common Issues
- **Docker not running**: Use GitHub Actions deployment option
- **Permission errors**: Run IAM policy setup from deployment script
- **Service not ready**: Wait for App Runner service to reach RUNNING state

## Cost Estimation (AWS)

| Service | Monthly Cost |
|---------|-------------|
| RDS PostgreSQL (db.t3.micro) | $15-20 |
| App Runner (0.25 vCPU, 0.5 GB) | $10-15 |
| Amplify (Standard tier) | $5-10 |
| ECR Storage | $1-2 |
| **Total** | **$31-47** |

## Support

For deployment issues:
1. Check deployment script output and logs
2. Verify AWS credentials and permissions
3. Monitor service status in AWS consoles
4. Review environment variable configuration

## License

This project is licensed under the MIT License.
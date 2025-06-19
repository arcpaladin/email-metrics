# Email Analytics Dashboard

Enterprise-grade email analytics platform that transforms complex email communications into actionable insights using AI processing and Microsoft Graph API integration.

## Features

- **Microsoft Graph Integration**: Seamlessly connects to Microsoft 365 email accounts
- **AI-Powered Analysis**: Uses OpenAI GPT-4 for sentiment analysis and task extraction
- **Real-time Dashboard**: Interactive analytics with charts and metrics
- **Task Management**: Automatically identifies and tracks email-derived tasks
- **Team Performance**: Monitor team productivity and response times
- **Secure Authentication**: Microsoft Azure AD integration with MSAL

## Tech Stack

- **Frontend**: React + TypeScript + Vite + Tailwind CSS
- **Backend**: Node.js + Express + TypeScript
- **Database**: PostgreSQL with Drizzle ORM
- **Authentication**: Microsoft MSAL + JWT
- **AI**: OpenAI GPT-4 API
- **Deployment**: AWS Amplify + App Runner + RDS

## Quick Start

### Local Development

1. **Clone and install dependencies**:
   ```bash
   git clone <repository-url>
   cd email-analytics
   npm install
   ```

2. **Set up environment variables**:
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your configuration
   ```

3. **Start the development server**:
   ```bash
   npm run dev
   ```

### Production Deployment

Deploy to AWS using the automated script:

```bash
./deploy-simple.sh
```

Or follow the detailed deployment guide in `DEPLOYMENT_GUIDE.md`.

## Configuration

### Required Environment Variables

**Backend**:
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secret key for JWT token signing
- `OPENAI_API_KEY`: OpenAI API key for AI features

**Frontend**:
- `VITE_AZURE_CLIENT_ID`: Azure app registration client ID
- `VITE_AZURE_TENANT_ID`: Azure tenant ID
- `VITE_API_URL`: Backend API URL (for production)

### Azure Setup

1. Create an Azure app registration
2. Configure redirect URIs for your deployment URLs
3. Grant Microsoft Graph permissions:
   - `User.Read` (delegated)
   - `Mail.Read` (delegated)
4. Update environment variables with your Azure credentials

## Architecture

```
Frontend (React/Amplify) → Backend API (Express/App Runner) → Database (PostgreSQL/RDS)
                        ↘                                   ↗
                         Microsoft Graph API (Azure)
                        ↗
                     OpenAI API
```

## API Endpoints

### Authentication
- `POST /api/auth/microsoft` - Authenticate with Microsoft Graph

### Dashboard Data
- `GET /api/dashboard/metrics` - Get dashboard metrics
- `GET /api/dashboard/sentiment` - Get sentiment analysis
- `GET /api/dashboard/email-volume` - Get email volume data

### Email Management
- `POST /api/emails/sync` - Sync emails from Microsoft Graph
- `GET /api/emails/recent` - Get recent emails

### Task Management
- `GET /api/tasks/recent` - Get recent tasks
- `PUT /api/tasks/:id/status` - Update task status

### Team Management
- `GET /api/employees/team` - Get team members

## Security

- JWT-based authentication
- Microsoft Azure AD integration
- HTTPS-only communication
- Secure environment variable handling
- Database encryption at rest

## Monitoring

- Health check endpoint: `/api/health`
- AWS CloudWatch integration
- Real-time error logging
- Performance metrics tracking

## Development Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run check` - Type checking
- `npm run db:push` - Push database schema changes

## Deployment Scripts

- `./deploy-simple.sh` - Automated AWS deployment
- `./check-deployment-status.sh` - Check deployment status
- `./setup-local-https.sh` - Set up local HTTPS for development

## Support

For deployment issues, check:
1. AWS CloudWatch logs
2. Environment variable configuration
3. Azure app registration settings
4. Database connectivity

## License

MIT License - see LICENSE file for details
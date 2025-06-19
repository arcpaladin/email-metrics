import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { GraphService } from "./services/graph-service";
import { AIAnalysisService } from "./services/openai-service";
import { authService } from "./services/auth-service";
import jwt from 'jsonwebtoken';

const aiService = new AIAnalysisService();

// Middleware to verify JWT token
const authenticateToken = (req: any, res: any, next: any) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.sendStatus(401);
  }

  const user = authService.verifyToken(token);
  if (!user) {
    return res.sendStatus(403);
  }

  req.user = user;
  next();
};

export async function registerRoutes(app: Express): Promise<Server> {
  // Health check endpoint for App Runner
  app.get("/api/health", (_req, res) => {
    res.status(200).json({ status: "healthy", timestamp: new Date().toISOString() });
  });
  // Authentication routes
  app.post('/api/auth/microsoft', async (req, res) => {
    try {
      const { accessToken } = req.body;
      
      if (!accessToken) {
        return res.status(400).json({ error: 'Access token required' });
      }

      const graphService = new GraphService(accessToken);
      const graphUser = await graphService.getCurrentUser();
      
      if (!graphUser.mail) {
        return res.status(400).json({ error: 'No email found in user profile' });
      }

      // Get or create organization
      const domain = graphUser.mail.split('@')[1];
      let organization = await storage.getOrganizationByDomain(domain);
      
      if (!organization) {
        organization = await storage.createOrganization({
          name: domain,
          domain: domain,
        });
      }

      // Get or create employee
      let employee = await storage.getEmployeeByEmail(graphUser.mail);
      
      if (!employee) {
        employee = await authService.createEmployeeFromGraph(graphUser, organization.id);
      }

      const auth = await authService.authenticateEmployee(graphUser.mail);
      if (!auth) {
        return res.status(500).json({ error: 'Authentication failed' });
      }

      res.json(auth);
    } catch (error) {
      console.error('Microsoft auth error:', error);
      res.status(500).json({ error: 'Authentication failed' });
    }
  });

  // Email sync route
  app.post('/api/emails/sync', authenticateToken, async (req: any, res: any) => {
    try {
      const { accessToken } = req.body;
      const user = req.user;

      if (!accessToken) {
        return res.status(400).json({ error: 'Access token required' });
      }

      const graphService = new GraphService(accessToken);
      const graphUser = await graphService.getCurrentUser();
      
      // Fetch emails from Microsoft Graph
      const graphEmails = await graphService.getUserEmails(graphUser.id!, {
        top: 50,
        orderBy: 'receivedDateTime desc'
      });

      const processedEmails = [];

      for (const graphEmail of graphEmails) {
        // Check if email already exists
        try {
          const existingEmail = await storage.getEmailsByEmployee(user.id, 1);
          const emailExists = existingEmail.some(e => e.messageId === graphEmail.id);
          
          if (emailExists) continue;

          // Create email record
          const email = await storage.createEmail({
            messageId: graphEmail.id,
            conversationId: graphEmail.conversationId,
            senderId: user.id,
            subject: graphEmail.subject,
            bodyPreview: graphEmail.bodyPreview,
            receivedAt: new Date(graphEmail.receivedDateTime),
            isRead: graphEmail.isRead || false,
            importance: graphEmail.importance,
            hasAttachments: graphEmail.hasAttachments || false,
          });

          // AI analysis
          if (graphEmail.bodyPreview && graphEmail.subject) {
            try {
              const analysis = await aiService.extractTasks(
                graphEmail.bodyPreview,
                {
                  subject: graphEmail.subject,
                  sender: graphEmail.sender?.emailAddress?.address || '',
                  recipients: graphEmail.toRecipients?.map(r => r.emailAddress?.address || '') || []
                }
              );

              // Store email analysis
              await storage.createEmailAnalysis({
                emailId: email.id,
                sentiment: analysis.sentiment === 'urgent' ? 'neutral' : analysis.sentiment,
                urgencyScore: analysis.urgencyScore,
                topics: analysis.keyTopics,
                actionItems: analysis.tasks.map(t => t.title),
                keyEntities: {},
                aiSummary: analysis.summary,
                processingVersion: '1.0',
              });

              // Create tasks
              for (const task of analysis.tasks) {
                if (task.confidence > 0.7) {
                  await storage.createTask({
                    title: task.title,
                    description: task.description,
                    assignedToId: user.id,
                    status: 'identified',
                    priority: task.priority,
                    dueDate: task.dueDate ? new Date(task.dueDate) : null,
                    confidenceScore: task.confidence,
                    sourceEmailId: email.id,
                  });
                }
              }
            } catch (aiError) {
              console.error('AI analysis failed for email:', email.id, aiError);
            }
          }

          processedEmails.push(email);
        } catch (emailError) {
          console.error('Error processing email:', graphEmail.id, emailError);
        }
      }

      // Update last sync time
      await storage.updateEmployeeLastSync(user.id);

      res.json({
        success: true,
        processedCount: processedEmails.length,
        totalFetched: graphEmails.length
      });
    } catch (error) {
      console.error('Email sync error:', error);
      res.status(500).json({ error: 'Email sync failed' });
    }
  });

  // Dashboard data routes
  app.get('/api/dashboard/metrics', authenticateToken, async (req: any, res: any) => {
    try {
      const user = req.user;
      const metrics = await storage.getEmailMetrics(user.organizationId);
      res.json(metrics);
    } catch (error) {
      console.error('Metrics error:', error);
      res.status(500).json({ error: 'Failed to fetch metrics' });
    }
  });

  app.get('/api/dashboard/sentiment', authenticateToken, async (req: any, res: any) => {
    try {
      const user = req.user;
      const sentiment = await storage.getSentimentAnalytics(user.organizationId);
      res.json(sentiment);
    } catch (error) {
      console.error('Sentiment error:', error);
      res.status(500).json({ error: 'Failed to fetch sentiment data' });
    }
  });

  app.get('/api/dashboard/email-volume', authenticateToken, async (req: any, res: any) => {
    try {
      const user = req.user;
      const days = parseInt(req.query.days as string) || 7;
      const volumeData = await storage.getEmailVolumeData(days, user.organizationId);
      res.json(volumeData);
    } catch (error) {
      console.error('Email volume error:', error);
      res.status(500).json({ error: 'Failed to fetch email volume data' });
    }
  });

  app.get('/api/emails/recent', authenticateToken, async (req: any, res: any) => {
    try {
      const limit = parseInt(req.query.limit as string) || 10;
      const emails = await storage.getRecentEmails(limit);
      res.json(emails);
    } catch (error) {
      console.error('Recent emails error:', error);
      res.status(500).json({ error: 'Failed to fetch recent emails' });
    }
  });

  app.get('/api/tasks/recent', authenticateToken, async (req: any, res: any) => {
    try {
      const limit = parseInt(req.query.limit as string) || 10;
      const tasks = await storage.getRecentTasks(limit);
      res.json(tasks);
    } catch (error) {
      console.error('Recent tasks error:', error);
      res.status(500).json({ error: 'Failed to fetch recent tasks' });
    }
  });

  app.put('/api/tasks/:id/status', authenticateToken, async (req: any, res: any) => {
    try {
      const taskId = parseInt(req.params.id);
      const { status } = req.body;

      if (!['identified', 'in_progress', 'completed'].includes(status)) {
        return res.status(400).json({ error: 'Invalid status' });
      }

      await storage.updateTaskStatus(taskId, status);
      res.json({ success: true });
    } catch (error) {
      console.error('Task status update error:', error);
      res.status(500).json({ error: 'Failed to update task status' });
    }
  });

  app.get('/api/employees/team', authenticateToken, async (req: any, res: any) => {
    try {
      const user = req.user;
      if (!user.organizationId) {
        return res.status(400).json({ error: 'No organization found' });
      }
      
      const employees = await storage.getEmployeesByOrganization(user.organizationId);
      res.json(employees);
    } catch (error) {
      console.error('Team employees error:', error);
      res.status(500).json({ error: 'Failed to fetch team employees' });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}

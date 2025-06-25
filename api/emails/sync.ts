import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';
import { GraphService } from '../../lib/services/graph-service';
import { AIAnalysisService } from '../../lib/services/openai-service';

const aiService = new AIAnalysisService();

async function syncHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

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

    const processedEmails: any[] = [];

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

    return res.json({
      success: true,
      processedCount: processedEmails.length,
      totalFetched: graphEmails.length
    });
  } catch (error) {
    console.error('Email sync error:', error);
    return res.status(500).json({ error: 'Email sync failed' });
  }
}

export default withAuth(syncHandler);

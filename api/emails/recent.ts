import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function recentEmailsHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const limit = parseInt(req.query.limit as string) || 10;
    const emails = await storage.getRecentEmails(limit);
    return res.json(emails);
  } catch (error) {
    console.error('Recent emails error:', error);
    return res.status(500).json({ error: 'Failed to fetch recent emails' });
  }
}

export default withAuth(recentEmailsHandler);

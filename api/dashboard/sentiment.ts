import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function sentimentHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const user = req.user;
    const sentiment = await storage.getSentimentAnalytics(user.organizationId);
    return res.json(sentiment);
  } catch (error) {
    console.error('Sentiment error:', error);
    return res.status(500).json({ error: 'Failed to fetch sentiment data' });
  }
}

export default withAuth(sentimentHandler);

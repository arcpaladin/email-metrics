import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function recentTasksHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const limit = parseInt(req.query.limit as string) || 10;
    const tasks = await storage.getRecentTasks(limit);
    return res.json(tasks);
  } catch (error) {
    console.error('Recent tasks error:', error);
    return res.status(500).json({ error: 'Failed to fetch recent tasks' });
  }
}

export default withAuth(recentTasksHandler);

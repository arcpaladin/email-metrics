import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../../lib/middleware/auth';
import { storage } from '../../../lib/storage';

async function taskStatusHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'PUT') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const taskId = parseInt(req.query.id as string);
    const { status } = req.body;

    if (!['identified', 'in_progress', 'completed'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    await storage.updateTaskStatus(taskId, status);
    return res.json({ success: true });
  } catch (error) {
    console.error('Task status update error:', error);
    return res.status(500).json({ error: 'Failed to update task status' });
  }
}

export default withAuth(taskStatusHandler);

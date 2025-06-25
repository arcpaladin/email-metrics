import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function metricsHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const user = req.user;
    const metrics = await storage.getEmailMetrics(user.organizationId);
    return res.json(metrics);
  } catch (error) {
    console.error('Metrics error:', error);
    return res.status(500).json({ error: 'Failed to fetch metrics' });
  }
}

export default withAuth(metricsHandler);

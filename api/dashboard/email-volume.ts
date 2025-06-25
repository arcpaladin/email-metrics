import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function emailVolumeHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const user = req.user;
    const days = parseInt(req.query.days as string) || 7;
    const volumeData = await storage.getEmailVolumeData(days, user.organizationId);
    return res.json(volumeData);
  } catch (error) {
    console.error('Email volume error:', error);
    return res.status(500).json({ error: 'Failed to fetch email volume data' });
  }
}

export default withAuth(emailVolumeHandler);

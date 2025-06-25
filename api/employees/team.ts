import type { VercelRequest, VercelResponse } from '@vercel/node';
import { withAuth, handleCors, type AuthenticatedRequest } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';

async function teamHandler(req: AuthenticatedRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const user = req.user;
    if (!user.organizationId) {
      return res.status(400).json({ error: 'No organization found' });
    }
    
    const employees = await storage.getEmployeesByOrganization(user.organizationId);
    return res.json(employees);
  } catch (error) {
    console.error('Team employees error:', error);
    return res.status(500).json({ error: 'Failed to fetch team employees' });
  }
}

export default withAuth(teamHandler);

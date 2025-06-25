import type { VercelRequest, VercelResponse } from '@vercel/node';
import { handleCors } from '../../lib/middleware/auth';
import { storage } from '../../lib/storage';
import { GraphService } from '../../lib/services/graph-service';
import { authService } from '../../lib/services/auth-service';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    console.log('Microsoft auth request received');
    const { accessToken } = req.body;
    
    if (!accessToken) {
      console.log('No access token provided');
      return res.status(400).json({ error: 'Access token required' });
    }

    console.log('Creating GraphService with access token');
    const graphService = new GraphService(accessToken);
    
    console.log('Fetching current user from Microsoft Graph');
    const graphUser = await graphService.getCurrentUser();
    console.log('Microsoft Graph user:', { id: graphUser.id, mail: graphUser.mail, displayName: graphUser.displayName });
    
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
  } catch (error: any) {
    console.error('Microsoft auth error:', error);
    
    if (error.message?.includes('JWT is not well formed')) {
      return res.status(400).json({ error: 'Invalid access token format' });
    }
    
    if (error.statusCode === 401) {
      return res.status(401).json({ error: 'Invalid or expired access token' });
    }
    
    res.status(500).json({ 
      error: 'Authentication failed',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

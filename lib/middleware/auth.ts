import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authService } from '../services/auth-service';

export interface AuthenticatedRequest extends VercelRequest {
  user?: any;
}

export function withAuth(handler: (req: AuthenticatedRequest, res: VercelResponse) => Promise<any>) {
  return async (req: VercelRequest, res: VercelResponse) => {
    try {
      const authHeader = req.headers['authorization'] as string;
      const token = authHeader && authHeader.split(' ')[1];

      if (!token) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const user = authService.verifyToken(token);
      if (!user) {
        return res.status(403).json({ error: 'Forbidden' });
      }

      const authenticatedReq = req as AuthenticatedRequest;
      authenticatedReq.user = user;
      return await handler(authenticatedReq, res);
    } catch (error) {
      console.error('Auth middleware error:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  };
}

export function corsHeaders(res: VercelResponse) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
}

export function handleCors(req: VercelRequest, res: VercelResponse) {
  corsHeaders(res);
  
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return true;
  }
  
  return false;
}

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { handleCors } from '../lib/middleware/auth';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (handleCors(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    res.status(200).json({ 
      status: "healthy", 
      timestamp: new Date().toISOString() 
    });
  } catch (error) {
    console.error('Health check error:', error);
    res.status(500).json({ error: 'Health check failed' });
  }
}

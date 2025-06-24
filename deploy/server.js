import express from 'express';
import { createServer } from 'http';
import dotenv from 'dotenv';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';
import { neon } from '@neondatabase/serverless';
import jwt from 'jsonwebtoken';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 80;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// CORS middleware for production
app.use((req, res, next) => {
  const allowedOrigins = [
    process.env.FRONTEND_URL,
    'https://your-app.vercel.app', // Replace with your actual Vercel domain
    'http://localhost:3000',
    'http://localhost:5173'
  ].filter(Boolean);

  const origin = req.headers.origin;
  if (allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
    return;
  }
  
  next();
});

// Database connection
const sql = neon(process.env.DATABASE_URL);

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Email Analytics API',
      version: '1.0.0',
      description: 'API for Email Analytics Dashboard with Microsoft Graph integration',
    },
    servers: [
      {
        url: process.env.API_URL || 'http://localhost',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./server.js'], // Path to the API docs
};

const specs = swaggerJsdoc(swaggerOptions);
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(specs));

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.sendStatus(401);
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
};

/**
 * @swagger
 * /api/health:
 *   get:
 *     summary: Health check endpoint
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 database:
 *                   type: string
 *                   example: connected
 */
app.get('/api/health', async (req, res) => {
  try {
    const result = await sql`SELECT NOW() as now`;
    res.json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      database: 'connected',
      db_time: result[0].now
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'unhealthy', 
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message
    });
  }
});

/**
 * @swagger
 * /api/setup-db:
 *   post:
 *     summary: Setup database tables
 *     tags: [Database]
 *     responses:
 *       200:
 *         description: Database tables created successfully
 *       500:
 *         description: Database setup failed
 */
app.post('/api/setup-db', async (req, res) => {
  try {
    await sql`
      CREATE TABLE IF NOT EXISTS organizations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        domain TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT NOW()
      );
      
      CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        organization_id INTEGER REFERENCES organizations(id),
        email TEXT NOT NULL UNIQUE,
        display_name TEXT,
        department TEXT,
        role TEXT,
        last_sync_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      );
      
      CREATE TABLE IF NOT EXISTS emails (
        id SERIAL PRIMARY KEY,
        message_id TEXT NOT NULL UNIQUE,
        conversation_id TEXT,
        sender_id INTEGER REFERENCES employees(id),
        subject TEXT,
        body_preview TEXT,
        received_at TIMESTAMP NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        importance TEXT,
        has_attachments BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS email_analysis (
        id SERIAL PRIMARY KEY,
        email_id INTEGER REFERENCES emails(id),
        sentiment TEXT,
        urgency_score DECIMAL(3,2),
        topics TEXT[],
        action_items TEXT[],
        key_entities JSONB,
        ai_summary TEXT,
        processing_version TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        assigned_to_id INTEGER REFERENCES employees(id),
        status TEXT DEFAULT 'identified',
        priority TEXT,
        due_date TIMESTAMP,
        confidence_score DECIMAL(3,2),
        source_email_id INTEGER REFERENCES emails(id),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    
    res.json({ status: 'Database tables created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /api/auth/microsoft:
 *   post:
 *     summary: Authenticate with Microsoft Graph
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               accessToken:
 *                 type: string
 *                 description: Microsoft Graph access token
 *     responses:
 *       200:
 *         description: Authentication successful
 *       400:
 *         description: Invalid request
 *       401:
 *         description: Authentication failed
 */
app.post('/api/auth/microsoft', async (req, res) => {
  try {
    const { accessToken } = req.body;
    
    if (!accessToken) {
      return res.status(400).json({ error: 'Access token required' });
    }

    // Here you would integrate with your existing auth service
    // For now, returning a basic response
    res.json({ 
      message: 'Microsoft authentication endpoint - integrate with your auth service',
      token: 'placeholder-jwt-token'
    });
  } catch (error) {
    res.status(500).json({ error: 'Authentication failed' });
  }
});

// Default route
app.get('*', (req, res) => {
  res.json({
    message: 'Email Analytics API',
    version: '1.0.0',
    documentation: '/api/docs',
    health: '/api/health',
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

const server = createServer(app);

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Email Analytics API running on port ${PORT}`);
  console.log(`API Documentation: http://localhost:${PORT}/api/docs`);
  console.log(`Health Check: http://localhost:${PORT}/api/health`);
  console.log(`Database: ${process.env.DATABASE_URL ? 'Connected to Neon' : 'Not configured'}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Server started at: ${new Date().toISOString()}`);
});

// Load environment variables first
import "./env";

import express, { type Request, Response, NextFunction } from "express";
import https from "https";
import fs from "fs";
import path from "path";
import { registerRoutes } from "./routes";
import { setupVite, serveStatic, log } from "./vite";

const app = express();

// CORS configuration
app.use((req, res, next) => {
  const allowedOrigins = [
    'https://email-metrics-taupe.vercel.app',
    'http://localhost:5173',
    'http://localhost:3000',
    'https://localhost:5001'
  ];
  
  const origin = req.headers.origin;
  if (allowedOrigins.includes(origin as string)) {
    res.setHeader('Access-Control-Allow-Origin', origin as string);
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

app.use(express.json());
app.use(express.urlencoded({ extended: false }));

app.use((req, res, next) => {
  const start = Date.now();
  const path = req.path;
  let capturedJsonResponse: Record<string, any> | undefined = undefined;

  const originalResJson = res.json;
  res.json = function (bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };

  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path.startsWith("/api")) {
      let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }

      if (logLine.length > 80) {
        logLine = logLine.slice(0, 79) + "…";
      }

      log(logLine);
    }
  });

  next();
});

(async () => {
  const server = await registerRoutes(app);

  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";

    res.status(status).json({ message });
    throw err;
  });

  // importantly only setup vite in development and after
  // setting up all the other routes so the catch-all route
  // doesn't interfere with the other routes
  if (app.get("env") === "development") {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }

  // ALWAYS serve the app on port 5000
  // this serves both the API and the client.
  // It is the only port that is not firewalled.
  const port = process.env.PORT;
  
  // In development, run both HTTP and HTTPS servers
  if (app.get("env") === "development") {
    // Start HTTP server on main port
    server.listen({
      port,
      reusePort: true,
    }, () => {
      log(`serving on port ${port}`);
    });
    
    // Try to start HTTPS server on port 5001 for Microsoft auth
    try {
      const httpsOptions = {
        key: fs.readFileSync(path.resolve("key.pem")),
        cert: fs.readFileSync(path.resolve("cert.pem")),
      };
      
      const httpsServer = https.createServer(httpsOptions, app);
      httpsServer.listen({
        port: 5001,
        reusePort: true,
      }, () => {
        log(`serving HTTPS on port 5001 for Microsoft auth`);
      });
    } catch (error) {
      log("HTTPS certificates not found, skipping HTTPS server");
    }
  } else {
    server.listen({
      port,
      reusePort: true,
    }, () => {
      log(`serving on port ${port}`);
    });
  }
})();

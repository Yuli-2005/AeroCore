import 'dotenv/config';
import { randomUUID } from 'crypto';
import express, { type Express } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost:3002',
  'http://localhost:3003',
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:4200',
  'https://integracion-sistemas2026.onrender.com',
  'https://mango-meadow-0d3fdd810.7.azurestaticapps.net',
  'https://aerocore-frontend-issd.onrender.com',
  'https://aerocore-api-issd.onrender.com',
  process.env.FRONTEND_URL,
].filter(Boolean) as string[];

export function createServiceApp(serviceName: string): Express {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);

  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
    referrerPolicy: { policy: 'no-referrer' },
  }));

  // Servicios internos y frontend permitidos
  app.use(cors({
    origin(origin, cb) {
      if (!origin) return cb(null, true); // llamadas internas del gateway
      if (allowedOrigins.includes(origin)) return cb(null, true);

      const isLocal = /^http:\/\/localhost(:\d+)?$/.test(origin) || /^http:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);
      const isRender = /\.onrender\.com$/.test(origin);
      const isSwagger = /swagger\.io$/.test(origin);

      if (isLocal || isRender || isSwagger) {
        return cb(null, true);
      }

      console.warn('⚠️  CORS bloqueado en microservicio:', origin);
      cb(new Error('Not allowed by CORS'));
    },
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-correlation-id'],
    maxAge: 600,
  }));

  app.use(rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 500,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { success: false, error: { code: 'RATE_LIMITED', message: 'Demasiadas solicitudes.' } },
  }));

  app.use((req, res, next) => {
    if (
      ['POST', 'PUT', 'PATCH'].includes(req.method) &&
      Number(req.headers['content-length'] ?? 0) > 0 &&
      !req.is('application/json')
    ) {
      res.status(415).json({ success: false, error: { code: 'UNSUPPORTED_MEDIA_TYPE', message: 'Content-Type debe ser application/json' } });
      return;
    }
    next();
  });

  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // Propagación de Correlation ID
  app.use((req, res, next) => {
    const cid = (req.headers['x-correlation-id'] as string) || randomUUID();
    req.headers['x-correlation-id'] = cid;
    res.setHeader('X-Correlation-Id', cid);
    next();
  });

  app.use((_req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Pragma', 'no-cache');
    next();
  });

  // Logger estructurado
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      console.log(JSON.stringify({
        ts: new Date().toISOString(),
        service: serviceName,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        ms: Date.now() - start,
        cid: req.headers['x-correlation-id'],
      }));
    });
    next();
  });

  return app;
}

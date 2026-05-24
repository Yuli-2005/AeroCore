// src/server.ts — punto de entrada de la aplicación
import 'dotenv/config';
import { randomUUID } from 'crypto';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './shared/swagger.js';
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

// ── Dependency Injection Container ──────────────────────────
import {
  authController,
  flightController,
  reservationController,
  promotionController,
  adminController,
  countryController,
  cityController,
  airportController,
  airlineController,
  aircraftController,
  airlineAirportController,
  airlineServiceConfigController,
  flightClassController,
  segmentController,
  serviceCatalogController,
  billingProfileController,
  boardingPassController,
  paymentController,
  invoiceController,
  invoiceItemController,
  passengerServiceController,
  reservationPassengerController,
  auditLogController,
  prisma,
  bookingDb,
  paymentsDb,
} from './shared/container.js';

// ── Routers ──────────────────────────────────────────────────
import { createAuthRouter }                  from './modules/api_users/routes/auth.routes.js';
import { createFlightRouter }                from './modules/api_flights/routes/flights.routes.js';
import { createReservationRouter }           from './modules/api_reservations/routes/reservations.routes.js';
import { createPromotionRouter }             from './modules/api_promotions/routes/promotions.routes.js';
import { createAdminRouter }                 from './modules/api_admin/routes/admin.routes.js';
import { createCountryRouter }               from './modules/api_countries/routes/countries.routes.js';
import { createCityRouter }                  from './modules/api_cities/routes/cities.routes.js';
import { createAirportRouter }               from './modules/api_airports/routes/airports.routes.js';
import { createAirlineRouter }               from './modules/api_airlines/routes/airlines.routes.js';
import { createAircraftRouter }              from './modules/api_aircrafts/routes/aircraft.routes.js';
import { createAirlineAirportRouter }        from './modules/api_airline_airports/routes/airline-airports.routes.js';
import { createAirlineServiceConfigRouter }  from './modules/api_airline_service_configs/routes/airline-service-config.routes.js';
import { createFlightClassRouter }           from './modules/api_flight_classes/routes/flight-classes.routes.js';
import { createSegmentRouter }               from './modules/api_segments/routes/segments.routes.js';
import { createServiceCatalogRouter }        from './modules/api_service_catalog/routes/service-catalog.routes.js';
import { createBillingProfileRouter }        from './modules/api_billing_profiles/routes/billing-profiles.routes.js';
import { createBoardingPassRouter }          from './modules/api_boarding_passes/routes/boarding-passes.routes.js';
import { createPaymentRouter }               from './modules/api_payments/routes/payments.routes.js';
import { createInvoiceRouter }               from './modules/api_invoices/routes/invoices.routes.js';
import { createInvoiceItemRouter }           from './modules/api_invoice_items/routes/invoice-items.routes.js';
import { createPassengerServiceRouter }      from './modules/api_passenger_services/routes/passenger-services.routes.js';
import { createReservationPassengerRouter }  from './modules/api_reservation_passengers/routes/reservation-passengers.routes.js';
import { createAuditLogRouter }              from './modules/api_audit_logs/routes/audit-logs.routes.js';
import { errorHandler }                      from './shared/middlewares/error.middleware.js';
import { validateJwtConfig }                 from './shared/security/jwt.config.js';
import { startGrpcServer }                   from './grpc/grpc.server.js';

// ============================================================
//                        APP SETUP
// ============================================================

const app  = express();
const PORT = Number(process.env.PORT) || 3000;
const DB_CONNECT_MAX_ATTEMPTS = Number(process.env.DB_CONNECT_MAX_ATTEMPTS) || 5;
const DB_CONNECT_RETRY_MS = Number(process.env.DB_CONNECT_RETRY_MS) || 2000;
let grpcServer: Awaited<ReturnType<typeof startGrpcServer>> | undefined;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function connectToDatabaseWithRetry() {
  let lastError: unknown;

  for (let attempt = 1; attempt <= DB_CONNECT_MAX_ATTEMPTS; attempt += 1) {
    try {
      await prisma.$connect();
      if (attempt > 1) {
        console.log(`Conexion a PostgreSQL recuperada en intento ${attempt}/${DB_CONNECT_MAX_ATTEMPTS}`);
      }
      return;
    } catch (error) {
      lastError = error;
      if (attempt === DB_CONNECT_MAX_ATTEMPTS) break;
      console.warn(`Conexion a PostgreSQL fallo en intento ${attempt}/${DB_CONNECT_MAX_ATTEMPTS}. Reintentando en ${DB_CONNECT_RETRY_MS}ms...`);
      await sleep(DB_CONNECT_RETRY_MS);
    }
  }

  throw lastError;
}

validateJwtConfig();
app.disable('x-powered-by');
app.set('trust proxy', 1);

app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
  referrerPolicy: { policy: 'no-referrer' },
}));

// ── CORS ─────────────────────────────────────────────────────
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

app.use(cors({
  origin(origin, cb) {
    if (!origin) return cb(null, true);
    if (allowedOrigins.includes(origin)) return cb(null, true);

    const isLocal = /^http:\/\/localhost(:\d+)?$/.test(origin) || /^http:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);
    const isRender = /\.onrender\.com$/.test(origin);
    const isSwagger = /swagger\.io$/.test(origin);

    if (isLocal || isRender || isSwagger) {
      return cb(null, true);
    }

    console.warn('⚠️  CORS bloqueado:', origin);
    cb(new Error('Not allowed by CORS'));
  },
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-correlation-id'],
  maxAge: 600,
}));

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 450,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMITED', message: 'Demasiadas solicitudes. Intenta nuevamente en unos minutos.' } },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMITED', message: 'Demasiados intentos de autenticacion. Intenta mas tarde.' } },
});

const searchLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 90,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMITED', message: 'Demasiadas busquedas. Intenta nuevamente en unos segundos.' } },
});

app.use('/api', apiLimiter);
app.use(['/api/v1/auth/login', '/api/auth/login', '/api/v1/auth/register', '/api/auth/register'], authLimiter);
app.use(['/api/v1/flights/search', '/api/flights/search'], searchLimiter);

app.use((req, res, next) => {
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && Number(req.headers['content-length'] ?? 0) > 0 && !req.is('application/json')) {
    res.status(415).json({ success: false, error: { code: 'UNSUPPORTED_MEDIA_TYPE', message: 'Content-Type debe ser application/json' } });
    return;
  }
  next();
});

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ── Correlation ID ───────────────────────────────────────────
app.use((req, res, next) => {
  const cid = (req.headers['x-correlation-id'] as string) || randomUUID();
  req.headers['x-correlation-id'] = cid;
  res.setHeader('X-Correlation-Id', cid);
  next();
});

// ── Interceptor de Respuestas (Envelope de Integración) ───────
app.use((req, res, next) => {
  const originalJson = res.json;
  res.json = function (body: any) {
    if (body && typeof body === 'object' && body.success === true && 'data' in body) {
      body.owner = "Yulieth Galarza";
      body.api = "Yulieth Galarza Booking API";
      body.version = "1.0.0";
      body.module = "booking";
      body.visibility = "public";
      body.auth = req.headers.authorization ? "bearer" : "none";
    }
    return originalJson.call(this, body);
  };
  next();
});

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Pragma', 'no-cache');
  }
  next();
});

// ── Logger estructurado ──────────────────────────────────────
if (process.env.NODE_ENV === 'development') {
  app.use((req, _res, next) => {
    console.log(JSON.stringify({ ts: new Date().toISOString(), method: req.method, path: req.path, cid: req.headers['x-correlation-id'] }));
    next();
  });
}

// ============================================================
//                        HEALTH CHECK
// ============================================================

app.get(['/', '/api/v1', '/api/v1/yulieth-galarza'], (_req, res) => {
  res.json({
    success: true,
    data: {
      status: 'online',
      endpoints: 10,
      tables: 22,
      architecture: 'Clean Architecture (Domain / Application / Infrastructure / Presentation)'
    }
  });
});

// ============================================================
//   RUTAS v1
// ============================================================

const PREFIX = '/api/v1/yulieth-galarza';

// Auth & Users
app.use(['/api/v1/auth', `${PREFIX}/auth`],         createAuthRouter(authController));
app.use(['/api/v1/reservations', `${PREFIX}/reservations`], createReservationRouter(reservationController, prisma));
app.use(['/api/v1/promotions', `${PREFIX}/promotions`],   createPromotionRouter(promotionController));

// Catálogos geográficos (GET público, mutaciones admin)
app.use(['/api/v1/countries', `${PREFIX}/countries`], createCountryRouter(countryController));
app.use(['/api/v1/cities', `${PREFIX}/cities`],    createCityRouter(cityController));
app.use(['/api/v1/airports', `${PREFIX}/airports`],  createAirportRouter(airportController));

// Aerolíneas y aeronaves (GET público, mutaciones admin)
app.use(['/api/v1/airlines', `${PREFIX}/airlines`],              createAirlineRouter(airlineController));
app.use(['/api/v1/aircraft', `${PREFIX}/aircraft`],              createAircraftRouter(aircraftController));
app.use(['/api/v1/airline-airports', `${PREFIX}/airline-airports`],      createAirlineAirportRouter(airlineAirportController));
app.use(['/api/v1/airline-service-config', `${PREFIX}/airline-service-config`],createAirlineServiceConfigRouter(airlineServiceConfigController));

// Vuelos y clases (GET público, mutaciones admin)
app.use(['/api/v1/flights', `${PREFIX}/flights`],       createFlightRouter(flightController));
app.use(['/api/v1/flight-classes', `${PREFIX}/flight-classes`],createFlightClassRouter(flightClassController));
app.use(['/api/v1/segments', `${PREFIX}/segments`],      createSegmentRouter(segmentController));

// Servicios de catálogo (GET público, mutaciones admin)
app.use(['/api/v1/service-catalog', `${PREFIX}/service-catalog`], createServiceCatalogRouter(serviceCatalogController));

// Operaciones autenticadas
app.use(['/api/v1/billing-profiles', `${PREFIX}/billing-profiles`],       createBillingProfileRouter(billingProfileController, paymentsDb));
app.use(['/api/v1/boarding-passes', `${PREFIX}/boarding-passes`],        createBoardingPassRouter(boardingPassController, bookingDb));
app.use(['/api/v1/payments', `${PREFIX}/payments`],               createPaymentRouter(paymentController, bookingDb, paymentsDb));
app.use(['/api/v1/invoices', `${PREFIX}/invoices`],               createInvoiceRouter(invoiceController, paymentsDb));
app.use(['/api/v1/invoice-items', `${PREFIX}/invoice-items`],          createInvoiceItemRouter(invoiceItemController, paymentsDb));
app.use(['/api/v1/passenger-services', `${PREFIX}/passenger-services`],     createPassengerServiceRouter(passengerServiceController, bookingDb));
app.use(['/api/v1/reservation-passengers', `${PREFIX}/reservation-passengers`], createReservationPassengerRouter(reservationPassengerController, bookingDb));
app.use(['/api/v1/audit-logs', `${PREFIX}/audit-logs`],             createAuditLogRouter(auditLogController));

// Admin panel (todas requieren ADMIN)
app.use(['/api/v1/admin', `${PREFIX}/admin`], createAdminRouter(adminController, prisma));

// ── Alias sin versión (backward compatibility) ───────────────
app.use('/api/auth',                  createAuthRouter(authController));
app.use('/api/flights',               createFlightRouter(flightController));
app.use('/api/reservations',          createReservationRouter(reservationController, prisma));
app.use('/api/promotions',            createPromotionRouter(promotionController));
app.use('/api/admin',                 createAdminRouter(adminController, prisma));

// ── Cargar contrato OpenAPI unificado ────────────────────────
let unifiedSpec: object | null = null;
try {
  const filePath = path.resolve('openapi.yaml');
  unifiedSpec = yaml.load(fs.readFileSync(filePath, 'utf8')) as object;
} catch (error: any) {
  console.error('❌ Error al cargar openapi.yaml:', error.message);
}

// ── Cargar spec pública (para equipos externos) ───────────────
let publicSpec: object | null = null;
try {
  const filePath = path.resolve('openapi-public.yaml');
  publicSpec = yaml.load(fs.readFileSync(filePath, 'utf8')) as object;
} catch (error: any) {
  console.warn('⚠️  openapi-public.yaml no encontrado:', error.message);
}

// ── Redirección para asegurar barra al final en Swagger UI ────
app.use((req, res, next) => {
  const urlPath = req.path;
  if (urlPath.match(/^\/api\/v1\/(yulieth-galarza\/)?docs(-public)?$/)) {
    return res.redirect(301, req.originalUrl.replace(urlPath, urlPath + '/'));
  }
  next();
});

// ── Documentación Swagger UI (unificada, interna) ────────────
const activeSpec = unifiedSpec ?? swaggerSpec;

app.use(['/api/v1/docs', `${PREFIX}/docs`], swaggerUi.serve, swaggerUi.setup(activeSpec, {
  customSiteTitle: 'Yulieth Galarza — Booking API Docs',
  swaggerOptions: { persistAuthorization: true },
}));

// ── Swagger UI pública (spec reducida para integración) ───────
if (publicSpec) {
  app.use(['/api/v1/docs-public', `${PREFIX}/docs-public`], swaggerUi.serve, swaggerUi.setup(publicSpec, {
    customSiteTitle: 'Yulieth Galarza — Public API (Integración)',
    swaggerOptions: { persistAuthorization: false },
  }));
}

// Endpoint YAML de la spec pública
app.get(['/api/v1/openapi-public.yaml', `${PREFIX}/openapi-public.yaml`], (_req, res) => {
  res.setHeader('Content-Type', 'application/yaml');
  res.sendFile(path.resolve('openapi-public.yaml'));
});

// Endpoint JSON de la spec pública
app.get(['/api/v1/openapi-public.json', `${PREFIX}/openapi-public.json`], (_req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(publicSpec ?? {});
});

// Endpoint JSON del spec (para el frontend y herramientas externas)
app.get(['/api/v1/docs.json', `${PREFIX}/docs.json`], (_req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(activeSpec);
});

// Endpoint YAML del spec
app.get(['/api/v1/docs.yaml', `${PREFIX}/docs.yaml`], (_req, res) => {
  res.setHeader('Content-Type', 'application/yaml');
  res.sendFile(path.resolve('openapi.yaml'));
});

// Alias /spec para compatibilidad
app.get(['/api/v1/spec', `${PREFIX}/spec`], (_req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(activeSpec);
});

// ── 404 ──────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `Ruta ${req.originalUrl} no encontrada` } });
});

app.use(errorHandler);

// ============================================================
//                        ARRANQUE
// ============================================================

async function startServer() {
  try {
    await connectToDatabaseWithRetry();
    console.log('✅ Conectado a PostgreSQL');

    const GRPC_PORT = Number(process.env.GRPC_PORT) || 50051;
    try {
      grpcServer = await startGrpcServer(GRPC_PORT);
    } catch (grpcErr: any) {
      console.warn(`⚠️  gRPC no disponible (puerto ${GRPC_PORT}): ${grpcErr.message} — el servidor REST sigue activo.`);
    }

    app.listen(PORT, () => {
      console.log(`\n🚀 Vuelos API — http://localhost:${PORT}`);
      console.log(`\n📡 Endpoints activos (${22} tablas cubiertas):`);
      console.log(`   /api/v1/auth                   — autenticación`);
      console.log(`   /api/v1/countries              — países (GET público)`);
      console.log(`   /api/v1/cities                 — ciudades (GET público)`);
      console.log(`   /api/v1/airports               — aeropuertos (GET público)`);
      console.log(`   /api/v1/airlines               — aerolíneas (GET público)`);
      console.log(`   /api/v1/aircraft               — aeronaves (GET público)`);
      console.log(`   /api/v1/airline-airports        — relación aerolínea-aeropuerto`);
      console.log(`   /api/v1/airline-service-config  — configuración de servicios`);
      console.log(`   /api/v1/flights                — vuelos (GET público)`);
      console.log(`   /api/v1/flight-classes         — clases de vuelo`);
      console.log(`   /api/v1/segments               — segmentos`);
      console.log(`   /api/v1/service-catalog        — catálogo de servicios`);
      console.log(`   /api/v1/promotions             — promociones`);
      console.log(`   /api/v1/reservations           — reservas (auth)`);
      console.log(`   /api/v1/reservation-passengers — pasajeros (auth)`);
      console.log(`   /api/v1/billing-profiles       — perfiles de facturación (auth)`);
      console.log(`   /api/v1/payments               — pagos (auth)`);
      console.log(`   /api/v1/invoices               — facturas (auth)`);
      console.log(`   /api/v1/invoice-items          — ítems de factura (auth)`);
      console.log(`   /api/v1/passenger-services     — servicios de pasajero (auth)`);
      console.log(`   /api/v1/boarding-passes        — pases de abordar (auth)`);
      console.log(`   /api/v1/audit-logs             — auditoría (admin)`);
      console.log(`   /api/v1/admin                  — panel admin (admin)`);
      console.log(`\n💡 Modo: ${process.env.NODE_ENV}`);
    });
  } catch (error) {
    console.error('❌ Error al conectar con la base de datos:', error);
    process.exit(1);
  }
}

async function stopGrpcServer() {
  if (!grpcServer) return;

  await new Promise<void>((resolve) => {
    grpcServer?.tryShutdown((error) => {
      if (error) grpcServer?.forceShutdown();
      resolve();
    });
  });

  grpcServer = undefined;
}

async function shutdown() {
  await stopGrpcServer();
  await prisma.$disconnect();
  process.exit(0);
}

process.on('SIGINT',  () => { void shutdown(); });
process.on('SIGTERM', () => { void shutdown(); });
process.on('uncaughtException',   (err) => { console.error('❌ Excepción no capturada:', err); process.exit(1); });
process.on('unhandledRejection',  (r)   => { console.error('❌ Promesa rechazada:', r); process.exit(1); });

startServer();

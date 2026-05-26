// shared/gateway.ts
// API Gateway — punto de entrada central que enruta peticiones hacia los microservicios internos.
// Responsabilidades: logging por servicio, trazabilidad, registro de métricas básicas y enrutamiento.
import type { Application, Router, RequestHandler } from 'express';

export type ServiceName = 'ms_identity' | 'ms_catalog' | 'ms_booking' | 'ms_payments' | 'ms_admin';

interface ServiceRoute {
  service: ServiceName;
  paths: string[];
  router: Router;
  middlewares?: RequestHandler[];
}

const SERVICE_COLORS: Record<ServiceName, string> = {
  ms_identity : '🟣',
  ms_catalog  : '🟡',
  ms_booking  : '🟢',
  ms_payments : '🔵',
  ms_admin    : '🔴',
};

const requestCounts: Record<ServiceName, number> = {
  ms_identity : 0,
  ms_catalog  : 0,
  ms_booking  : 0,
  ms_payments : 0,
  ms_admin    : 0,
};

function gatewayLogger(service: ServiceName): RequestHandler {
  return (req, _res, next) => {
    requestCounts[service]++;
    if (process.env.NODE_ENV === 'development') {
      console.log(
        `${SERVICE_COLORS[service]} [gateway → ${service}] ${req.method} ${req.path} ` +
        `| cid=${req.headers['x-correlation-id'] ?? '-'}`
      );
    }
    next();
  };
}

export function registerRoutes(app: Application, routes: ServiceRoute[]): void {
  const PREFIX = '/api/v1/yulieth-galarza';

  for (const { service, paths, router, middlewares = [] } of routes) {
    const logger = gatewayLogger(service);
    const chain: RequestHandler[] = [logger, ...middlewares];

    for (const p of paths) {
      app.use([p, `${PREFIX}${p.replace('/api/v1', '')}`], ...chain, router);
    }
  }
}

export function getGatewayStats() {
  const total = Object.values(requestCounts).reduce((a, b) => a + b, 0);
  return {
    totalRequests: total,
    byService: { ...requestCounts },
    services: Object.keys(requestCounts) as ServiceName[],
  };
}

// shared/middlewares/idempotency-key.middleware.ts
// Previene reservas duplicadas cuando el cliente reintenta una petición HTTP.
//
// Flujo:
//   1. Cliente envía POST con header  Idempotency-Key: <uuid>
//   2. Si la key ya fue procesada → devuelve la respuesta guardada (sin tocar DB)
//   3. Si es nueva → deja pasar, intercepta la respuesta y la almacena en caché
//
// Límite: 5,000 keys en memoria (FIFO). Se resetea al reiniciar el servidor.
import type { Request, Response, NextFunction } from 'express';

interface CachedResponse {
  status: number;
  body:   unknown;
}

const MAX_CACHE = 5_000;
const cache = new Map<string, CachedResponse>();

export function idempotencyKey(req: Request, res: Response, next: NextFunction): void {
  const key = req.headers['idempotency-key'] as string | undefined;

  // Si no viene el header, rechaza con 400
  if (!key || key.trim() === '') {
    res.status(400).json({
      success: false,
      error: {
        code:    'MISSING_IDEMPOTENCY_KEY',
        message: 'El header Idempotency-Key es obligatorio en este endpoint. Envía un UUID único por intento.',
      },
    });
    return;
  }

  // ¿Ya procesamos esta key? → respuesta cacheada
  if (cache.has(key)) {
    const cached = cache.get(key)!;
    res.status(cached.status).json(cached.body);
    return;
  }

  // Interceptar la respuesta para guardarla en caché
  const originalJson = res.json.bind(res);
  res.json = (body: unknown) => {
    // Solo cachear respuestas exitosas (2xx)
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (cache.size >= MAX_CACHE) {
        // FIFO: eliminar la entrada más antigua
        const oldest = cache.keys().next().value as string;
        cache.delete(oldest);
      }
      cache.set(key, { status: res.statusCode, body });
    }
    return originalJson(body);
  };

  next();
}
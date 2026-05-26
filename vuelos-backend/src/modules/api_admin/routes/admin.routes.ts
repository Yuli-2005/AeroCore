// presentation/routes/admin.routes.ts
// Rutas del panel de administración — todas requieren rol ADMIN
import { Router } from 'express';
import { AdminController } from '../controllers/AdminController.js';
import { authenticate, requireAdmin } from '../../../shared/middlewares/auth.middleware.js';
import { validate } from '../../../shared/middlewares/validate.middleware.js';
import { CreateFlightClassSchema, UpdateFlightClassSchema, CreateSegmentSchema, UpdateSegmentSchema } from '../../../shared/schemas/validation.schemas.js';
import type { ZodSchema } from 'zod';

async function audit(db: any, req: any, action: string, entity: string, entityId: string, oldData: any, newData: any) {
  try {
    await db.auditLog.create({
      data: {
        userId:    (req as any).user?.id ?? null,
        action,
        entity,
        entityId,
        oldData:   oldData  ?? undefined,
        newData:   newData  ?? undefined,
        ipAddress: req.ip   ?? null,
        userAgent: (req.headers['user-agent'] as string | undefined) ?? null,
      },
    });
  } catch { /* auditoría no bloquea la operación */ }
}

// Repositorios genéricos usados directamente para CRUD simple de catálogos
function makeGenericRouter(
  db: any,
  model: any,
  include?: object,
  schemas?: { create?: ZodSchema; update?: ZodSchema },
): Router {
  const entityName = String(model);
  const router = Router();
  router.get('/', async (_req, res, next) => {
    try {
      const data = await (db as any)[model].findMany({ include });
      res.json({ success: true, data: { data, pagination: { total: data.length } } });
    } catch (err) { next(err); }
  });
  router.get('/:id', async (req, res, next) => {
    try {
      const data = await (db as any)[model].findUnique({ where: { id: String(req.params.id) }, include });
      if (!data) { res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'No encontrado' } }); return; }
      res.json({ success: true, data });
    } catch (err) { next(err); }
  });
  const createMiddlewares: any[] = schemas?.create ? [validate(schemas.create)] : [];
  router.post('/', ...createMiddlewares, async (req: any, res: any, next: any) => {
    try {
      const data = await (db as any)[model].create({ data: req.body, include });
      await audit(db, req, 'CREATE', entityName, data.id, null, data);
      res.status(201).json({ success: true, data });
    } catch (err) { next(err); }
  });
  const updateMiddlewares: any[] = schemas?.update ? [validate(schemas.update)] : [];
  const updateHandler = async (req: any, res: any, next: any) => {
    try {
      const id = String(req.params.id);
      const oldData = await (db as any)[model].findUnique({ where: { id } });
      const data = await (db as any)[model].update({ where: { id }, data: req.body, include });
      await audit(db, req, 'UPDATE', entityName, id, oldData, data);
      res.json({ success: true, data });
    } catch (err) { next(err); }
  };
  router.patch('/:id', ...updateMiddlewares, updateHandler);
  router.put('/:id',   ...updateMiddlewares, updateHandler);
  router.delete('/:id', async (req, res, next) => {
    try {
      const id = String(req.params.id);
      const oldData = await (db as any)[model].findUnique({ where: { id } });
      await (db as any)[model].delete({ where: { id } });
      await audit(db, req, 'DELETE', entityName, id, oldData, null);
      res.json({ success: true, data: { deleted: true } });
    } catch (err) { next(err); }
  });
  return router;
}

export function createAdminRouter(
  controller: AdminController,
  cDb: any,
  iDb: any,
  bDb: any,
  pDb: any,
): Router {
  const router = Router();
  const auth = [authenticate, requireAdmin];

  // Dashboard
  router.get('/dashboard', ...auth, controller.dashboard);

  // Users
  router.get('/users',        ...auth, controller.listUsers);
  router.post('/users',       ...auth, async (req, res, next) => {
    try {
      const bcrypt = await import('bcryptjs');
      const { password, cityId: rawCityId, ...rest } = req.body;
      if (!password) { res.status(400).json({ success: false, error: { code: 'VALIDATION', message: 'password es requerido' } }); return; }
      const passwordHash = await bcrypt.default.hash(String(password), 10);
      let cityId = rawCityId;
      if (!cityId) {
        const city = await cDb.city.findFirst({ select: { id: true }, orderBy: { name: 'asc' } });
        cityId = city?.id;
      }
      const mainAddress = rest.mainAddress ?? 'Sin dirección';
      const user = await iDb.user.create({
        data: { ...rest, mainAddress, cityId, passwordHash },
      });
      const { passwordHash: _ph, ...safe } = user as any;
      res.status(201).json({ success: true, data: safe });
    } catch (err) { next(err); }
  });
  const updateUserHandler = async (req: any, res: any, next: any) => {
    try {
      const bcrypt = await import('bcryptjs');
      const { password, birthDate, cityId, ...rest } = req.body;
      const updateData: Record<string, unknown> = { ...rest };
      if (password)   updateData.passwordHash = await bcrypt.default.hash(String(password), 10);
      if (birthDate)  updateData.birthDate    = new Date(birthDate);
      if (cityId)     updateData.cityId       = cityId;
      const user = await iDb.user.update({
        where: { id: String(req.params.id) },
        data: updateData,
      });
      const { passwordHash: _ph, ...safe } = user as any;
      res.json({ success: true, data: safe });
    } catch (err) { next(err); }
  };
  router.patch('/users/:id',  ...auth, updateUserHandler);
  router.put('/users/:id',    ...auth, updateUserHandler);
  router.delete('/users/:id', ...auth, controller.deleteUser);

  // ── Catálogos geográficos ────────────────────────────────────
  router.use('/countries', ...auth, makeGenericRouter(cDb, 'country'));
  router.use('/cities',    ...auth, makeGenericRouter(cDb, 'city',    { country: true }));
  router.use('/airports',  ...auth, makeGenericRouter(cDb, 'airport', { city: { include: { country: true } } }));

  // ── Aerolíneas y aeronaves ───────────────────────────────────
  router.use('/airlines',  ...auth, makeGenericRouter(cDb, 'airline',  { country: true }));
  router.use('/aircraft',  ...auth, makeGenericRouter(cDb, 'aircraft', { airline: true }));

  // ── Relación aerolínea-aeropuerto ───────────────────────────
  router.get('/airline-airports', ...auth, async (_req, res, next) => {
    try {
      const data = await cDb.airlineAirport.findMany({ include: { airline: true, airport: true } });
      res.json({ success: true, data: { data, pagination: { total: data.length } } });
    } catch (err) { next(err); }
  });
  router.post('/airline-airports', ...auth, async (req, res, next) => {
    try {
      const { airlineId, airportId } = req.body;
      const data = await cDb.airlineAirport.create({ data: { airlineId, airportId }, include: { airline: true, airport: true } });
      await audit(iDb, req, 'CREATE', 'airlineAirport', `${airlineId}_${airportId}`, null, data);
      res.status(201).json({ success: true, data });
    } catch (err) { next(err); }
  });
  router.delete('/airline-airports/:airlineId/:airportId', ...auth, async (req, res, next) => {
    try {
      const airlineId = String(req.params.airlineId);
      const airportId = String(req.params.airportId);
      const oldData = await cDb.airlineAirport.findFirst({ where: { airlineId, airportId } });
      await cDb.airlineAirport.delete({ where: { airlineId_airportId: { airlineId, airportId } } });
      await audit(iDb, req, 'DELETE', 'airlineAirport', `${airlineId}_${airportId}`, oldData, null);
      res.json({ success: true, data: { deleted: true } });
    } catch (err) { next(err); }
  });

  // ── Vuelos ──────────────────────────────────────────────────
  router.use('/flightclasses', ...auth, makeGenericRouter(cDb, 'flightClass', { flight: true }, { create: CreateFlightClassSchema, update: UpdateFlightClassSchema }));
  router.use('/segments',      ...auth, makeGenericRouter(cDb, 'segment', {
    originAirport: true,
    destinationAirport: true,
    airline: true,
    aircraft: true,
  }, { create: CreateSegmentSchema, update: UpdateSegmentSchema }));

  // ── Reservas y pasajeros ────────────────────────────────────
  router.use('/reservations', ...auth, makeGenericRouter(bDb, 'reservation', {
    passengers: true,
  }));
  router.use('/reservation-passengers', ...auth, makeGenericRouter(bDb, 'reservationPassenger', {
    reservation: { select: { id: true, reservationCode: true } },
    flightClass: true,
  }));

  // ── Servicios y configuración ───────────────────────────────
  router.use('/servicecatalog',         ...auth, makeGenericRouter(cDb, 'serviceCatalog'));
  router.use('/airline-service-config', ...auth, makeGenericRouter(cDb, 'airlineServiceConfig', {
    service: true,
    airline: true,
  }));
  router.use('/passenger-services', ...auth, makeGenericRouter(bDb, 'passengerService', {
    passenger: true,
    serviceConfig: { include: { service: true } },
  }));

  // ── Promociones ─────────────────────────────────────────────
  router.use('/promotions', ...auth, makeGenericRouter(bDb, 'promotion'));

  // ── Pagos y facturación ─────────────────────────────────────
  router.use('/payments', ...auth, makeGenericRouter(pDb, 'payment', {
    reservation: { select: { id: true, reservationCode: true, totalAmount: true } },
  }));
  router.use('/billing-profiles', ...auth, makeGenericRouter(pDb, 'billingProfile'));
  router.use('/invoices',         ...auth, makeGenericRouter(pDb, 'invoice', {
    payment: true,
    items: true,
  }));
  router.use('/invoice-items', ...auth, makeGenericRouter(pDb, 'invoiceItem'));

  // ── Embarque ────────────────────────────────────────────────
  router.use('/boarding-passes', ...auth, makeGenericRouter(bDb, 'boardingPass', {
    passenger: true,
    segment: { include: { originAirport: true, destinationAirport: true, airline: true } },
  }));

  // ── Auditoría ────────────────────────────────────────────────
  router.use('/auditlogs', ...auth, makeGenericRouter(iDb, 'auditLog'));

  return router;
}

import { createRequire } from 'module';

const _require = createRequire(import.meta.url);

const { PrismaClient: CatalogPrisma }   = _require('../../../prisma-catalog/index.js');
const { PrismaClient: IdentityPrisma }  = _require('../../../prisma-identity/index.js');
const { PrismaClient: BookingPrisma }   = _require('../../../prisma-booking/index.js');
const { PrismaClient: PaymentsPrisma }  = _require('../../../prisma-payments/index.js');

const opts = (url: string | undefined) => ({
  datasources: { db: { url } },
  transactionOptions: { maxWait: 15000, timeout: 25000 },
  log: (process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error']) as any,
});

export const catalogDb  = new CatalogPrisma(opts(process.env.CATALOG_DATABASE_URL))  as any;
export const identityDb = new IdentityPrisma(opts(process.env.IDENTITY_DATABASE_URL)) as any;
export const bookingDb  = new BookingPrisma(opts(process.env.BOOKING_DATABASE_URL))   as any;
export const paymentsDb = new PaymentsPrisma(opts(process.env.PAYMENTS_DATABASE_URL)) as any;

import { createRequire } from 'module';

const _require = createRequire(import.meta.url);

function requireEnv(name: string): string {
  const val = process.env[name];
  if (!val) throw new Error(`❌ Missing required environment variable: ${name}`);
  return val;
}

const CATALOG_URL  = requireEnv('CATALOG_DATABASE_URL');
const IDENTITY_URL = requireEnv('IDENTITY_DATABASE_URL');
const BOOKING_URL  = requireEnv('BOOKING_DATABASE_URL');
const PAYMENTS_URL = requireEnv('PAYMENTS_DATABASE_URL');

console.log('🔌 DB connections:');
console.log('  catalog :', CATALOG_URL.split('@')[1]?.split('/')[0]);
console.log('  identity:', IDENTITY_URL.split('@')[1]?.split('/')[0]);
console.log('  booking :', BOOKING_URL.split('@')[1]?.split('/')[0]);
console.log('  payments:', PAYMENTS_URL.split('@')[1]?.split('/')[0]);

const { PrismaClient: CatalogPrisma }   = _require('../../../prisma-catalog/index.js');
const { PrismaClient: IdentityPrisma }  = _require('../../../prisma-identity/index.js');
const { PrismaClient: BookingPrisma }   = _require('../../../prisma-booking/index.js');
const { PrismaClient: PaymentsPrisma }  = _require('../../../prisma-payments/index.js');

const opts = (url: string) => ({
  datasources: { db: { url } },
  transactionOptions: { maxWait: 15000, timeout: 25000 },
  log: (process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error']) as any,
});

export const catalogDb  = new CatalogPrisma(opts(CATALOG_URL))   as any;
export const identityDb = new IdentityPrisma(opts(IDENTITY_URL)) as any;
export const bookingDb  = new BookingPrisma(opts(BOOKING_URL))   as any;
export const paymentsDb = new PaymentsPrisma(opts(PAYMENTS_URL)) as any;

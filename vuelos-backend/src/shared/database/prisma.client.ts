// infrastructure/database/prisma.client.ts
// Load Prisma from the custom output directory (../prisma-client) via createRequire.
// This bypasses @prisma/client's CJS wrapper and the node_modules/.prisma resolution
// chain that fails on Node.js 20 ESM + Linux Azure App Service.
// The constructor is cast to return PrismaClient typed from @prisma/client so the
// instance is type-compatible with all repositories that import type from @prisma/client.
import { createRequire } from 'module';
import type { PrismaClient as PrismaClientPublic } from '@prisma/client';

const _require = createRequire(import.meta.url);
const { PrismaClient } = _require('../../../prisma-client/index.js') as {
  PrismaClient: new (opts?: ConstructorParameters<typeof PrismaClientPublic>[0]) => PrismaClientPublic;
};

let databaseUrl = process.env.DATABASE_URL;

const args = process.argv.join(' ');
if (args.includes('auth-service')) {
  databaseUrl = process.env.IDENTITY_DATABASE_URL || databaseUrl;
} else if (args.includes('booking-service')) {
  databaseUrl = process.env.BOOKING_DATABASE_URL || databaseUrl;
} else if (args.includes('payments-service')) {
  databaseUrl = process.env.PAYMENTS_DATABASE_URL || databaseUrl;
} else if (args.includes('catalog-service') || args.includes('flights-service')) {
  databaseUrl = process.env.CATALOG_DATABASE_URL || databaseUrl;
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: databaseUrl,
    },
  },
  transactionOptions: {
    maxWait: 15000,
    timeout: 25000,
  },
  log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
});

export default prisma;

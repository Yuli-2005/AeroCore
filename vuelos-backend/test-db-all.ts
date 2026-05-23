import { PrismaClient } from './prisma-client/index.js';

const urls = {
  identity: "postgresql://postgres.stdgavgnqdrvxiedblmy:Yuli%402005%2C.%2C@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true&sslmode=require",
  catalog: "postgresql://postgres.hsdzimksgiajklxbjzaa:Yuli%402005%2C.%2C@aws-0-us-west-2.pooler.supabase.com:6543/postgres?pgbouncer=true&sslmode=require",
  booking: "postgresql://postgres.fxxxqmajmkyizeacxdmz:Yuli%402005%2C.%2C@aws-0-us-east-2.pooler.supabase.com:6543/postgres?pgbouncer=true&sslmode=require",
  payments: "postgresql://postgres.yscdzivpnaslvzhhdgzf:Yuli%402005%2C.%2C@aws-0-us-west-1.pooler.supabase.com:6543/postgres?pgbouncer=true&sslmode=require"
};

async function testAll() {
  for (const [name, url] of Object.entries(urls)) {
    console.log(`🔌 Probando conexión a la base de datos de ${name.toUpperCase()}...`);
    const prisma = new PrismaClient({
      datasources: {
        db: {
          url: url
        }
      }
    });
    try {
      await prisma.$connect();
      const res = await prisma.$queryRaw`SELECT version()`;
      console.log(`✅ Conexión exitosa a ${name.toUpperCase()}!`);
      await prisma.$disconnect();
    } catch (err: any) {
      console.error(`❌ Falló la conexión a ${name.toUpperCase()}: ${err.message}`);
    }
  }
}

testAll();

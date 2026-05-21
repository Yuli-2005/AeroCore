import { PrismaClient } from './prisma-client/index.js';

const urls = {
  identity: "postgresql://postgres:Yuli%402005%2C.%2C@db.stdgavgnqdrvxiedblmy.supabase.co:5432/postgres",
  catalog: "postgresql://postgres:Yuli%402005%2C.%2C@db.hsdzimksgiajklxbjzaa.supabase.co:5432/postgres",
  booking: "postgresql://postgres:Yuli%402005%2C.%2C@db.fxxxqmajmkyizeacxdmz.supabase.co:5432/postgres",
  payments: "postgresql://postgres:Yuli%402005%2C.%2C@db.yscdzivpnaslvzhhdgzf.supabase.co:5432/postgres"
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

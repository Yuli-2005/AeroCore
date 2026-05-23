import { PrismaClient } from './prisma-client/index.js';

const passwords = [
  "postgres",
  "admin",
  "1234",
  "123456",
  "Yuli@2005",
  "Yuli@2005,.",
  "Yuli2005",
  "root",
  "password",
  ""
];

async function probe() {
  for (const pw of passwords) {
    const encoded = encodeURIComponent(pw);
    const url = `postgresql://postgres:${encoded}@localhost:5432/postgres`;
    console.log(`🔌 Probando contraseña: "${pw}"...`);
    const prisma = new PrismaClient({
      datasources: {
        db: {
          url: url
        }
      }
    });
    try {
      await prisma.$connect();
      console.log(`✅ ¡Conexión exitosa con la contraseña: "${pw}"!`);
      await prisma.$disconnect();
      return;
    } catch (err: any) {
      if (err.message.includes("Authentication failed")) {
        console.log(`❌ Contraseña incorrecta.`);
      } else {
        console.log(`❌ Otro error: ${err.message}`);
      }
    }
  }
  console.log(`⚠️ Ninguna contraseña común funcionó.`);
}

probe();

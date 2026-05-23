import { PrismaClient } from './prisma-client/index.js';

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: "postgresql://postgres:postgres@localhost:5432/postgres"
    }
  }
});

async function main() {
  console.log("=== RESERVACIONES ===");
  const reservations = await prisma.reservation.findMany({
    take: 5,
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      reservationCode: true,
      status: true,
      totalAmount: true,
      createdAt: true
    }
  });
  console.dir(reservations, { depth: null });

  console.log("\n=== PAGOS ===");
  const payments = await prisma.payment.findMany({
    take: 5,
    orderBy: { createdAt: 'desc' }
  });
  console.dir(payments, { depth: null });

  console.log("\n=== AUDIT LOGS ===");
  const auditLogs = await prisma.auditLog.findMany({
    take: 5,
    orderBy: { createdAt: 'desc' }
  });
  console.dir(auditLogs, { depth: null });

  await prisma.$disconnect();
}

main().catch(console.error);

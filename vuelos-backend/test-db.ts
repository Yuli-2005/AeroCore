import { PrismaClient } from './prisma-client/index.js';
const prisma = new PrismaClient();

async function testSearch() {
  console.log("🔍 Probando buscador de vuelos...");
  
  const vuelos = await prisma.flight.findMany({
    where: {
      originAirportIata: 'UIO',
      status: 'SCHEDULED'
    },
    include: {
      segments: {
        include: {
          airline: true,
          aircraft: true
        }
      },
      flightClasses: true
    }
  });

  console.log("✈️ Vuelos encontrados:", vuelos.length);

  console.log("🔍 Probando consulta de usuarios...");
  const usuarios = await prisma.user.findMany({
    take: 5
  });
  console.log("👤 Usuarios encontrados:", usuarios.map(u => ({ id: u.id, email: u.email, role: u.role })));
}

testSearch();
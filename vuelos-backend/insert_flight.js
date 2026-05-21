import { PrismaClient } from './prisma-client/index.js';

const prisma = new PrismaClient();

async function main() {
  console.log('Insertando vuelo BOG -> UIO para el 30 de mayo de 2026...');

  const flight = await prisma.flight.create({
    data: {
      originAirportIata: 'BOG',
      destinationAirportIata: 'UIO',
      departureDate: new Date('2026-05-30T10:00:00Z'),
      status: 'SCHEDULED'
    }
  });

  await prisma.flightClass.create({
    data: {
      flightId: flight.id,
      cabinClass: 'ECONOMY',
      availableSeats: 120,
      basePrice: 150.00
    }
  });

  console.log('Vuelo insertado: ' + flight.id);
}

main().finally(() => prisma.$disconnect());

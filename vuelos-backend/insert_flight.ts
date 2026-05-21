import { PrismaClient } from './prisma-client';

const prisma = new PrismaClient();

async function main() {
  console.log('Insertando datos para el vuelo BOG -> UIO el 30 de Mayo de 2026...');

  // 1. Obtener los IDs de Country, City, Airport para Colombia y Ecuador
  const colombia = await prisma.country.findFirst({ where: { isoCode: 'CO' } }) ||
    await prisma.country.create({ data: { name: 'Colombia', isoCode: 'CO', phoneCode: '+57', currencyCode: 'COP' } });
  
  const ecuador = await prisma.country.findFirst({ where: { isoCode: 'EC' } }) ||
    await prisma.country.create({ data: { name: 'Ecuador', isoCode: 'EC', phoneCode: '+593', currencyCode: 'USD' } });

  const bogCity = await prisma.city.findFirst({ where: { name: 'Bogotá' } }) ||
    await prisma.city.create({ data: { name: 'Bogotá', countryId: colombia.id, iataCode: 'BOG' } });

  const uioCity = await prisma.city.findFirst({ where: { name: 'Quito' } }) ||
    await prisma.city.create({ data: { name: 'Quito', countryId: ecuador.id, iataCode: 'UIO' } });

  const bogAirport = await prisma.airport.findUnique({ where: { iataCode: 'BOG' } }) ||
    await prisma.airport.create({ data: { iataCode: 'BOG', name: 'El Dorado', cityId: bogCity.id, timezone: 'America/Bogota' } });

  const uioAirport = await prisma.airport.findUnique({ where: { iataCode: 'UIO' } }) ||
    await prisma.airport.create({ data: { iataCode: 'UIO', name: 'Mariscal Sucre', cityId: uioCity.id, timezone: 'America/Guayaquil' } });

  // 2. Crear una Aerolínea y Aeronave
  const airline = await prisma.airline.findUnique({ where: { iataCode: 'AV' } }) ||
    await prisma.airline.create({ data: { iataCode: 'AV', name: 'Avianca', countryId: colombia.id } });

  const aircraft = await prisma.aircraft.findUnique({ where: { registration: 'HK-5321' } }) ||
    await prisma.aircraft.create({ data: { airlineId: airline.id, modelName: 'Airbus A320', registration: 'HK-5321' } });

  // 3. Crear el Vuelo para el 30 de mayo de 2026 (a las 10:00 AM)
  const departureDate = new Date('2026-05-30T10:00:00Z');
  
  const flight = await prisma.flight.create({
    data: {
      originAirportIata: 'BOG',
      destinationAirportIata: 'UIO',
      departureDate,
      status: 'SCHEDULED'
    }
  });

  // 4. Crear el Segmento asociado
  const arrivalDate = new Date('2026-05-30T11:45:00Z');
  await prisma.segment.create({
    data: {
      segmentNumber: 'AV123',
      originAirportId: bogAirport.id,
      destinationAirportId: uioAirport.id,
      departureDateTime: departureDate,
      arrivalDateTime: arrivalDate,
      airlineId: airline.id,
      aircraftId: aircraft.id,
      estimatedDuration: 105,
      flightId: flight.id
    }
  });

  // 5. Crear la Clase de Vuelo
  await prisma.flightClass.create({
    data: {
      flightId: flight.id,
      cabinClass: 'ECONOMY',
      availableSeats: 120,
      basePrice: 150.00
    }
  });

  console.log('¡Vuelo insertado exitosamente!');
  console.log('ID del vuelo:', flight.id);
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

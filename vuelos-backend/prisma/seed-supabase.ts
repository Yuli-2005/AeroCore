import { createRequire } from 'module';
const _require = createRequire(import.meta.url);
const { PrismaClient: CatalogPrisma }  = _require('../prisma-catalog/index.js');
const { PrismaClient: IdentityPrisma } = _require('../prisma-identity/index.js');
const { PrismaClient: BookingPrisma }  = _require('../prisma-booking/index.js');
const { PrismaClient: PaymentsPrisma } = _require('../prisma-payments/index.js');

const catalog  = new CatalogPrisma({ datasources: { db: { url: process.env.CATALOG_DATABASE_URL } } });
const identity = new IdentityPrisma({ datasources: { db: { url: process.env.IDENTITY_DATABASE_URL } } });
const booking  = new BookingPrisma({ datasources: { db: { url: process.env.BOOKING_DATABASE_URL } } });
const payments = new PaymentsPrisma({ datasources: { db: { url: process.env.PAYMENTS_DATABASE_URL } } });

async function main() {
  console.log('🌎 Insertando datos en las 4 bases de datos Supabase...');

  // ── MS_CATALOG: países, ciudades, aeropuertos, aerolíneas, vuelos ──
  const ecuador = await catalog.country.upsert({
    where: { isoCode: 'EC' },
    update: {},
    create: { name: 'Ecuador', isoCode: 'EC', phoneCode: '+593', currencyCode: 'USD' },
  });
  const colombia = await catalog.country.upsert({
    where: { isoCode: 'CO' },
    update: {},
    create: { name: 'Colombia', isoCode: 'CO', phoneCode: '+57', currencyCode: 'COP' },
  });
  const usa = await catalog.country.upsert({
    where: { isoCode: 'US' },
    update: {},
    create: { name: 'Estados Unidos', isoCode: 'US', phoneCode: '+1', currencyCode: 'USD' },
  });
  const peru = await catalog.country.upsert({
    where: { isoCode: 'PE' },
    update: {},
    create: { name: 'Perú', isoCode: 'PE', phoneCode: '+51', currencyCode: 'PEN' },
  });

  const cityQuito = await catalog.city.upsert({
    where: { iataCode: 'UIO' },
    update: {},
    create: { name: 'Quito', iataCode: 'UIO', countryId: ecuador.id },
  });
  const cityBogota = await catalog.city.upsert({
    where: { iataCode: 'BOG' },
    update: {},
    create: { name: 'Bogotá', iataCode: 'BOG', countryId: colombia.id },
  });
  const cityGuayaquil = await catalog.city.upsert({
    where: { iataCode: 'GYE' },
    update: {},
    create: { name: 'Guayaquil', iataCode: 'GYE', countryId: ecuador.id },
  });
  const cityMiami = await catalog.city.upsert({
    where: { iataCode: 'MIA' },
    update: {},
    create: { name: 'Miami', iataCode: 'MIA', countryId: usa.id },
  });
  const cityLima = await catalog.city.upsert({
    where: { iataCode: 'LIM' },
    update: {},
    create: { name: 'Lima', iataCode: 'LIM', countryId: peru.id },
  });

  const airportUIO = await catalog.airport.upsert({
    where: { iataCode: 'UIO' },
    update: {},
    create: { iataCode: 'UIO', name: 'Mariscal Sucre', cityId: cityQuito.id, timezone: 'America/Guayaquil' },
  });
  const airportBOG = await catalog.airport.upsert({
    where: { iataCode: 'BOG' },
    update: {},
    create: { iataCode: 'BOG', name: 'El Dorado', cityId: cityBogota.id, timezone: 'America/Bogota' },
  });
  const airportGYE = await catalog.airport.upsert({
    where: { iataCode: 'GYE' },
    update: {},
    create: { iataCode: 'GYE', name: 'Aeropuerto José Joaquín de Olmedo', cityId: cityGuayaquil.id, timezone: 'America/Guayaquil' },
  });
  const airportMIA = await catalog.airport.upsert({
    where: { iataCode: 'MIA' },
    update: {},
    create: { iataCode: 'MIA', name: 'Aeropuerto Internacional de Miami', cityId: cityMiami.id, timezone: 'America/New_York' },
  });
  const airportLIM = await catalog.airport.upsert({
    where: { iataCode: 'LIM' },
    update: {},
    create: { iataCode: 'LIM', name: 'Aeropuerto Internacional Jorge Chávez', cityId: cityLima.id, timezone: 'America/Lima' },
  });

  console.log('✅ ms_catalog: países, ciudades, aeropuertos');

  const avianca = await catalog.airline.upsert({
    where: { iataCode: 'AV' },
    update: {},
    create: { iataCode: 'AV', name: 'Avianca', countryId: colombia.id },
  });
  const latam = await catalog.airline.upsert({
    where: { iataCode: 'LA' },
    update: {},
    create: { iataCode: 'LA', name: 'LATAM Airlines', countryId: ecuador.id },
  });
  const american = await catalog.airline.upsert({
    where: { iataCode: 'AA' },
    update: {},
    create: { iataCode: 'AA', name: 'American Airlines', countryId: usa.id },
  });

  const a320AV = await catalog.aircraft.upsert({
    where: { registration: 'HC-AV123' },
    update: {},
    create: { airlineId: avianca.id, modelName: 'Airbus A320', registration: 'HC-AV123', hasWifi: true },
  });
  const a320LA = await catalog.aircraft.upsert({
    where: { registration: 'HC-LA456' },
    update: {},
    create: { airlineId: latam.id, modelName: 'Airbus A320', registration: 'HC-LA456', hasUsb: true },
  });
  const b787AA = await catalog.aircraft.upsert({
    where: { registration: 'N-AA789' },
    update: {},
    create: { airlineId: american.id, modelName: 'Boeing 787 Dreamliner', registration: 'N-AA789', hasWifi: true, hasUsb: true },
  });

  console.log('✅ ms_catalog: aerolíneas y aviones');

  const flightsDef = [
    { origin: 'UIO', dest: 'GYE', date: new Date('2026-05-25T12:00:00Z'), airline: latam, aircraft: a320LA, num: 'LA101', dur: 50, classes: [{ cabin: 'ECONOMY', seats: 150, price: 55 }] },
    { origin: 'UIO', dest: 'BOG', date: new Date('2026-05-25T13:00:00Z'), airline: avianca, aircraft: a320AV, num: 'AV201', dur: 95, classes: [{ cabin: 'ECONOMY', seats: 120, price: 135 }, { cabin: 'BUSINESS', seats: 12, price: 380 }] },
    { origin: 'GYE', dest: 'UIO', date: new Date('2026-05-25T15:00:00Z'), airline: latam, aircraft: a320LA, num: 'LA102', dur: 50, classes: [{ cabin: 'ECONOMY', seats: 150, price: 50 }] },
    { origin: 'BOG', dest: 'UIO', date: new Date('2026-05-25T19:00:00Z'), airline: avianca, aircraft: a320AV, num: 'AV202', dur: 95, classes: [{ cabin: 'ECONOMY', seats: 120, price: 140 }, { cabin: 'BUSINESS', seats: 12, price: 390 }] },
    { origin: 'BOG', dest: 'MIA', date: new Date('2026-05-26T14:00:00Z'), airline: american, aircraft: b787AA, num: 'AA901', dur: 230, classes: [{ cabin: 'ECONOMY', seats: 180, price: 290 }, { cabin: 'BUSINESS', seats: 28, price: 650 }] },
    { origin: 'UIO', dest: 'LIM', date: new Date('2026-05-26T16:00:00Z'), airline: latam, aircraft: a320LA, num: 'LA301', dur: 185, classes: [{ cabin: 'ECONOMY', seats: 140, price: 210 }, { cabin: 'BUSINESS', seats: 16, price: 520 }] },
  ];

  const airports: Record<string, any> = { UIO: airportUIO, BOG: airportBOG, GYE: airportGYE, MIA: airportMIA, LIM: airportLIM };

  for (const fd of flightsDef) {
    const existing = await catalog.flight.findFirst({ where: { originAirportIata: fd.origin, destinationAirportIata: fd.dest, departureDate: fd.date } });
    if (existing) continue;

    const arrival = new Date(fd.date.getTime() + fd.dur * 60000);
    const flight = await catalog.flight.create({
      data: {
        originAirportIata: fd.origin,
        destinationAirportIata: fd.dest,
        departureDate: fd.date,
        status: 'SCHEDULED',
        segments: {
          create: {
            segmentNumber: fd.num,
            originAirportId: airports[fd.origin].id,
            destinationAirportId: airports[fd.dest].id,
            departureDateTime: fd.date,
            arrivalDateTime: arrival,
            airlineId: fd.airline.id,
            aircraftId: fd.aircraft.id,
            estimatedDuration: fd.dur,
          },
        },
        flightClasses: {
          create: fd.classes.map((c: any) => ({
            cabinClass: c.cabin,
            availableSeats: c.seats,
            basePrice: c.price,
          })),
        },
      },
    });
  }

  const totalFlights = await catalog.flight.count();
  console.log(`✅ ms_catalog: ${totalFlights} vuelos creados`);

  // ── MS_IDENTITY: usuario demo ──
  const bcrypt = await import('bcryptjs');
  const pass = await bcrypt.hash('Demo@2026', 10);
  await identity.user.upsert({
    where: { email: 'demo@aerocore.com' },
    update: {},
    create: {
      email: 'demo@aerocore.com',
      passwordHash: pass,
      firstName: 'Demo',
      firstLastName: 'Usuario',
      mainAddress: 'Av. Principal 123',
      cityId: cityQuito.id,
      role: 'CUSTOMER',
    },
  });
  console.log('✅ ms_identity: usuario demo creado');

  // ── MS_BOOKING: promoción demo ──
  await booking.promotion.upsert({
    where: { code: 'BIENVENIDO15' },
    update: {},
    create: {
      code: 'BIENVENIDO15',
      discountType: 'PERCENTAGE',
      discountValue: 15,
      maxUsages: 50,
      isActive: true,
    },
  });
  console.log('✅ ms_booking: promoción demo creada');

  console.log('🎉 ¡Datos insertados en las 4 bases de datos Supabase!');
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(async () => {
    await Promise.all([catalog.$disconnect(), identity.$disconnect(), booking.$disconnect(), payments.$disconnect()]);
  });

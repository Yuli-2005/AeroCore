import { PrismaClient, UserRole, FlightStatus, CabinClass, DiscountType } from '../prisma-client/index.js';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando seed robusto de AeroCore (60 vuelos, 5 días)...');

  // 1. PAÍSES (Catálogo Maestro)
  const ecuador = await prisma.country.upsert({
    where: { isoCode: 'EC' },
    update: {},
    create: { name: 'Ecuador', isoCode: 'EC', phoneCode: '+593', currencyCode: 'USD' }
  });

  const colombia = await prisma.country.upsert({
    where: { isoCode: 'CO' },
    update: {},
    create: { name: 'Colombia', isoCode: 'CO', phoneCode: '+57', currencyCode: 'COP' }
  });

  const usa = await prisma.country.upsert({
    where: { isoCode: 'US' },
    update: {},
    create: { name: 'Estados Unidos', isoCode: 'US', phoneCode: '+1', currencyCode: 'USD' }
  });

  // 2. CIUDADES
  const quito = await prisma.city.upsert({
    where: { iataCode: 'UIO' },
    update: {},
    create: { name: 'Quito', countryId: ecuador.id, iataCode: 'UIO' }
  });

  const guayaquil = await prisma.city.upsert({
    where: { iataCode: 'GYE' },
    update: {},
    create: { name: 'Guayaquil', countryId: ecuador.id, iataCode: 'GYE' }
  });

  const bogota = await prisma.city.upsert({
    where: { iataCode: 'BOG' },
    update: {},
    create: { name: 'Bogotá', countryId: colombia.id, iataCode: 'BOG' }
  });

  const miami = await prisma.city.upsert({
    where: { iataCode: 'MIA' },
    update: {},
    create: { name: 'Miami', countryId: usa.id, iataCode: 'MIA' }
  });

  // 3. USUARIOS (Normalizados)
  const adminPassword = await bcrypt.hash('Yuli@2005', 10);
  await prisma.user.upsert({
    where: { email: 'yvgalarza@vuelosapp.com' },
    update: {
      passwordHash: adminPassword,
      firstName: 'Yulieth',
      firstLastName: 'Galarza',
    },
    create: {
      email: 'yvgalarza@vuelosapp.com',
      passwordHash: adminPassword,
      firstName: 'Yulieth',
      firstLastName: 'Galarza',
      mainAddress: 'Av. Amazonas N-100',
      cityId: quito.id,
      role: UserRole.ADMIN,
    },
  });

  // 4. AEROLÍNEAS Y AVIONES
  const avianca = await prisma.airline.upsert({
    where: { iataCode: 'AV' },
    update: {},
    create: { iataCode: 'AV', name: 'Avianca', countryId: colombia.id },
  });

  const latam = await prisma.airline.upsert({
    where: { iataCode: 'LA' },
    update: {},
    create: { iataCode: 'LA', name: 'LATAM Airlines', countryId: ecuador.id },
  });

  const american = await prisma.airline.upsert({
    where: { iataCode: 'AA' },
    update: {},
    create: { iataCode: 'AA', name: 'American Airlines', countryId: usa.id },
  });

  const copa = await prisma.airline.upsert({
    where: { iataCode: 'CM' },
    update: {},
    create: { iataCode: 'CM', name: 'Copa Airlines', countryId: colombia.id }, // Simplificado
  });

  // Aviones
  const aviancaA320 = await prisma.aircraft.upsert({
    where: { registration: 'HC-AV123' },
    update: {},
    create: { modelName: 'Airbus A320', registration: 'HC-AV123', airlineId: avianca.id, hasWifi: true }
  });

  const latamA320 = await prisma.aircraft.upsert({
    where: { registration: 'HC-LA456' },
    update: {},
    create: { modelName: 'Airbus A320', registration: 'HC-LA456', airlineId: latam.id, hasWifi: false, hasUsb: true }
  });

  const americanB787 = await prisma.aircraft.upsert({
    where: { registration: 'N-AA789' },
    update: {},
    create: { modelName: 'Boeing 787 Dreamliner', registration: 'N-AA789', airlineId: american.id, hasWifi: true, hasUsb: true }
  });

  const copaB737 = await prisma.aircraft.upsert({
    where: { registration: 'HP-CM901' },
    update: {},
    create: { modelName: 'Boeing 737 MAX', registration: 'HP-CM901', airlineId: copa.id, hasWifi: true }
  });

  // 5. AEROPUERTOS
  const aptUIO = await prisma.airport.upsert({
    where: { iataCode: 'UIO' },
    update: {},
    create: { iataCode: 'UIO', name: 'Aeropuerto Mariscal Sucre', cityId: quito.id, timezone: 'America/Guayaquil' }
  });

  const aptGYE = await prisma.airport.upsert({
    where: { iataCode: 'GYE' },
    update: {},
    create: { iataCode: 'GYE', name: 'Aeropuerto José Joaquín de Olmedo', cityId: guayaquil.id, timezone: 'America/Guayaquil' }
  });

  const aptBOG = await prisma.airport.upsert({
    where: { iataCode: 'BOG' },
    update: {},
    create: { iataCode: 'BOG', name: 'Aeropuerto El Dorado', cityId: bogota.id, timezone: 'America/Bogota' }
  });

  const aptMIA = await prisma.airport.upsert({
    where: { iataCode: 'MIA' },
    update: {},
    create: { iataCode: 'MIA', name: 'Aeropuerto Internacional de Miami', cityId: miami.id, timezone: 'America/New_York' }
  });

  // 6. PROMOCIONES
  await prisma.promotion.upsert({
    where: { code: 'DESCUENTO10' },
    update: {},
    create: { code: 'DESCUENTO10', discountType: DiscountType.PERCENTAGE, discountValue: 10.00, isActive: true }
  });

  await prisma.promotion.upsert({
    where: { code: 'VIAJERO20' },
    update: {},
    create: { code: 'VIAJERO20', discountType: DiscountType.FIXED_AMOUNT, discountValue: 20.00, isActive: true }
  });

  // 7. CATÁLOGO DE SERVICIOS
  const bag23 = await prisma.serviceCatalog.upsert({
    where: { code: 'BAG_23KG' },
    update: {},
    create: { name: 'Maleta de Bodega 23kg', code: 'BAG_23KG', category: 'BAGGAGE' }
  });

  const bag10 = await prisma.serviceCatalog.upsert({
    where: { code: 'BAG_10KG' },
    update: {},
    create: { name: 'Maleta de Mano 10kg', code: 'BAG_10KG', category: 'BAGGAGE' }
  });

  const seatSel = await prisma.serviceCatalog.upsert({
    where: { code: 'SEAT_SEL' },
    update: {},
    create: { name: 'Selección de Asiento estándar', code: 'SEAT_SEL', category: 'SEATING' }
  });

  // Precios de servicios por aerolínea
  const airlines = [avianca, latam, american, copa];
  const services = [
    { serviceId: bag23.id, price: 35.00 },
    { serviceId: bag10.id, price: 15.00 },
    { serviceId: seatSel.id, price: 8.00 },
  ];

  for (const airline of airlines) {
    for (const s of services) {
      const exists = await prisma.airlineServiceConfig.findFirst({
        where: { serviceId: s.serviceId, airlineId: airline.id }
      });
      if (!exists) {
        await prisma.airlineServiceConfig.create({
          data: { serviceId: s.serviceId, airlineId: airline.id, price: s.price }
        });
      }
    }
  }

  // 8. GENERACIÓN DE VUELOS (60 vuelos en 5 días)
  console.log('🧹 Limpiando vuelos antiguos sin reservas...');
  const flightsWithReservations = await prisma.reservation.findMany({ select: { flightId: true } });
  const flightIdsToKeep = flightsWithReservations.map(r => r.flightId);

  // Borrar segmentos y clases de vuelos viejos asociados a los vuelos que vamos a borrar
  await prisma.segment.deleteMany({
    where: { flightId: { notIn: flightIdsToKeep } }
  });
  await prisma.flightClass.deleteMany({
    where: { flightId: { notIn: flightIdsToKeep } }
  });
  await prisma.flight.deleteMany({
    where: { id: { notIn: flightIdsToKeep } }
  });

  const getFlightDate = (offsetDays: number, hours: number, minutes: number) => {
    const d = new Date();
    d.setDate(d.getDate() + offsetDays);
    d.setHours(hours, minutes, 0, 0);
    return d;
  };

  const getArrivalDate = (departure: Date, durationMinutes: number) => {
    const d = new Date(departure);
    d.setMinutes(d.getMinutes() + durationMinutes);
    return d;
  };

  console.log('✈️ Creando nuevos vuelos...');

  let createdCount = 0;

  for (let day = 0; day < 5; day++) {
    // Definición de vuelos para cada día
    const dailyDefinitions = [
      // 1. UIO ↔ BOG (Avianca & LATAM)
      {
        origin: 'UIO', dest: 'BOG', originAptId: aptUIO.id, destAptId: aptBOG.id,
        depH: 8, depM: 0, duration: 95, num: 'AV201', airlineId: avianca.id, aircraftId: aviancaA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 135.00, seats: 120 }, { class: CabinClass.BUSINESS, price: 380.00, seats: 12 }]
      },
      {
        origin: 'UIO', dest: 'BOG', originAptId: aptUIO.id, destAptId: aptBOG.id,
        depH: 16, depM: 30, duration: 95, num: 'LA601', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 120.00, seats: 140 }, { class: CabinClass.PREMIUM_ECONOMY, price: 180.00, seats: 18 }]
      },
      {
        origin: 'BOG', dest: 'UIO', originAptId: aptBOG.id, destAptId: aptUIO.id,
        depH: 11, depM: 0, duration: 95, num: 'AV202', airlineId: avianca.id, aircraftId: aviancaA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 140.00, seats: 120 }, { class: CabinClass.BUSINESS, price: 390.00, seats: 12 }]
      },
      {
        origin: 'BOG', dest: 'UIO', originAptId: aptBOG.id, destAptId: aptUIO.id,
        depH: 19, depM: 30, duration: 95, num: 'LA602', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 115.00, seats: 140 }, { class: CabinClass.PREMIUM_ECONOMY, price: 175.00, seats: 18 }]
      },

      // 2. UIO ↔ GYE (LATAM)
      {
        origin: 'UIO', dest: 'GYE', originAptId: aptUIO.id, destAptId: aptGYE.id,
        depH: 7, depM: 0, duration: 50, num: 'LA101', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 55.00, seats: 150 }]
      },
      {
        origin: 'UIO', dest: 'GYE', originAptId: aptUIO.id, destAptId: aptGYE.id,
        depH: 18, depM: 0, duration: 50, num: 'LA103', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 65.00, seats: 150 }]
      },
      {
        origin: 'GYE', dest: 'UIO', originAptId: aptGYE.id, destAptId: aptUIO.id,
        depH: 8, depM: 30, duration: 50, num: 'LA102', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 50.00, seats: 150 }]
      },
      {
        origin: 'GYE', dest: 'UIO', originAptId: aptGYE.id, destAptId: aptUIO.id,
        depH: 19, depM: 30, duration: 50, num: 'LA104', airlineId: latam.id, aircraftId: latamA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 60.00, seats: 150 }]
      },

      // 3. BOG ↔ MIA (American & Avianca)
      {
        origin: 'BOG', dest: 'MIA', originAptId: aptBOG.id, destAptId: aptMIA.id,
        depH: 9, depM: 0, duration: 230, num: 'AA901', airlineId: american.id, aircraftId: americanB787.id,
        prices: [{ class: CabinClass.ECONOMY, price: 290.00, seats: 180 }, { class: CabinClass.BUSINESS, price: 650.00, seats: 28 }, { class: CabinClass.FIRST, price: 1200.00, seats: 8 }]
      },
      {
        origin: 'MIA', dest: 'BOG', originAptId: aptMIA.id, destAptId: aptBOG.id,
        depH: 14, depM: 30, duration: 230, num: 'AV402', airlineId: avianca.id, aircraftId: aviancaA320.id,
        prices: [{ class: CabinClass.ECONOMY, price: 280.00, seats: 120 }, { class: CabinClass.BUSINESS, price: 580.00, seats: 12 }]
      },

      // 4. UIO ↔ MIA (American)
      {
        origin: 'UIO', dest: 'MIA', originAptId: aptUIO.id, destAptId: aptMIA.id,
        depH: 13, depM: 0, duration: 250, num: 'AA501', airlineId: american.id, aircraftId: americanB787.id,
        prices: [{ class: CabinClass.ECONOMY, price: 320.00, seats: 180 }, { class: CabinClass.BUSINESS, price: 720.00, seats: 28 }]
      },
      {
        origin: 'MIA', dest: 'UIO', originAptId: aptMIA.id, destAptId: aptUIO.id,
        depH: 20, depM: 0, duration: 250, num: 'AA502', airlineId: american.id, aircraftId: americanB787.id,
        prices: [{ class: CabinClass.ECONOMY, price: 310.00, seats: 180 }, { class: CabinClass.BUSINESS, price: 700.00, seats: 28 }]
      }
    ];

    for (const def of dailyDefinitions) {
      const depDate = getFlightDate(day, def.depH, def.depM);
      const arrDate = getArrivalDate(depDate, def.duration);

      await prisma.flight.create({
        data: {
          originAirportIata: def.origin,
          destinationAirportIata: def.dest,
          departureDate: depDate,
          status: FlightStatus.SCHEDULED,
          segments: {
            create: {
              segmentNumber: def.num,
              originAirportId: def.originAptId,
              destinationAirportId: def.destAptId,
              departureDateTime: depDate,
              arrivalDateTime: arrDate,
              airlineId: def.airlineId,
              aircraftId: def.aircraftId,
              estimatedDuration: def.duration
            }
          },
          flightClasses: {
            create: def.prices.map(p => ({
              cabinClass: p.class,
              availableSeats: p.seats,
              basePrice: p.price
            }))
          }
        }
      });
      createdCount++;
    }
  }

  console.log(`✅ Seed completado exitosamente. Se crearon ${createdCount} vuelos distribuidos en 5 días.`);
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
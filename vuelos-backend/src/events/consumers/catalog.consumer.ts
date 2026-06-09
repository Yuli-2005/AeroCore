// events/consumers/catalog.consumer.ts
// Escucha booking.cancelled y restaura availableSeats en ms_catalog.
//
// NOTA DE DISEÑO:
// booking.created NO se maneja aquí porque ReservationRepository.create()
// ya resta los asientos de forma síncrona antes de crear la reserva
// (necesario para evitar sobreventa). Si lo hiciéramos también aquí,
// los asientos se restarían dos veces.
// booking.cancelled SÍ se maneja aquí porque reemplaza la llamada directa
// a catalogDb que tenía ReservationRepository.cancelAndRestoreSeats().
import { getChannel }   from '../rabbitmq/connection.js';
import { QUEUES }       from '../rabbitmq/topology.js';
import { EVENTS }       from '../events.types.js';
import { catalogDb }    from '../../shared/database/clients.js';

export async function startCatalogConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.prefetch(1);

  await channel.consume(QUEUES.CATALOG_SEATS, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data } = envelope;
      const { flightClassId, passengerCount } = data;

      if (eventType === EVENTS.BOOKING_CANCELLED && flightClassId && passengerCount > 0) {
        await catalogDb.flightClass.update({
          where: { id: flightClassId },
          data:  { availableSeats: { increment: passengerCount } },
        });
        console.log(`[catalog.consumer] seats +${passengerCount} restaurados en flightClass ${flightClassId}`);
      }

      channel.ack(msg);

    } catch (err: any) {
      console.error('[catalog.consumer] error:', err.message);
      channel.nack(msg, false, false);
    }
  });

  console.log(`[catalog.consumer] ✅ escuchando cola "${QUEUES.CATALOG_SEATS}"`);
}

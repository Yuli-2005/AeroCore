// events/consumers/catalog.consumer.ts
// Escucha booking.* y actualiza availableSeats en ms_catalog.
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

      if (eventType === EVENTS.BOOKING_CREATED) {
        // Reserva creada → restar asientos
        await catalogDb.flightClass.update({
          where: { id: flightClassId },
          data:  { availableSeats: { decrement: passengerCount } },
        });
        console.log(`[catalog.consumer] seats -${passengerCount} en flightClass ${flightClassId}`);

      } else if (eventType === EVENTS.BOOKING_CANCELLED) {
        // Reserva cancelada → devolver asientos
        await catalogDb.flightClass.update({
          where: { id: flightClassId },
          data:  { availableSeats: { increment: passengerCount } },
        });
        console.log(`[catalog.consumer] seats +${passengerCount} en flightClass ${flightClassId}`);
      }

      channel.ack(msg);

    } catch (err: any) {
      console.error('[catalog.consumer] error:', err.message);
      channel.nack(msg, false, false); // mensaje fallido → DLQ
    }
  });

  console.log(`[catalog.consumer] ✅ escuchando cola "${QUEUES.CATALOG_SEATS}"`);
}

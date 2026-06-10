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
import { getChannel }            from '../rabbitmq/connection.js';
import { QUEUES }                from '../rabbitmq/topology.js';
import { EVENTS }                from '../events.types.js';
import { catalogDb }             from '../../shared/database/clients.js';
import { availabilityEmitter }   from '../availability.emitter.js';
import { isAlreadyProcessed, markAsProcessed } from '../idempotency.js';
import { recordProcessed, recordDuplicate, recordError } from '../bus.metrics.js';

export async function startCatalogConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.prefetch(1);

  await channel.consume(QUEUES.CATALOG_SEATS, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data, messageId } = envelope;
      const { flightClassId, passengerCount } = data;

      // Idempotencia: descarta duplicados
      if (messageId && isAlreadyProcessed(messageId)) {
        console.log(`[catalog.consumer] duplicado ignorado messageId=${messageId}`);
        recordDuplicate('catalog');
        channel.ack(msg);
        return;
      }

      if (eventType === EVENTS.BOOKING_CANCELLED && flightClassId && passengerCount > 0) {
        const updated = await catalogDb.flightClass.update({
          where: { id: flightClassId },
          data:  { availableSeats: { increment: passengerCount } },
        });
        console.log(`[catalog.consumer] seats +${passengerCount} restaurados en flightClass ${flightClassId}`);
        availabilityEmitter.emit('update', {
          flightClassId,
          flightId:       updated.flightId,
          availableSeats: updated.availableSeats,
        });
        // markAsProcessed solo cuando el trabajo se completó correctamente
        if (messageId) markAsProcessed(messageId);
      }

      recordProcessed('catalog', eventType);
      channel.ack(msg);

    } catch (err: any) {
      console.error('[catalog.consumer] error:', err.message);
      recordError('catalog');
      channel.nack(msg, false, false);
    }
  });

  console.log(`[catalog.consumer] ✅ escuchando cola "${QUEUES.CATALOG_SEATS}"`);
}

// events/consumers/booking.consumer.ts
// Escucha payment.* y actualiza el status de la reserva en ms_booking.
import { getChannel }  from '../rabbitmq/connection.js';
import { QUEUES }      from '../rabbitmq/topology.js';
import { EVENTS }      from '../events.types.js';
import { bookingDb }   from '../../shared/database/clients.js';
import { publishBookingCancelled } from '../producers/booking.producer.js';
import { isAlreadyProcessed, markAsProcessed } from '../idempotency.js';
import { recordProcessed, recordDuplicate, recordError } from '../bus.metrics.js';

export async function startBookingConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.prefetch(1);

  await channel.consume(QUEUES.BOOKING_STATUS, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data, messageId } = envelope;
      const { reservationId } = data;

      // Idempotencia: descarta duplicados
      if (messageId && isAlreadyProcessed(messageId)) {
        console.log(`[booking.consumer] duplicado ignorado messageId=${messageId}`);
        recordDuplicate('booking');
        channel.ack(msg);
        return;
      }

      if (eventType === EVENTS.PAYMENT_CONFIRMED) {
        await bookingDb.reservation.update({
          where: { id: reservationId },
          data:  { status: 'CONFIRMED' },
        });
        console.log(`[booking.consumer] reserva ${reservationId} → CONFIRMED`);

      } else if (eventType === EVENTS.PAYMENT_FAILED) {
        // Leer reserva con pasajeros ANTES de cancelar para obtener los datos del evento
        const reservation = await bookingDb.reservation.findUnique({
          where:   { id: reservationId },
          include: { passengers: true },
        });

        await bookingDb.reservation.update({
          where: { id: reservationId },
          data:  { status: 'CANCELLED' },
        });
        console.log(`[booking.consumer] reserva ${reservationId} → CANCELLED (pago fallido)`);

        // Publicar booking.cancelled para que catalog.consumer restaure los asientos
        if (reservation) {
          const flightClassId  = (reservation as any).passengers?.[0]?.flightClassId ?? null;
          const passengerCount = (reservation as any).passengers?.length ?? 0;
          if (flightClassId && passengerCount > 0) {
            publishBookingCancelled({
              reservationId,
              reservationCode: (reservation as any).reservationCode,
              flightClassId,
              passengerCount,
              promotionId: (reservation as any).promotionId ?? null,
            });
          }
        }
      }

      if (messageId) markAsProcessed(messageId);
      recordProcessed('booking', eventType);
      channel.ack(msg);

    } catch (err: any) {
      console.error('[booking.consumer] error:', err.message);
      recordError('booking');
      channel.nack(msg, false, false);
    }
  });

  console.log(`[booking.consumer] ✅ escuchando cola "${QUEUES.BOOKING_STATUS}"`);
}

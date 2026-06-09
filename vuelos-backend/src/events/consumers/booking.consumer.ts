// events/consumers/booking.consumer.ts
// Escucha payment.* y actualiza el status de la reserva en ms_booking.
import { getChannel }  from '../rabbitmq/connection.js';
import { QUEUES }      from '../rabbitmq/topology.js';
import { EVENTS }      from '../events.types.js';
import { bookingDb }   from '../../shared/database/clients.js';

export async function startBookingConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.prefetch(1);

  await channel.consume(QUEUES.BOOKING_STATUS, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data } = envelope;
      const { reservationId } = data;

      if (eventType === EVENTS.PAYMENT_CONFIRMED) {
        await bookingDb.reservation.update({
          where: { id: reservationId },
          data:  { status: 'CONFIRMED' },
        });
        console.log(`[booking.consumer] reserva ${reservationId} → CONFIRMED`);

      } else if (eventType === EVENTS.PAYMENT_FAILED) {
        await bookingDb.reservation.update({
          where: { id: reservationId },
          data:  { status: 'CANCELLED' },
        });
        console.log(`[booking.consumer] reserva ${reservationId} → CANCELLED (pago fallido)`);
      }

      channel.ack(msg);

    } catch (err: any) {
      console.error('[booking.consumer] error:', err.message);
      channel.nack(msg, false, false);
    }
  });

  console.log(`[booking.consumer] ✅ escuchando cola "${QUEUES.BOOKING_STATUS}"`);
}

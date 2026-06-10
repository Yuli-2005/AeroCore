// events/consumers/payments.consumer.ts
// Escucha booking.created y pre-crea la factura PENDING en ms_payments.
import { getChannel }   from '../rabbitmq/connection.js';
import { QUEUES }       from '../rabbitmq/topology.js';
import { paymentsDb }   from '../../shared/database/clients.js';
import { recordProcessed, recordDuplicate, recordError } from '../bus.metrics.js';

export async function startPaymentsConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.prefetch(1);

  await channel.consume(QUEUES.PAYMENTS_INVOICE, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data } = envelope;
      const { reservationId, totalAmount } = data;

      // Idempotencia via DB: si ya existe un pago para esta reserva, ignorar
      const existing = await paymentsDb.payment.findUnique({
        where: { reservationId },
      }).catch(() => null);

      if (existing) {
        console.log(`[payments.consumer] pago ya existe para reserva ${reservationId} — ignorando`);
        recordDuplicate('payments');
        channel.ack(msg);
        return;
      }

      // Guarda el monto esperado para validar cuando llegue el pago real
      console.log(`[payments.consumer] reserva ${reservationId} lista para pago — monto: $${totalAmount}`);

      recordProcessed('payments', eventType);
      channel.ack(msg);

    } catch (err: any) {
      console.error('[payments.consumer] error:', err.message);
      recordError('payments');
      channel.nack(msg, false, false);
    }
  });

  console.log(`[payments.consumer] ✅ escuchando cola "${QUEUES.PAYMENTS_INVOICE}"`);
}

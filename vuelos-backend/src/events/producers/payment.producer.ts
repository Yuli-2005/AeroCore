// events/producers/payment.producer.ts
// Publica eventos de pagos al bus. Llamado desde PaymentService.
import { randomUUID }  from 'crypto';
import { getChannel }  from '../rabbitmq/connection.js';
import { EXCHANGE }    from '../rabbitmq/topology.js';
import {
  EVENTS,
  type PaymentConfirmedPayload,
  type PaymentFailedPayload,
  type EventEnvelope,
} from '../events.types.js';

function publish<T>(routingKey: string, data: T): void {
  try {
    const envelope: EventEnvelope<T> = {
      messageId:  randomUUID(),
      eventType:  routingKey as any,
      occurredAt: new Date().toISOString(),
      source:     'ms_payments',
      data,
    };
    getChannel().publish(
      EXCHANGE,
      routingKey,
      Buffer.from(JSON.stringify(envelope)),
      { persistent: true, contentType: 'application/json' },
    );
  } catch (err: any) {
    console.warn(`[payment.producer] no se pudo publicar "${routingKey}":`, err.message);
  }
}

export function publishPaymentConfirmed(data: PaymentConfirmedPayload): void {
  publish(EVENTS.PAYMENT_CONFIRMED, data);
  console.log(`[payment.producer] → ${EVENTS.PAYMENT_CONFIRMED} pago=${data.paymentId}`);
}

export function publishPaymentFailed(data: PaymentFailedPayload): void {
  publish(EVENTS.PAYMENT_FAILED, data);
  console.log(`[payment.producer] → ${EVENTS.PAYMENT_FAILED} pago=${data.paymentId}`);
}

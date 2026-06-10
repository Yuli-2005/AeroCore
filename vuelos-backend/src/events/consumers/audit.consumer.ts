// events/consumers/audit.consumer.ts
// Escucha TODOS los eventos del bus y los registra en audit_logs (ms_identity).
import { getChannel }  from '../rabbitmq/connection.js';
import { QUEUES }      from '../rabbitmq/topology.js';
import { identityDb }  from '../../shared/database/clients.js';
import { isAlreadyProcessed, markAsProcessed } from '../idempotency.js';
import { recordProcessed, recordDuplicate, recordError } from '../bus.metrics.js';

export async function startAuditConsumer(): Promise<void> {
  const channel = getChannel();

  // Un mensaje a la vez — evita saturar la DB de identity
  await channel.prefetch(1);

  await channel.consume(QUEUES.AUDIT_LOG, async (msg: any) => {
    if (!msg) return;

    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, source, occurredAt, data, messageId } = envelope;

      // Idempotencia: descarta duplicados (evita entradas dobles en audit_logs)
      if (messageId && isAlreadyProcessed(messageId)) {
        console.log(`[audit.consumer] duplicado ignorado messageId=${messageId}`);
        recordDuplicate('audit');
        channel.ack(msg);
        return;
      }

      await identityDb.auditLog.create({
        data: {
          action:    eventType,
          entity:    source ?? eventType.split('.')[0],
          entityId:  data?.reservationId ?? data?.paymentId ?? messageId ?? 'unknown',
          newData:   data,
          createdAt: new Date(occurredAt),
        },
      });

      if (messageId) markAsProcessed(messageId);
      recordProcessed('audit', eventType);
      channel.ack(msg);

    } catch (err: any) {
      console.error('[audit.consumer] error:', err.message);
      recordError('audit');
      // requeue: false → si falla, va al DLQ en vez de reintentar infinito
      channel.nack(msg, false, false);
    }
  });

  console.log(`[audit.consumer] ✅ escuchando cola "${QUEUES.AUDIT_LOG}"`);
}

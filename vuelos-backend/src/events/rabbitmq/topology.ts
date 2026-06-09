// events/rabbitmq/topology.ts
// Define y crea todos los exchanges, colas y bindings en RabbitMQ.
// Se ejecuta una sola vez al arrancar el servidor.
import type { Channel } from 'amqplib';

// ── Nombres centralizados ────────────────────────────────────────────────────
export const EXCHANGE     = 'vuelos.events';   // exchange principal (topic)
export const DEAD_LETTER  = 'vuelos.dlx';      // exchange para mensajes fallidos

export const QUEUES = {
  CATALOG_SEATS:     'catalog.seat-queue',      // actualiza availableSeats
  BOOKING_STATUS:    'booking.status-queue',    // cambia estado de reserva
  PAYMENTS_INVOICE:  'payments.invoice-queue',  // genera factura
  AUDIT_LOG:         'audit.log-queue',         // registra en audit_logs
  GRAPHQL_PUBSUB:    'graphql.pubsub-queue',    // broadcast a subscriptions WS
  DLQ_FAILED:        'dlq.failed-queue',        // mensajes que fallaron 3 veces
} as const;

// ── Setup completo ───────────────────────────────────────────────────────────
export async function setupTopology(channel: Channel): Promise<void> {

  // 1. Dead Letter Exchange — recibe mensajes que fallaron demasiadas veces
  await channel.assertExchange(DEAD_LETTER, 'direct', { durable: true });

  // 2. Exchange principal tipo topic — enruta por patrón de routing key
  await channel.assertExchange(EXCHANGE, 'topic', { durable: true });

  // 3. Colas con sus configuraciones
  const queues: Array<{
    name:    string;
    binding: string;
    dlq:     boolean;
    durable: boolean;
  }> = [
    {
      name:    QUEUES.CATALOG_SEATS,
      binding: 'booking.*',       // booking.created y booking.cancelled
      dlq:     true,
      durable: true,
    },
    {
      name:    QUEUES.BOOKING_STATUS,
      binding: 'payment.*',       // payment.confirmed y payment.failed
      dlq:     true,
      durable: true,
    },
    {
      name:    QUEUES.PAYMENTS_INVOICE,
      binding: 'booking.created', // solo al crear, no al cancelar
      dlq:     true,
      durable: true,
    },
    {
      name:    QUEUES.AUDIT_LOG,
      binding: '#',               // TODOS los eventos
      dlq:     false,             // audit es best-effort, no necesita DLQ
      durable: true,
    },
    {
      name:    QUEUES.GRAPHQL_PUBSUB,
      binding: 'seat.*',          // seat.updated → Subscription WebSocket
      dlq:     false,
      durable: false,             // efímero: si el server cae, no importa
    },
  ];

  for (const q of queues) {
    await channel.assertQueue(q.name, {
      durable: q.durable,
      arguments: q.dlq ? {
        'x-dead-letter-exchange':    DEAD_LETTER,
        'x-dead-letter-routing-key': `dlq.${q.name}`,
        'x-message-ttl':             30_000,  // 30s máximo en cola
      } : {},
    });
    await channel.bindQueue(q.name, EXCHANGE, q.binding);
  }

  // 4. Cola de mensajes fallidos (DLQ) — para revisión manual
  await channel.assertQueue(QUEUES.DLQ_FAILED, { durable: true });
  await channel.bindQueue(QUEUES.DLQ_FAILED, DEAD_LETTER, '#');

  console.log('[RabbitMQ] exchanges, colas y bindings creados:');
  console.log(`  exchange: ${EXCHANGE} (topic)`);
  for (const q of queues) {
    console.log(`  cola: ${q.name.padEnd(28)} ← binding: "${q.binding}"`);
  }
}

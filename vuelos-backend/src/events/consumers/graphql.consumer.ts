// events/consumers/graphql.consumer.ts
// Escucha la cola graphql.pubsub-queue (binding: seat.*) y reemite los eventos
// al availabilityEmitter para que los clientes GraphQL suscritos los reciban.
import { getChannel }          from '../rabbitmq/connection.js';
import { QUEUES }              from '../rabbitmq/topology.js';
import { availabilityEmitter } from '../availability.emitter.js';
import { recordProcessed, recordError } from '../bus.metrics.js';

export async function startGraphqlConsumer(): Promise<void> {
  const channel = getChannel();

  await channel.consume(QUEUES.GRAPHQL_PUBSUB, (msg: any) => {
    if (!msg) return;
    try {
      const envelope = JSON.parse(msg.content.toString());
      const { eventType, data } = envelope;

      if (data?.flightClassId && data?.flightId && data?.availableSeats !== undefined) {
        availabilityEmitter.emit('update', {
          flightClassId:  data.flightClassId,
          flightId:       data.flightId,
          availableSeats: data.availableSeats,
        });
      }

      recordProcessed('graphql' as any, eventType ?? 'seat.updated');
      channel.ack(msg);
    } catch (err: any) {
      console.error('[graphql.consumer] error:', err.message);
      recordError('graphql' as any);
      channel.nack(msg, false, false);
    }
  });

  console.log(`[graphql.consumer] ✅ escuchando cola "${QUEUES.GRAPHQL_PUBSUB}"`);
}
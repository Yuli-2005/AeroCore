// graphql/schema.ts
// Schema GraphQL con Subscription para disponibilidad de asientos en tiempo real.
// Los eventos llegan desde catalog.consumer → availabilityEmitter → GraphQL clients.
import { createSchema } from 'graphql-yoga';
import { availabilityEmitter } from '../events/availability.emitter.js';

export const schema = createSchema({
  typeDefs: `
    type Query {
      _health: String!
    }

    type AvailabilityUpdate {
      flightClassId: String!
      flightId:      String!
      availableSeats: Int!
    }

    type Subscription {
      """
      Se emite cada vez que cambia el número de asientos disponibles en un vuelo.
      Si se pasa flightId, solo se reciben actualizaciones de ese vuelo.
      Si no se pasa, se reciben todas.
      """
      seatAvailabilityUpdated(flightId: String): AvailabilityUpdate!
    }
  `,

  resolvers: {
    Query: {
      _health: () => 'ok',
    },

    Subscription: {
      seatAvailabilityUpdated: {
        subscribe: async function* (_: unknown, { flightId }: { flightId?: string }) {
          const queue: { flightClassId: string; flightId: string; availableSeats: number }[] = [];
          let notify: (() => void) | null = null;

          const onUpdate = (update: { flightClassId: string; flightId: string; availableSeats: number }) => {
            if (!flightId || update.flightId === flightId) {
              queue.push(update);
              notify?.();
              notify = null;
            }
          };

          availabilityEmitter.on('update', onUpdate);

          try {
            while (true) {
              if (queue.length > 0) {
                yield { seatAvailabilityUpdated: queue.shift()! };
              } else {
                await new Promise<void>(resolve => { notify = resolve; });
              }
            }
          } finally {
            availabilityEmitter.off('update', onUpdate);
          }
        },
      },
    },
  },
});
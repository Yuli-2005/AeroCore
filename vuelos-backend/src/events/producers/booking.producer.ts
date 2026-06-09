// events/producers/booking.producer.ts
// Publica eventos de reservas al bus. Llamado desde ReservationService.
import { randomUUID }  from 'crypto';
import { getChannel }  from '../rabbitmq/connection.js';
import { EXCHANGE }    from '../rabbitmq/topology.js';
import {
  EVENTS,
  type BookingCreatedPayload,
  type BookingCancelledPayload,
  type EventEnvelope,
} from '../events.types.js';

function publish<T>(routingKey: string, data: T): void {
  try {
    const envelope: EventEnvelope<T> = {
      messageId:  randomUUID(),
      eventType:  routingKey as any,
      occurredAt: new Date().toISOString(),
      source:     'ms_booking',
      data,
    };
    getChannel().publish(
      EXCHANGE,
      routingKey,
      Buffer.from(JSON.stringify(envelope)),
      { persistent: true, contentType: 'application/json' },
    );
  } catch (err: any) {
    // El bus nunca bloquea la operación principal
    console.warn(`[booking.producer] no se pudo publicar "${routingKey}":`, err.message);
  }
}

export function publishBookingCreated(data: BookingCreatedPayload): void {
  publish(EVENTS.BOOKING_CREATED, data);
  console.log(`[booking.producer] → ${EVENTS.BOOKING_CREATED} reserva=${data.reservationId}`);
}

export function publishBookingCancelled(data: BookingCancelledPayload): void {
  publish(EVENTS.BOOKING_CANCELLED, data);
  console.log(`[booking.producer] → ${EVENTS.BOOKING_CANCELLED} reserva=${data.reservationId}`);
}

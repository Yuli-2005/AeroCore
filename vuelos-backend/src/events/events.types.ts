// events/events.types.ts
// Contratos TypeScript de cada evento del bus.
// Productor y consumidor usan los mismos tipos — si uno cambia, TypeScript avisa.

// ── Routing keys ────────────────────────────────────────────────────────────
export const EVENTS = {
  BOOKING_CREATED:       'booking.created',
  BOOKING_CANCELLED:     'booking.cancelled',
  PAYMENT_CONFIRMED:     'payment.confirmed',
  PAYMENT_FAILED:        'payment.failed',
  SEAT_UPDATED:          'seat.updated',
} as const;

export type EventName = typeof EVENTS[keyof typeof EVENTS];

// ── Envelope base (todo mensaje lleva esto) ──────────────────────────────────
export interface EventEnvelope<T> {
  messageId:     string;      // UUID único — usado para idempotencia
  eventType:     EventName;
  occurredAt:    string;      // ISO 8601
  source:        string;      // microservicio que lo publicó
  data:          T;
}

// ── Payloads por evento ──────────────────────────────────────────────────────

export interface BookingCreatedPayload {
  reservationId:   string;
  reservationCode: string;
  flightClassId:   string;
  flightId:        string;
  userId:          string;
  passengerCount:  number;
  totalAmount:     number;
  promotionId:     string | null;
}

export interface BookingCancelledPayload {
  reservationId:   string;
  reservationCode: string;
  flightClassId:   string;
  passengerCount:  number;
  promotionId:     string | null;
}

export interface PaymentConfirmedPayload {
  paymentId:      string;
  reservationId:  string;
  userId:         string;
  amount:         number;
  provider:       string;
  userEmail?:     string;
  userFullName?:  string;
  userAddress?:   string;
  cityId?:        string;
}

export interface PaymentFailedPayload {
  paymentId:     string;
  reservationId: string;
  reason:        string;
}

export interface SeatUpdatedPayload {
  flightClassId:  string;
  flightId:       string;
  availableSeats: number;
  cabinClass:     string;
}

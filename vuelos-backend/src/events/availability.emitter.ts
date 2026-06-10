import { EventEmitter } from 'events';

export interface AvailabilityUpdate {
  flightClassId: string;
  flightId: string;
  availableSeats: number;
}

class AvailabilityEmitter extends EventEmitter {}

export const availabilityEmitter = new AvailabilityEmitter();

// infrastructure/repositories/ReservationRepository.ts
import { IReservationRepository } from '../interfaces/IReservationRepository.js';
import { Reservation } from '../entities/Reservation.js';
import { PagedResult } from '../../../shared/interfaces/IBaseRepository.js';

const bookingInclude = {
  passengers: true,
  promotion: true,
};

const flightInclude = {
  segments: {
    include: {
      originAirport: { include: { city: { include: { country: true } } } },
      destinationAirport: { include: { city: { include: { country: true } } } },
      airline: true,
      aircraft: true,
    },
    orderBy: { departureDateTime: 'asc' as const },
  },
  flightClasses: { orderBy: { basePrice: 'asc' as const } },
};

export class ReservationRepository implements IReservationRepository {
  constructor(
    private readonly db: any,       // bookingDb
    private readonly catalogDb: any // catalogDb — for flightClass seat updates
  ) {}

  async findAll(page = 1, limit = 100): Promise<PagedResult<Reservation>> {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.db.reservation.findMany({ skip, take: limit, orderBy: { createdAt: 'desc' } }),
      this.db.reservation.count(),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) } as any;
  }

  private async enrichWithFlight(reservation: any): Promise<any> {
    if (!reservation?.flightId) return reservation;
    try {
      const flight = await this.catalogDb.flight.findUnique({
        where: { id: reservation.flightId },
        include: flightInclude,
      });
      return { ...reservation, flight };
    } catch {
      return reservation;
    }
  }

  async findById(id: string): Promise<Reservation | null> {
    return this.db.reservation.findUnique({ where: { id } }) as any;
  }

  async findByUserId(userId: string): Promise<any[]> {
    const reservations = await this.db.reservation.findMany({
      where: { userId },
      include: bookingInclude,
      orderBy: { createdAt: 'desc' },
    });
    return Promise.all(reservations.map((r: any) => this.enrichWithFlight(r)));
  }

  async findByIdWithRelations(id: string): Promise<any | null> {
    const reservation = await this.db.reservation.findUnique({ where: { id }, include: bookingInclude });
    return this.enrichWithFlight(reservation);
  }

  async findAllWithRelations(): Promise<any[]> {
    const reservations = await this.db.reservation.findMany({ include: bookingInclude, orderBy: { createdAt: 'desc' } });
    return Promise.all(reservations.map((r: any) => this.enrichWithFlight(r)));
  }

  async updateStatus(id: string, status: string): Promise<void> {
    await this.db.reservation.update({ where: { id }, data: { status: status as any } });
  }

  async create(data: any): Promise<Reservation> {
    // Step 1: decrement seats in catalogDb (separate DB — cannot share transaction)
    const seatsReserved = await this.catalogDb.flightClass.updateMany({
      where: {
        id: data.flightClassId,
        availableSeats: { gte: data.passengerCount },
      },
      data: { availableSeats: { decrement: data.passengerCount } },
    });
    if (seatsReserved.count !== 1) {
      throw new Error('NO_AVAILABILITY');
    }

    // Step 2: create reservation + update promotion in bookingDb transaction
    try {
      const reservation = await this.db.$transaction(async (tx: any) => {
        const res = await tx.reservation.create({
          data: {
            reservationCode: data.reservationCode,
            userId: data.userId,
            flightId: data.flightId,
            promotionId: data.promotionId,
            totalAmount: data.totalAmount,
            status: data.status,
            passengers: {
              create: data.passengers.map((p: any) => ({
                flightClassId: data.flightClassId,
                firstName: p.firstName,
                lastName: p.lastName,
                documentNumber: p.documentNumber,
                seatNumber: p.seatNumber ?? null,
              })),
            },
          },
          include: bookingInclude,
        });

        if (data.promotionId_forUsageIncrement) {
          await tx.promotion.update({
            where: { id: data.promotionId_forUsageIncrement },
            data: { currentUsages: { increment: 1 } },
          });
        }

        return res;
      }, { maxWait: 15000, timeout: 25000 });

      return reservation as any;
    } catch (err) {
      // Rollback seat decrement if booking creation failed
      await this.catalogDb.flightClass.update({
        where: { id: data.flightClassId },
        data: { availableSeats: { increment: data.passengerCount } },
      }).catch(() => {});
      throw err;
    }
  }

  async cancelAndRestoreSeats(id: string, flightClassId: string, passengerCount: number): Promise<void> {
    // Update booking status in bookingDb
    await this.db.$transaction(async (tx: any) => {
      await tx.reservation.update({ where: { id }, data: { status: 'CANCELLED' } });
      await tx.reservationPassenger.updateMany({
        where: { reservationId: id },
        data: { seatNumber: null },
      });
    }, { maxWait: 15000, timeout: 25000 });

    // Restore seats in catalogDb
    if (flightClassId && passengerCount > 0) {
      await this.catalogDb.flightClass.update({
        where: { id: flightClassId },
        data: { availableSeats: { increment: passengerCount } },
      });
    }
  }

  async update(id: string, data: any): Promise<Reservation> {
    return this.db.reservation.update({ where: { id }, data }) as any;
  }

  async delete(id: string): Promise<void> {
    await this.db.reservation.delete({ where: { id } });
  }
}

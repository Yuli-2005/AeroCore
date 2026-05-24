// infrastructure/queries/ReservationQueryRepository.ts
export class ReservationQueryRepository {
  constructor(private readonly db: any) {}

  async getDashboardStats() {
    const [totalReservations, confirmedReservations, cancelledReservations, totalRevenue] =
      await Promise.all([
        this.db.reservation.count(),
        this.db.reservation.count({ where: { status: 'CONFIRMED' } }),
        this.db.reservation.count({ where: { status: 'CANCELLED' } }),
        this.db.reservation.aggregate({
          where: { status: 'CONFIRMED' },
          _sum: { totalAmount: true },
        }),
      ]);

    return {
      totalReservations,
      confirmedReservations,
      cancelledReservations,
      totalRevenue: Number(totalRevenue._sum.totalAmount ?? 0),
    };
  }

  async getReservationsByUser(userId: string) {
    return this.db.reservation.findMany({
      where: { userId },
      include: {
        passengers: true,
        promotion: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}

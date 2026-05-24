// infrastructure/queries/PaymentQueryRepository.ts

export class PaymentQueryRepository {
  constructor(private readonly db: any) {}

  async getStats() {
    const [total, byStatus, totalRevenue] = await Promise.all([
      this.db.payment.count(),
      this.db.payment.groupBy({ by: ['status'], _count: { id: true }, _sum: { amount: true } }),
      this.db.payment.aggregate({ _sum: { amount: true } }),
    ]);
    return {
      total,
      byStatus,
      totalRevenue: Number(totalRevenue._sum.amount ?? 0),
    };
  }

  async findByReservation(reservationId: string) {
    return this.db.payment.findMany({
      where: { reservationId },
      include: { invoice: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findAll() {
    return this.db.payment.findMany({
      include: { invoice: true },
      orderBy: { createdAt: 'desc' },
    });
  }
}

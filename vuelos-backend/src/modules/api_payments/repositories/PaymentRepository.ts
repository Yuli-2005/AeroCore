// infrastructure/repositories/PaymentRepository.ts
import { IPaymentRepository } from '../interfaces/IPaymentRepository.js';
import { Payment } from '../entities/Payment.js';
import { PagedResult } from '../../../shared/interfaces/IBaseRepository.js';

export class PaymentRepository implements IPaymentRepository {
  constructor(private readonly db: any) {}

  async findAll(page = 1, limit = 100): Promise<PagedResult<Payment>> {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.db.payment.findMany({ skip, take: limit, include: { invoice: true }, orderBy: { createdAt: 'desc' } }),
      this.db.payment.count(),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) } as any;
  }

  async findById(id: string): Promise<Payment | null> {
    return this.db.payment.findUnique({ where: { id }, include: { invoice: true } }) as any;
  }

  async findByReservation(reservationId: string): Promise<any[]> {
    return this.db.payment.findMany({ where: { reservationId }, include: { invoice: true }, orderBy: { createdAt: 'desc' } });
  }

  async findByTransaction(transactionId: string): Promise<Payment | null> {
    return this.db.payment.findFirst({ where: { transactionId }, include: { invoice: true } }) as any;
  }

  async findAllWithRelations(): Promise<any[]> {
    return this.db.payment.findMany({ include: { invoice: true }, orderBy: { createdAt: 'desc' } });
  }

  async create(data: any): Promise<Payment> {
    return this.db.payment.create({ data, include: { invoice: true } }) as any;
  }

  async update(id: string, data: any): Promise<Payment> {
    return this.db.payment.update({ where: { id }, data, include: { invoice: true } }) as any;
  }

  async delete(id: string): Promise<void> {
    await this.db.payment.delete({ where: { id } });
  }
}

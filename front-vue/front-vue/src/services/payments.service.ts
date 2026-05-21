import api from './api';
import type { ApiResponse, Payment } from '../models/domain';

export interface CreatePaymentPayload {
  reservationId: string;
  amount: number;
  provider: string;
  transactionId: string;
  status?: string;
}

export const paymentsService = {
  async create(payload: CreatePaymentPayload): Promise<Payment> {
    const res = await api.post<ApiResponse<Payment>>('/payments', payload);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al procesar el pago');
    }
    return res.data.data;
  },

  async byReservation(reservationId: string): Promise<Payment[]> {
    const res = await api.get<ApiResponse<Payment[]>>(`/payments/by-reservation/${reservationId}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener pagos de la reserva');
    }
    return res.data.data;
  },

  async getById(id: string): Promise<Payment> {
    const res = await api.get<ApiResponse<Payment>>(`/payments/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener el pago');
    }
    return res.data.data;
  },

  async listAll(): Promise<Payment[]> {
    const res = await api.get<ApiResponse<Payment[]>>('/payments');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al listar pagos');
    }
    return res.data.data;
  },
};

import api from './api';
import type { ApiResponse, Invoice } from '../models/domain';

export const invoicesService = {
  async byPayment(paymentId: string): Promise<Invoice> {
    const res = await api.get<ApiResponse<Invoice>>(`/invoices/by-payment/${paymentId}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener la factura por pago');
    }
    return res.data.data;
  },

  async byBillingProfile(billingProfileId: string): Promise<Invoice[]> {
    const res = await api.get<ApiResponse<Invoice[]>>(
      `/invoices/by-billing-profile/${billingProfileId}`
    );
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener facturas por perfil de facturación');
    }
    return res.data.data;
  },

  async getById(id: string): Promise<Invoice> {
    const res = await api.get<ApiResponse<Invoice>>(`/invoices/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener la factura');
    }
    return res.data.data;
  },
};

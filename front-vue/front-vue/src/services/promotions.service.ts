import api from './api';
import type { ApiResponse, Promotion, PromotionValidation } from '../models/domain';

export const promotionsService = {
  async validate(code: string, amount: number): Promise<PromotionValidation> {
    const res = await api.post<ApiResponse<PromotionValidation>>('/promotions/validate', {
      code,
      amount,
    });
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Código de promoción inválido');
    }
    return res.data.data;
  },

  async getAll(): Promise<Promotion[]> {
    const res = await api.get<ApiResponse<Promotion[]>>('/promotions');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener promociones');
    }
    return res.data.data;
  },

  async create(body: Partial<Promotion>): Promise<Promotion> {
    const res = await api.post<ApiResponse<Promotion>>('/promotions', body);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al crear la promoción');
    }
    return res.data.data;
  },

  async update(id: string, body: Partial<Promotion>): Promise<Promotion> {
    const res = await api.patch<ApiResponse<Promotion>>(`/promotions/${id}`, body);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al actualizar la promoción');
    }
    return res.data.data;
  },

  async remove(id: string): Promise<void> {
    const res = await api.delete<ApiResponse<unknown>>(`/promotions/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al eliminar la promoción');
    }
  },
};

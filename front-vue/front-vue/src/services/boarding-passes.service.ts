import api from './api';
import type { ApiResponse, BoardingPass } from '../models/domain';

export interface CreateBoardingPassPayload {
  passengerId: string;
  segmentId: string;
  boardingCode: string;
  gate?: string | null;
  boardingGroup?: string | null;
  checkInAt?: string | null;
  status?: string;
}

export const boardingPassesService = {
  async byPassenger(passengerId: string): Promise<BoardingPass[]> {
    const res = await api.get<ApiResponse<BoardingPass[]>>(
      `/boarding-passes/by-passenger/${passengerId}`
    );
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener pases de abordar');
    }
    return res.data.data;
  },

  async create(payload: CreateBoardingPassPayload): Promise<BoardingPass> {
    const res = await api.post<ApiResponse<BoardingPass>>('/boarding-passes', payload);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al crear pase de abordar');
    }
    return res.data.data;
  },

  async getById(id: string): Promise<BoardingPass> {
    const res = await api.get<ApiResponse<BoardingPass>>(`/boarding-passes/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener pase de abordar');
    }
    return res.data.data;
  },
};

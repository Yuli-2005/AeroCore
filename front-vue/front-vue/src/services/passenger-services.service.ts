import api from './api';
import type { ApiResponse, PassengerService } from '../models/domain';

export interface CreatePassengerServicePayload {
  passengerId: string;
  serviceConfigId: string;
  quantity: number;
  unitPriceAtBooking: number;
}

export const passengerServicesService = {
  async byPassenger(passengerId: string): Promise<PassengerService[]> {
    const res = await api.get<ApiResponse<PassengerService[]>>(
      `/passenger-services/by-passenger/${passengerId}`
    );
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener servicios del pasajero');
    }
    return res.data.data;
  },

  async create(payload: CreatePassengerServicePayload): Promise<PassengerService> {
    const res = await api.post<ApiResponse<PassengerService>>('/passenger-services', payload);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al agregar servicio');
    }
    return res.data.data;
  },

  async remove(id: string): Promise<void> {
    const res = await api.delete<ApiResponse<unknown>>(`/passenger-services/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al quitar servicio');
    }
  },
};

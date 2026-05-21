import api from './api';
import type { ApiResponse, Reservation } from '../models/domain';

export interface CreateReservationPayload {
  flightClassId: string;
  passengers: { firstName: string; lastName: string; documentNumber: string; seatNumber?: string }[];
  promotionCode?: string;
}

export const reservationsService = {
  async create(payload: CreateReservationPayload): Promise<Reservation> {
    const res = await api.post<ApiResponse<Reservation>>('/reservations', payload);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al crear la reserva');
    }
    return res.data.data;
  },

  async myReservations(): Promise<Reservation[]> {
    const res = await api.get<ApiResponse<Reservation[]>>('/reservations/my');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener tus viajes');
    }
    return res.data.data;
  },

  async getById(id: string): Promise<Reservation> {
    const res = await api.get<ApiResponse<Reservation>>(`/reservations/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener la reserva');
    }
    return res.data.data;
  },

  async cancel(id: string): Promise<Reservation> {
    const res = await api.patch<ApiResponse<Reservation>>(`/reservations/${id}/cancel`, {});
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al cancelar la reserva');
    }
    return res.data.data;
  },

  async setSeat(reservationId: string, passengerId: string, seatNumber: string): Promise<any> {
    const res = await api.patch<ApiResponse<any>>(
      `/reservations/${reservationId}/passengers/${passengerId}/seat`,
      { seatNumber }
    );
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al asignar el asiento');
    }
    return res.data.data;
  },

  async occupiedSeats(flightClassId: string): Promise<string[]> {
    const res = await api.get<ApiResponse<string[]>>(`/reservations/flight-classes/${flightClassId}/occupied-seats`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener asientos ocupados');
    }
    return res.data.data;
  },

  async listAll(): Promise<Reservation[]> {
    const res = await api.get<ApiResponse<Reservation[]>>('/reservations');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al listar reservas');
    }
    return res.data.data;
  },
};

import api from './api';
import type { ApiResponse, Flight, FlightSearchParams } from '../models/domain';

export const flightsService = {
  async search(params: FlightSearchParams): Promise<Flight[]> {
    const httpParams: Record<string, string> = {
      origin: params.origin,
      destination: params.destination,
      date: params.date,
      passengers: String(params.passengers),
    };
    if (params.class) {
      httpParams.class = params.class;
    }

    const res = await api.get<ApiResponse<Flight[]>>('/flights/search', {
      params: httpParams,
    });
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error en la búsqueda de vuelos');
    }
    return res.data.data;
  },

  async getAll(): Promise<Flight[]> {
    const res = await api.get<ApiResponse<Flight[]>>('/flights');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener vuelos');
    }
    return res.data.data;
  },

  async getById(id: string): Promise<Flight> {
    const res = await api.get<ApiResponse<Flight>>(`/flights/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener detalle del vuelo');
    }
    return res.data.data;
  },

  async create(body: Partial<Flight>): Promise<Flight> {
    const res = await api.post<ApiResponse<Flight>>('/flights', body);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al crear vuelo');
    }
    return res.data.data;
  },

  async update(id: string, body: Partial<Flight>): Promise<Flight> {
    const res = await api.put<ApiResponse<Flight>>(`/flights/${id}`, body);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al actualizar vuelo');
    }
    return res.data.data;
  },

  async remove(id: string): Promise<void> {
    const res = await api.delete<ApiResponse<unknown>>(`/flights/${id}`);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al eliminar vuelo');
    }
  },
};

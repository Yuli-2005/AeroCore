import api from './api';
import type { ApiResponse, AirlineServiceConfig } from '../models/domain';

export const airlineServiceConfigsService = {
  async byAirline(
    airlineId: string,
    originAirportId?: string | null,
    destAirportId?: string | null
  ): Promise<AirlineServiceConfig[]> {
    const params: Record<string, string> = {};
    if (originAirportId) params.originAirportId = originAirportId;
    if (destAirportId) params.destAirportId = destAirportId;

    const res = await api.get<ApiResponse<AirlineServiceConfig[]>>(
      `/airline-service-config/by-airline/${airlineId}`,
      { params }
    );
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener configuraciones');
    }
    return res.data.data;
  },

  async list(): Promise<AirlineServiceConfig[]> {
    const res = await api.get<ApiResponse<AirlineServiceConfig[]>>('/airline-service-config');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al listar configuraciones');
    }
    return res.data.data;
  },
};

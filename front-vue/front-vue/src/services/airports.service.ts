import api from './api';
import type { Airport, ApiSuccess } from '../models/domain';

function extractData<T>(res: any): T[] {
  if (Array.isArray(res)) return res;
  if (Array.isArray(res?.data)) return res.data;
  if (Array.isArray(res?.data?.data)) return res.data.data;
  return [];
}

export const airportsService = {
  async getAll(): Promise<Airport[]> {
    const res = await api.get<ApiSuccess<Airport[]> | Airport[]>('/airports');
    return extractData<Airport>(res.data);
  },

  async search(query: string): Promise<Airport[]> {
    const res = await api.get<ApiSuccess<Airport[]> | Airport[]>('/airports/search', {
      params: { q: query },
    });
    return extractData<Airport>(res.data);
  },
};

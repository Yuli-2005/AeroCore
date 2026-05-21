import api from './api';
import type {
  ApiResponse,
  AuthResponse,
  LoginCredentials,
  RegisterData,
  User,
} from '../models/domain';

export const authService = {
  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    const res = await api.post<ApiResponse<AuthResponse>>('/auth/login', credentials);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error de inicio de sesión');
    }
    return res.data.data;
  },

  async register(data: RegisterData): Promise<AuthResponse> {
    const res = await api.post<ApiResponse<AuthResponse>>('/auth/register', data);
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error en registro');
    }
    return res.data.data;
  },

  async me(): Promise<User> {
    const res = await api.get<ApiResponse<User>>('/auth/me');
    if (!res.data.success) {
      throw new Error(res.data.error.message || 'Error al obtener usuario');
    }
    return res.data.data;
  },
};

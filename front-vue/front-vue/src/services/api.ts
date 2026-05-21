import axios from 'axios';
import { useAuthStore } from '../stores/auth';
import router from '../router';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://aerocore-api-issd.onrender.com/api/v1/yulieth-galarza';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor de petición (Correlation ID y Authorization Token)
api.interceptors.request.use(
  (config) => {
    const authStore = useAuthStore();
    const token = authStore.token;

    // Generar Correlation ID para trazabilidad
    const correlationId =
      typeof crypto !== 'undefined' && crypto.randomUUID
        ? crypto.randomUUID()
        : Math.random().toString(36).slice(2);

    config.headers['X-Correlation-Id'] = correlationId;

    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor de respuesta (Control de expiración de sesión 401)
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      const authStore = useAuthStore();
      authStore.clearAuth();
      router.push('/login');
    }
    return Promise.reject(error);
  }
);

export default api;

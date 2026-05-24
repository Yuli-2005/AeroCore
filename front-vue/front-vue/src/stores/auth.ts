import { ref, computed } from 'vue';
import { defineStore } from 'pinia';
import type { AuthUser } from '../models/domain';
import axios from 'axios';

const TOKEN_KEY = 'vuelos_token';
const USER_KEY = 'vuelos_user';

export const useAuthStore = defineStore('auth', () => {
  const user = ref<AuthUser | null>(loadUser());
  const token = ref<string | null>(loadToken());

  const isAuthenticated = computed(() => !!token.value);
  const isAdmin = computed(() => user.value?.role === 'ADMIN');
  const isCustomer = computed(() => user.value?.role === 'CUSTOMER');

  function loadUser(): AuthUser | null {
    try {
      const raw = sessionStorage.getItem(USER_KEY) ?? localStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function loadToken(): string | null {
    return sessionStorage.getItem(TOKEN_KEY) ?? localStorage.getItem(TOKEN_KEY);
  }

  function setAuth(newUser: AuthUser, newToken: string) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    sessionStorage.setItem(TOKEN_KEY, newToken);
    sessionStorage.setItem(USER_KEY, JSON.stringify(newUser));
    user.value = newUser;
    token.value = newToken;
  }

  function clearAuth() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);
    user.value = null;
    token.value = null;
  }

  async function autoLogin(role: 'CUSTOMER' | 'ADMIN') {
    if (token.value && user.value && user.value.role === role) {
      return true;
    }

    const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://aerocore-api-issd.onrender.com/api/v1/yulieth-galarza';
    const email = role === 'ADMIN' ? 'yvgalarza@vuelosapp.com' : 'demo@aerocore.com';
    const password = role === 'ADMIN' ? 'Yuli@2005' : 'Test@12345';

    try {
      const res = await axios.post(`${API_BASE_URL}/auth/login`, { email, password });
      if (res.data.success) {
        setAuth(res.data.data.user, res.data.data.token);
        return true;
      }
    } catch (error) {
      console.error(`Error performing auto-login for ${role}:`, error);
    }
    return false;
  }

  return {
    user,
    token,
    isAuthenticated,
    isAdmin,
    isCustomer,
    setAuth,
    clearAuth,
    autoLogin,
  };
});

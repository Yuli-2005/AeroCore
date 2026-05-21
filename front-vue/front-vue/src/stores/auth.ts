import { ref, computed } from 'vue';
import { defineStore } from 'pinia';
import type { AuthUser } from '../models/domain';

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

  return {
    user,
    token,
    isAuthenticated,
    isAdmin,
    isCustomer,
    setAuth,
    clearAuth,
  };
});

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useAuthStore } from '../stores/auth';

const authStore = useAuthStore();
const year = ref(new Date().getFullYear());
const mobileOpen = ref(false);

const isAuthenticated = computed(() => authStore.isAuthenticated);
const isAdmin = computed(() => authStore.isAdmin);
</script>

<template>
  <div class="min-h-screen bg-gray-50 flex flex-col">
    <!-- Navbar -->
    <header class="glass sticky top-0 z-50 shadow-sm border-b border-white/30">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <!-- Logo -->
          <router-link to="/" class="flex items-center gap-2.5 group">
            <div class="w-9 h-9 rounded-xl gradient-brand flex items-center justify-center shadow-md group-hover:shadow-lg transition-shadow">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </div>
            <span class="font-extrabold text-lg tracking-tight">
              <span class="gradient-brand-text">Aero</span><span class="text-slate-800">Core</span>
            </span>
          </router-link>

          <!-- Desktop Nav links -->
          <nav class="hidden md:flex items-center gap-1 text-sm font-medium text-gray-600">
            <router-link to="/" class="flex items-center gap-1.5 px-4 py-2 rounded-xl hover:bg-blue-50 hover:text-blue-600 transition-all duration-200">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0" />
              </svg>
              Buscar vuelos
            </router-link>
            <router-link v-if="isAuthenticated" to="/my-trips" class="flex items-center gap-1.5 px-4 py-2 rounded-xl hover:bg-blue-50 hover:text-blue-600 transition-all duration-200">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              Mis viajes
            </router-link>
            <router-link v-if="isAdmin" to="/admin" class="flex items-center gap-1.5 px-4 py-2 rounded-xl hover:bg-purple-50 text-purple-500 hover:text-purple-700 transition-all duration-200">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
              Admin
            </router-link>
          </nav>

          <!-- Mobile toggle -->
          <div class="flex items-center gap-3">
            <!-- Mobile menu button -->
            <button @click="mobileOpen = !mobileOpen" class="md:hidden flex items-center justify-center w-10 h-10 rounded-xl hover:bg-gray-100 transition-colors">
              <svg v-if="!mobileOpen" class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
              <svg v-else class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <!-- Mobile menu -->
        <div v-if="mobileOpen" class="md:hidden pb-4 border-t border-gray-100 mt-2 pt-3 space-y-1 animate-fade-up">
          <router-link @click="mobileOpen = false" to="/" class="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-blue-50 hover:text-blue-600 transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0" /></svg>
            Buscar vuelos
          </router-link>
          <router-link v-if="isAuthenticated" @click="mobileOpen = false" to="/my-trips" class="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-blue-50 hover:text-blue-600 transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
            Mis viajes
          </router-link>
          <router-link v-if="isAdmin" @click="mobileOpen = false" to="/admin" class="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-purple-500 hover:bg-purple-50 hover:text-purple-700 transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
            Admin
          </router-link>
        </div>
      </div>
    </header>

    <!-- Contenido -->
    <main class="flex-1">
      <router-view />
    </main>

    <!-- Footer Premium -->
    <footer class="bg-slate-900 text-white pt-12 pb-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-8 mb-10">
          <!-- Brand -->
          <div>
            <div class="flex items-center gap-2.5 mb-4">
              <div class="w-9 h-9 rounded-xl gradient-brand flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </div>
              <span class="font-extrabold text-lg">AeroCore</span>
            </div>
            <p class="text-sm text-slate-400 leading-relaxed">Tu plataforma de reserva de vuelos.<br/>Rápido, seguro y moderno.</p>
          </div>
          <!-- Links -->
          <div>
            <h4 class="font-semibold text-sm uppercase tracking-wider text-slate-300 mb-4">Navegación</h4>
            <ul class="space-y-2.5 text-sm text-slate-400">
              <li><router-link to="/" class="hover:text-white transition-colors">Buscar vuelos</router-link></li>
              <li><router-link to="/my-trips" class="hover:text-white transition-colors">Mis viajes</router-link></li>
            </ul>
          </div>
          <!-- Info -->
          <div>
            <h4 class="font-semibold text-sm uppercase tracking-wider text-slate-300 mb-4">Plataforma</h4>
            <ul class="space-y-2.5 text-sm text-slate-400">
              <li>Reserva segura</li>
              <li>Confirmación inmediata</li>
              <li>Soporte 24/7</li>
            </ul>
          </div>
        </div>
        <div class="border-t border-slate-800 pt-6 flex flex-col sm:flex-row items-center justify-between gap-3">
          <p class="text-xs text-slate-500">AeroCore © {{ year }} · Plataforma académica</p>
          <div class="flex gap-4">
            <span class="text-xs text-slate-600">Hecho con ❤️</span>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { adminService } from '../../services/admin.service';
import { useAuthStore } from '../../stores/auth';

const authStore = useAuthStore();

const totalFlights = ref(0);
const activeReservations = ref(0);
const simulatedRevenue = ref(0);
const registeredUsers = ref(0);
const isLoading = ref(true);

const CARDS = [
  { label: 'Países', path: '/admin/countries', color: 'bg-blue-50 hover:bg-blue-100/80 border-blue-200 text-blue-600' },
  { label: 'Ciudades', path: '/admin/cities', color: 'bg-indigo-50 hover:bg-indigo-100/80 border-indigo-200 text-indigo-600' },
  { label: 'Aeropuertos', path: '/admin/airports', color: 'bg-orange-50 hover:bg-orange-100/80 border-orange-200 text-orange-600' },
  { label: 'Aerolíneas', path: '/admin/airlines', color: 'bg-teal-50 hover:bg-teal-100/80 border-teal-200 text-teal-600' },
  { label: 'Aviones', path: '/admin/aircraft', color: 'bg-emerald-50 hover:bg-emerald-100/80 border-emerald-200 text-emerald-600' },
  { label: 'Vuelos', path: '/admin/flights', color: 'bg-sky-50 hover:bg-sky-100/80 border-sky-200 text-sky-600' },
];

onMounted(async () => {
  try {
    const [flights, reservations, users, payments] = await Promise.all([
      adminService.getFlights(),
      adminService.getReservations(),
      adminService.getUsers(),
      adminService.getPayments(),
    ]);

    totalFlights.value = flights.length;
    activeReservations.value = reservations.filter((r: any) => r.status !== 'CANCELLED').length;
    registeredUsers.value = users.length;
    simulatedRevenue.value = payments
      .filter((p: any) => p.status === 'CONFIRMED' || p.status === 'approved' || p.status === 'COMPLETED' || !p.status)
      .reduce((acc: number, p: any) => acc + Number(p.amount || 0), 0);
  } catch {
    // Manejo silencioso en stubs
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="space-y-8">
    <!-- Welcome Header -->
    <div>
      <h1 class="text-3xl font-black text-gray-900 tracking-tight">Dashboard</h1>
      <p class="text-sm text-gray-500 font-medium mt-1">
        Bienvenido de nuevo, <span class="text-blue-600 font-bold">{{ authStore.user?.firstName }}</span>. Panel de control administrativo.
      </p>
    </div>

    <!-- Loading Metrics Spinner -->
    <div v-if="isLoading" class="flex items-center justify-center py-10 bg-white border border-gray-100 rounded-2xl shadow-sm">
      <svg class="w-6 h-6 animate-spin text-blue-600" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
      <span class="text-sm text-gray-500 font-semibold ml-2">Cargando métricas...</span>
    </div>

    <!-- Statistical Grid -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
      <!-- Metric 1: Vuelos -->
      <div class="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden flex flex-col justify-between">
        <div>
          <span class="text-xs font-bold text-gray-400 uppercase tracking-wider block">Total Vuelos</span>
          <p class="text-4xl font-black text-gray-900 mt-2 tracking-tight">{{ totalFlights }}</p>
        </div>
        <div class="absolute right-4 bottom-4 w-12 h-12 bg-blue-50 text-blue-600 rounded-xl flex items-center justify-center shadow-inner">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </div>
      </div>

      <!-- Metric 2: Reservas -->
      <div class="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden flex flex-col justify-between">
        <div>
          <span class="text-xs font-bold text-gray-400 uppercase tracking-wider block">Reservas Activas</span>
          <p class="text-4xl font-black text-gray-900 mt-2 tracking-tight">{{ activeReservations }}</p>
        </div>
        <div class="absolute right-4 bottom-4 w-12 h-12 bg-green-50 text-green-600 rounded-xl flex items-center justify-center shadow-inner">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
        </div>
      </div>

      <!-- Metric 3: Ingresos -->
      <div class="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden flex flex-col justify-between">
        <div>
          <span class="text-xs font-bold text-gray-400 uppercase tracking-wider block">Ingresos Estimados</span>
          <p class="text-3xl font-black text-gray-900 mt-2 tracking-tight">
            ${{ simulatedRevenue.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
          </p>
        </div>
        <div class="absolute right-4 bottom-4 w-12 h-12 bg-yellow-50 text-yellow-600 rounded-xl flex items-center justify-center shadow-inner">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
      </div>

      <!-- Metric 4: Usuarios -->
      <div class="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden flex flex-col justify-between">
        <div>
          <span class="text-xs font-bold text-gray-400 uppercase tracking-wider block">Usuarios Registrados</span>
          <p class="text-4xl font-black text-gray-900 mt-2 tracking-tight">{{ registeredUsers }}</p>
        </div>
        <div class="absolute right-4 bottom-4 w-12 h-12 bg-purple-50 text-purple-600 rounded-xl flex items-center justify-center shadow-inner">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
        </div>
      </div>
    </div>

    <!-- Management Modules Matrix -->
    <div>
      <h2 class="text-lg font-bold text-gray-900 mb-4 tracking-tight">Módulos Administrativos</h2>
      <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
        <router-link
          v-for="c in CARDS"
          :key="c.path"
          :to="c.path"
          class="border rounded-2xl p-5 hover:shadow-md hover:scale-[1.02] active:scale-95 transition-all cursor-pointer font-bold block"
          :class="c.color"
        >
          <p class="text-lg">{{ c.label }}</p>
          <p class="text-xs opacity-70 mt-1 select-none">Gestionar &rarr;</p>
        </router-link>
      </div>
    </div>
  </div>
</template>

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
  <div class="space-y-10">
    <!-- Welcome Header -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white border border-slate-100 rounded-3xl p-6 md:p-8 shadow-sm">
      <div>
        <h1 class="text-3xl font-black text-slate-900 tracking-tight flex items-center gap-2.5">
          <span>Dashboard</span>
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
        </h1>
        <p class="text-sm text-slate-500 font-medium mt-1.5">
          Bienvenido de nuevo, <span class="text-[#5c5bf5] font-bold">{{ authStore.user?.firstName }}</span>. Aquí tienes el resumen del sistema.
        </p>
      </div>
      <div class="flex items-center gap-2.5 text-xs font-bold text-slate-500 bg-slate-50 border border-slate-100/80 rounded-2xl px-4 py-2.5 self-start md:self-auto">
        <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
        </svg>
        <span>Fecha de sesión: {{ new Date().toLocaleDateString('es-ES', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }) }}</span>
      </div>
    </div>

    <!-- Loading Metrics Spinner -->
    <div v-if="isLoading" class="flex flex-col items-center justify-center py-20 bg-white border border-slate-100 rounded-3xl shadow-sm">
      <svg class="w-8 h-8 animate-spin text-blue-600" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
      <span class="text-xs text-slate-400 font-bold mt-4 tracking-wider uppercase">Cargando métricas del sistema...</span>
    </div>

    <!-- Statistical Grid -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
      <!-- Metric 1: Vuelos -->
      <div class="bg-white border border-slate-150/80 rounded-3xl p-6 shadow-sm hover:shadow-md hover:-translate-y-1 transition-all duration-300 relative overflow-hidden flex flex-col justify-between group/metric">
        <div class="absolute top-0 right-0 w-24 h-24 bg-blue-500/5 rounded-bl-full transition-all duration-300 group-hover/metric:scale-110"></div>
        <div>
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block">Total Vuelos</span>
          <p class="text-4xl font-black text-slate-800 mt-2.5 tracking-tight">{{ totalFlights }}</p>
        </div>
        <div class="flex items-center justify-between mt-6">
          <span class="text-[11px] font-semibold text-slate-400">Actualizado recientemente</span>
          <div class="w-10 h-10 bg-blue-50 text-blue-600 rounded-xl flex items-center justify-center shadow-inner group-hover/metric:scale-110 transition-transform duration-300">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </div>
        </div>
      </div>

      <!-- Metric 2: Reservas -->
      <div class="bg-white border border-slate-150/80 rounded-3xl p-6 shadow-sm hover:shadow-md hover:-translate-y-1 transition-all duration-300 relative overflow-hidden flex flex-col justify-between group/metric">
        <div class="absolute top-0 right-0 w-24 h-24 bg-emerald-500/5 rounded-bl-full transition-all duration-300 group-hover/metric:scale-110"></div>
        <div>
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block">Reservas Activas</span>
          <p class="text-4xl font-black text-slate-800 mt-2.5 tracking-tight">{{ activeReservations }}</p>
        </div>
        <div class="flex items-center justify-between mt-6">
          <span class="text-[11px] font-semibold text-slate-400">Estado confirmadas</span>
          <div class="w-10 h-10 bg-emerald-50 text-emerald-600 rounded-xl flex items-center justify-center shadow-inner group-hover/metric:scale-110 transition-transform duration-300">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
        </div>
      </div>

      <!-- Metric 3: Ingresos -->
      <div class="bg-white border border-slate-150/80 rounded-3xl p-6 shadow-sm hover:shadow-md hover:-translate-y-1 transition-all duration-300 relative overflow-hidden flex flex-col justify-between group/metric">
        <div class="absolute top-0 right-0 w-24 h-24 bg-amber-500/5 rounded-bl-full transition-all duration-300 group-hover/metric:scale-110"></div>
        <div>
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block">Ingresos Estimados</span>
          <p class="text-3xl font-black text-slate-800 mt-2.5 tracking-tight">
            ${{ simulatedRevenue.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
          </p>
        </div>
        <div class="flex items-center justify-between mt-6">
          <span class="text-[11px] font-semibold text-slate-400">Moneda base: USD</span>
          <div class="w-10 h-10 bg-amber-50 text-amber-600 rounded-xl flex items-center justify-center shadow-inner group-hover/metric:scale-110 transition-transform duration-300">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        </div>
      </div>

      <!-- Metric 4: Usuarios -->
      <div class="bg-white border border-slate-150/80 rounded-3xl p-6 shadow-sm hover:shadow-md hover:-translate-y-1 transition-all duration-300 relative overflow-hidden flex flex-col justify-between group/metric">
        <div class="absolute top-0 right-0 w-24 h-24 bg-violet-500/5 rounded-bl-full transition-all duration-300 group-hover/metric:scale-110"></div>
        <div>
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block">Usuarios Registrados</span>
          <p class="text-4xl font-black text-slate-800 mt-2.5 tracking-tight">{{ registeredUsers }}</p>
        </div>
        <div class="flex items-center justify-between mt-6">
          <span class="text-[11px] font-semibold text-slate-400">Clientes & admins</span>
          <div class="w-10 h-10 bg-violet-50 text-violet-600 rounded-xl flex items-center justify-center shadow-inner group-hover/metric:scale-110 transition-transform duration-300">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          </div>
        </div>
      </div>
    </div>

    <!-- Management Modules Matrix -->
    <div class="space-y-4">
      <h2 class="text-lg font-bold text-slate-800 tracking-tight">Accesos Rápidos a Catálogos</h2>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
        <router-link
          v-for="c in CARDS"
          :key="c.path"
          :to="c.path"
          class="border rounded-2xl p-5 hover:shadow-md hover:-translate-y-0.5 active:scale-98 transition-all cursor-pointer font-bold block bg-white group/card border-slate-100"
        >
          <div class="flex items-center gap-2">
            <span class="w-2 h-2 rounded-full" :class="
              c.label === 'Países' ? 'bg-blue-500' :
              c.label === 'Ciudades' ? 'bg-indigo-500' :
              c.label === 'Aeropuertos' ? 'bg-orange-500' :
              c.label === 'Aerolíneas' ? 'bg-teal-500' :
              c.label === 'Aviones' ? 'bg-emerald-500' : 'bg-sky-500'
            "></span>
            <p class="text-sm font-semibold text-slate-800 leading-none group-hover/card:text-[#5c5bf5] transition-colors">{{ c.label }}</p>
          </div>
          <div class="flex items-center justify-between mt-5">
            <p class="text-[10px] text-slate-400 font-bold uppercase tracking-wider select-none">Gestionar</p>
            <svg class="w-3.5 h-3.5 text-slate-400 group-hover/card:text-[#5c5bf5] group-hover/card:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>

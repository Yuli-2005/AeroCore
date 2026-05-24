<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { reservationsService } from '../../services/reservations.service';
import type { Reservation } from '../../models/domain';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

const router = useRouter();
const loading = ref(true);
const error = ref<string | null>(null);
const reservations = ref<Reservation[]>([]);

onMounted(async () => {
  try {
    reservations.value = await reservationsService.myReservations();
  } catch (err: any) {
    error.value = err?.message || 'Error al cargar tus viajes';
  } finally {
    loading.value = false;
  }
});

function statusBadge(s: string) {
  if (s === 'CONFIRMED') return 'bg-emerald-50 text-emerald-700 border-emerald-200';
  if (s === 'CANCELLED') return 'bg-red-50 text-red-700 border-red-200';
  return 'bg-amber-50 text-amber-700 border-amber-200';
}

function statusText(s: string) {
  if (s === 'CONFIRMED') return '● Confirmada';
  if (s === 'CANCELLED') return '✕ Cancelada';
  return '◐ Pendiente';
}

function firstSeg(r: Reservation) {
  return r.flight?.segments?.[0] ?? null;
}

function lastSeg(r: Reservation) {
  const segs = r.flight?.segments ?? [];
  return segs.length ? segs[segs.length - 1] : null;
}

function fmtDate(dt?: string | null) {
  if (!dt) return '---';
  try { return format(new Date(dt), "d MMM yyyy · HH:mm", { locale: es }); } catch { return dt; }
}
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/30 min-h-screen">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-10">
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center gap-3 mb-1">
          <button
            @click="router.push('/')"
            class="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 class="text-2xl font-extrabold tracking-tight">Mis viajes</h1>
        </div>
        <p class="text-slate-300 text-sm ml-11">Historial y detalle de tus reservas</p>
        <div v-if="!loading && !error" class="mt-3 ml-11">
          <span class="text-xs bg-white/10 border border-white/20 px-3 py-1 rounded-full">
            {{ reservations.length }} {{ reservations.length === 1 ? 'reserva' : 'reservas' }}
          </span>
        </div>
      </div>
    </div>

    <div class="max-w-4xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="loading" class="flex flex-col items-center py-24 gap-4">
        <div class="relative w-14 h-14">
          <div class="absolute inset-0 rounded-full border-4 border-blue-100"></div>
          <div class="absolute inset-0 rounded-full border-4 border-blue-500 border-t-transparent animate-spin"></div>
          <div class="absolute inset-0 flex items-center justify-center">
            <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
        </div>
        <p class="text-sm text-gray-400 font-medium">Cargando tus viajes...</p>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl p-5">
        <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm text-red-700">{{ error }}</p>
      </div>

      <!-- Empty -->
      <div v-else-if="!reservations.length" class="text-center py-24">
        <div class="inline-flex items-center justify-center w-20 h-20 bg-gray-100 rounded-3xl mb-5">
          <svg class="w-10 h-10 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
        </div>
        <h2 class="text-xl font-bold text-gray-700 mb-2">Sin viajes registrados</h2>
        <p class="text-sm text-gray-400 mb-6">Aún no tienes reservas. ¡Busca tu próximo vuelo!</p>
        <button
          @click="router.push('/')"
          class="gradient-brand text-white text-sm font-bold px-6 py-2.5 rounded-xl hover:shadow-lg hover:shadow-blue-500/20 transition-all"
        >
          Buscar vuelos
        </button>
      </div>

      <!-- Reservation cards -->
      <div v-else class="space-y-4">
        <div
          v-for="r in reservations"
          :key="r.id"
          class="bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md hover:shadow-blue-500/5 transition-all duration-200 overflow-hidden cursor-pointer group"
          @click="router.push({ name: 'reservation-detail', params: { id: r.id } })"
        >
          <!-- Top bar -->
          <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-gray-50">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 gradient-brand rounded-xl flex items-center justify-center shadow-md shadow-blue-500/20">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </div>
              <div>
                <p class="font-mono font-black text-blue-600 text-base tracking-widest leading-none">{{ r.reservationCode }}</p>
                <p class="text-xs text-gray-400 mt-0.5">{{ fmtDate(firstSeg(r)?.departureDateTime) }}</p>
              </div>
            </div>
            <span class="text-xs px-3 py-1 rounded-full font-semibold border" :class="statusBadge(r.status)">
              {{ statusText(r.status) }}
            </span>
          </div>

          <!-- Route -->
          <div class="px-6 py-5">
            <div class="flex items-center gap-4">
              <div class="text-center min-w-[64px]">
                <p class="text-3xl font-black text-gray-900 tracking-tight leading-none">
                  {{ firstSeg(r)?.originAirport?.iataCode ?? '---' }}
                </p>
                <p class="text-xs text-gray-400 mt-1 max-w-[64px] truncate">
                  {{ firstSeg(r)?.originAirport?.city?.name ?? '' }}
                </p>
              </div>

              <div class="flex-1 flex flex-col items-center gap-1.5">
                <div class="w-full flex items-center gap-1">
                  <div class="flex-1 h-0.5 bg-gradient-to-r from-blue-200 to-indigo-200 rounded-full"></div>
                  <svg class="w-3.5 h-3.5 text-blue-400" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                  </svg>
                </div>
                <p class="text-[10px] text-gray-400 font-medium">{{ firstSeg(r)?.airline?.name ?? 'Vuelo directo' }}</p>
              </div>

              <div class="text-center min-w-[64px]">
                <p class="text-3xl font-black text-gray-900 tracking-tight leading-none">
                  {{ lastSeg(r)?.destinationAirport?.iataCode ?? '---' }}
                </p>
                <p class="text-xs text-gray-400 mt-1 max-w-[64px] truncate">
                  {{ lastSeg(r)?.destinationAirport?.city?.name ?? '' }}
                </p>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div class="px-6 pb-4 flex items-center justify-between">
            <span class="text-xs text-gray-400">
              {{ r.passengers?.length ?? 0 }} pasajero{{ (r.passengers?.length ?? 0) !== 1 ? 's' : '' }}
              <span v-if="r.passengers?.some(p => p.seatNumber)" class="ml-1 text-emerald-500 font-semibold">· Asientos asignados</span>
              <span v-else-if="r.status === 'CONFIRMED'" class="ml-1 text-amber-500 font-semibold">· Pendiente selección de asiento</span>
            </span>
            <div class="flex items-center gap-3">
              <span class="text-xl font-black text-indigo-600">
                ${{ Number(r.totalAmount).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
              </span>
              <span class="text-xs text-blue-600 font-semibold group-hover:underline">Ver detalle →</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

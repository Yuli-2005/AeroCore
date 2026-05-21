<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { flightsService } from '../../services/flights.service';
import type { Flight } from '../../models/domain';
import { format } from 'date-fns';

const route = useRoute();
const router = useRouter();

const loading = ref(true);
const flight = ref<Flight | null>(null);

onMounted(async () => {
  const id = route.params.id as string;
  try {
    const data = await flightsService.getById(id);
    flight.value = data;
  } catch {
    // Manejo silencioso de errores
  } finally {
    loading.value = false;
  }
});

function depTime(f: Flight) {
  return f.departureDateTime ? format(new Date(f.departureDateTime), 'HH:mm') : '--:--';
}

function arrTime(f: Flight) {
  return f.arrivalDateTime ? format(new Date(f.arrivalDateTime), 'HH:mm') : '--:--';
}

function classLabel(t: string) {
  if (t === 'ECONOMY') return 'Económica';
  if (t === 'BUSINESS') return 'Business';
  if (t === 'FIRST') return 'Primera clase';
  return t;
}

function classIcon(t: string) {
  if (t === 'FIRST') return '👑';
  if (t === 'BUSINESS') return '💼';
  return '🛩️';
}

function classBadge(t: string) {
  if (t === 'FIRST') return 'bg-purple-100 text-purple-700 border border-purple-200';
  if (t === 'BUSINESS') return 'bg-amber-100 text-amber-700 border border-amber-200';
  return 'bg-sky-50 text-sky-700 border border-sky-200';
}
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/40 min-h-screen">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-8">
      <div class="max-w-3xl mx-auto">
        <button
          @click="router.back()"
          class="flex items-center gap-2 text-slate-300 hover:text-white text-sm font-medium transition-colors mb-4"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Volver a resultados
        </button>
        <h1 class="text-2xl font-extrabold tracking-tight">
          Detalle del vuelo
        </h1>
      </div>
    </div>

    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="loading" class="flex flex-col items-center justify-center py-24 gap-4">
        <div class="relative w-16 h-16">
          <div class="absolute inset-0 rounded-full border-4 border-blue-100"></div>
          <div class="absolute inset-0 rounded-full border-4 border-blue-500 border-t-transparent animate-spin"></div>
        </div>
        <p class="text-sm text-gray-500">Cargando detalles del vuelo...</p>
      </div>

      <div v-else-if="flight" class="space-y-5 animate-fade-up">
        <!-- Route title -->
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 gradient-brand rounded-xl flex items-center justify-center shadow-lg">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </div>
          <div>
            <h2 class="text-xl font-black text-gray-900 tracking-tight">
              {{ flight.route?.originAirport?.iataCode ?? flight.originAirportIata }}
              <span class="text-blue-500 mx-1">→</span>
              {{ flight.route?.destinationAirport?.iataCode ?? flight.destinationAirportIata }}
            </h2>
            <p class="text-sm text-gray-500">{{ flight.airline?.name ?? 'Aerolínea' }} &middot; {{ flight.flightNumber ?? '' }}</p>
          </div>
        </div>

        <!-- Schedule card -->
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-5">Horario</p>
          <div class="flex items-center gap-4">
            <div class="text-center min-w-[80px]">
              <p class="text-4xl font-black text-gray-900 tracking-tight leading-none">{{ depTime(flight) }}</p>
              <p class="text-sm font-bold text-blue-600 mt-2">{{ flight.route?.originAirport?.iataCode ?? flight.originAirportIata }}</p>
              <p class="text-xs text-gray-400 mt-0.5">{{ flight.route?.originAirport?.city ?? '' }}</p>
            </div>

            <div class="flex-1 flex flex-col items-center gap-2">
              <div class="w-full flex items-center gap-2">
                <div class="flex-1 h-0.5 bg-gradient-to-r from-blue-200 to-indigo-200 rounded-full"></div>
                <div class="w-8 h-8 gradient-brand rounded-full flex items-center justify-center">
                  <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                  </svg>
                </div>
                <div class="flex-1 h-0.5 bg-gradient-to-r from-indigo-200 to-blue-200 rounded-full"></div>
              </div>
              <p class="text-xs text-gray-400">Vuelo directo</p>
            </div>

            <div class="text-center min-w-[80px]">
              <p class="text-4xl font-black text-gray-900 tracking-tight leading-none">{{ arrTime(flight) }}</p>
              <p class="text-sm font-bold text-blue-600 mt-2">{{ flight.route?.destinationAirport?.iataCode ?? flight.destinationAirportIata }}</p>
              <p class="text-xs text-gray-400 mt-0.5">{{ flight.route?.destinationAirport?.city ?? '' }}</p>
            </div>
          </div>
        </div>

        <!-- Classes -->
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-4">Clases disponibles</p>
          <div class="space-y-3">
            <div
              v-for="fc in flight.flightClasses ?? []"
              :key="fc.id"
              class="flex items-center justify-between p-4 rounded-xl bg-gray-50/80 hover:bg-blue-50/50 transition-colors"
            >
              <div class="flex items-center gap-3">
                <span class="text-xl">{{ classIcon(fc.classType) }}</span>
                <div>
                  <span class="text-xs font-bold px-2.5 py-1 rounded-lg" :class="classBadge(fc.classType)">
                    {{ classLabel(fc.classType) }}
                  </span>
                  <p class="text-xs text-gray-400 mt-1">{{ fc.availableSeats }} asientos disponibles</p>
                </div>
              </div>
              <div class="flex items-center gap-4">
                <p class="text-2xl font-black text-blue-600">${{ fc.basePrice.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</p>
                <button
                  @click="router.push({ name: 'reservation-new', params: { flightClassId: fc.id } })"
                  :disabled="fc.availableSeats === 0"
                  class="gradient-brand text-white text-xs font-bold px-5 py-2.5 rounded-xl transition-all duration-200 hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.05] active:scale-95 disabled:opacity-40 disabled:hover:scale-100 whitespace-nowrap"
                >
                  Reservar
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Not found -->
      <div v-else class="text-center py-24">
        <div class="inline-flex items-center justify-center w-20 h-20 bg-gray-100 rounded-3xl mb-5">
          <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </div>
        <h2 class="text-xl font-bold text-gray-700 mb-2">Vuelo no encontrado</h2>
        <button @click="router.push('/')" class="gradient-brand text-white text-sm font-semibold px-6 py-2.5 rounded-xl mt-4 hover:shadow-lg transition-all">
          Volver al inicio
        </button>
      </div>
    </div>
  </div>
</template>

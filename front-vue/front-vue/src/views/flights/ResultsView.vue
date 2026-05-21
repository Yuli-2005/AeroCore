<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { flightsService } from '../../services/flights.service';
import type { Flight, FlightSearchParams } from '../../models/domain';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

function formatDuration(mins: number) {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${h}h ${m > 0 ? `${m}m` : ''}`;
}

const route = useRoute();
const router = useRouter();

const loading = ref(false);
const error = ref<string | null>(null);
const flights = ref<Flight[]>([]);
const sortBy = ref('departure');

const params = ref<FlightSearchParams>({
  origin: (route.query.origin as string) || '',
  destination: (route.query.destination as string) || '',
  date: (route.query.date as string) || '',
  passengers: Number(route.query.passengers || 1),
  class: (route.query.class as any) || undefined,
});

const formattedDate = computed(() => {
  const d = params.value.date;
  if (!d) return '';
  try {
    return format(new Date(d + 'T12:00:00'), "d 'de' MMMM, yyyy", { locale: es });
  } catch {
    return d;
  }
});

const sorted = computed(() => {
  const list = [...flights.value];
  if (sortBy.value === 'price') {
    return list.sort((a, b) => {
      const aMin = Math.min(...(a.flightClasses ?? []).map(fc => fc.basePrice));
      const bMin = Math.min(...(b.flightClasses ?? []).map(fc => fc.basePrice));
      return aMin - bMin;
    });
  }
  if (sortBy.value === 'duration') {
    return list.sort((a, b) => {
      const aDur = a.route?.estimatedDuration ?? a.duration ?? 0;
      const bDur = b.route?.estimatedDuration ?? b.duration ?? 0;
      return aDur - bDur;
    });
  }
  return list.sort((a, b) => {
    const aTime = new Date(a.departureDateTime ?? a.departureDate).getTime();
    const bTime = new Date(b.departureDateTime ?? b.departureDate).getTime();
    return aTime - bTime;
  });
});

onMounted(() => { load(); });

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const list = await flightsService.search(params.value);
    flights.value = list;
  } catch (err: any) {
    error.value = err?.message || 'Error al buscar vuelos.';
  } finally {
    loading.value = false;
  }
}

function reserve(flightClassId: string) {
  router.push({ name: 'reservation-new', params: { flightClassId } });
}

function depTime(f: Flight) {
  const d = f.departureDateTime ? new Date(f.departureDateTime) : null;
  return d ? format(d, 'HH:mm') : '--:--';
}

function arrTime(f: Flight) {
  const d = f.arrivalDateTime ? new Date(f.arrivalDateTime) : null;
  return d ? format(d, 'HH:mm') : '--:--';
}

function durationStr(f: Flight) {
  const m = f.route?.estimatedDuration ?? f.duration;
  return m ? formatDuration(m) : '';
}

function classColor(t: string) {
  if (t === 'FIRST') return 'bg-purple-100 text-purple-700 border border-purple-200';
  if (t === 'BUSINESS') return 'bg-amber-100 text-amber-700 border border-amber-200';
  return 'bg-sky-50 text-sky-700 border border-sky-200';
}

function classLabel(t: string) {
  if (t === 'ECONOMY') return 'Económica';
  if (t === 'BUSINESS') return 'Business';
  if (t === 'FIRST') return 'Primera';
  return t;
}

function classIcon(t: string) {
  if (t === 'FIRST') return '👑';
  if (t === 'BUSINESS') return '💼';
  return '🛩️';
}
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/40 min-h-screen">
    <!-- Hero header bar -->
    <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-8">
      <div class="max-w-5xl mx-auto">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <!-- Route title -->
          <div>
            <div class="flex items-center gap-3 mb-1">
              <button @click="router.back()" class="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <h1 class="text-2xl font-extrabold tracking-tight">
                {{ params.origin }}
                <span class="text-blue-400 mx-2">→</span>
                {{ params.destination }}
              </h1>
            </div>
            <p class="text-slate-300 text-sm ml-11">
              {{ formattedDate }} &middot;
              {{ params.passengers }} {{ params.passengers === 1 ? 'pasajero' : 'pasajeros' }}
              <span v-if="params.class" class="ml-1">&middot; {{ params.class }}</span>
            </p>
          </div>

          <!-- Sort selector -->
          <div class="flex items-center gap-2 ml-11 sm:ml-0">
            <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
            </svg>
            <select
              v-model="sortBy"
              class="text-sm border border-white/20 bg-white/10 text-white rounded-xl px-3 py-2 focus:ring-2 focus:ring-blue-400 outline-none cursor-pointer backdrop-blur-sm"
            >
              <option value="departure" class="text-gray-900">Hora de salida</option>
              <option value="price" class="text-gray-900">Precio</option>
              <option value="duration" class="text-gray-900">Duración</option>
            </select>
          </div>
        </div>

        <!-- Results count badge -->
        <div v-if="!loading && !error" class="mt-4 ml-11">
          <span class="text-xs bg-white/10 border border-white/20 px-3 py-1 rounded-full">
            {{ sorted.length }} {{ sorted.length === 1 ? 'vuelo encontrado' : 'vuelos encontrados' }}
          </span>
        </div>
      </div>
    </div>

    <!-- Content area -->
    <div class="max-w-5xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="loading" class="flex flex-col items-center justify-center py-24 gap-4">
        <div class="relative w-16 h-16">
          <div class="absolute inset-0 rounded-full border-4 border-blue-100"></div>
          <div class="absolute inset-0 rounded-full border-4 border-blue-500 border-t-transparent animate-spin"></div>
          <div class="absolute inset-0 flex items-center justify-center">
            <svg class="w-6 h-6 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </div>
        </div>
        <p class="text-sm text-gray-500 font-medium">Buscando los mejores vuelos...</p>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl p-5">
        <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm text-red-700">{{ error }}</p>
      </div>

      <!-- Empty -->
      <div v-else-if="sorted.length === 0" class="text-center py-24">
        <div class="inline-flex items-center justify-center w-20 h-20 bg-gray-100 rounded-3xl mb-5">
          <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </div>
        <h2 class="text-xl font-bold text-gray-700 mb-2">Sin vuelos disponibles</h2>
        <p class="text-sm text-gray-400 mb-6">No encontramos vuelos para esta ruta y fecha.</p>
        <button @click="router.push('/')" class="gradient-brand text-white text-sm font-semibold px-6 py-2.5 rounded-xl hover:shadow-lg hover:shadow-blue-500/20 transition-all duration-200">
          Nueva búsqueda
        </button>
      </div>

      <!-- Flight Cards -->
      <div v-else class="space-y-4">
        <div
          v-for="(flight, idx) in sorted"
          :key="flight.id"
          class="bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-lg hover:shadow-blue-500/5 transition-all duration-300 overflow-hidden group"
          :style="{ animationDelay: idx * 0.06 + 's' }"
        >
          <!-- Card top: airline + status -->
          <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-gray-50">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 gradient-brand rounded-xl flex items-center justify-center shadow-md shadow-blue-500/20 group-hover:scale-110 transition-transform duration-300">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-bold text-gray-900">{{ flight.airline?.name ?? 'Aerolínea' }}</p>
                <p class="text-xs text-gray-400">{{ flight.flightNumber ?? flight.originAirportIata }}</p>
              </div>
            </div>
            <span
              class="text-xs px-3 py-1 rounded-full font-semibold border"
              :class="flight.status === 'SCHEDULED' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-amber-50 text-amber-700 border-amber-200'"
            >
              {{ flight.status === 'SCHEDULED' ? '● A tiempo' : flight.status }}
            </span>
          </div>

          <!-- Schedule -->
          <div class="px-6 py-5">
            <div class="flex items-center gap-4">
              <div class="text-center min-w-[72px]">
                <p class="text-3xl font-black text-gray-900 tracking-tight leading-none">{{ depTime(flight) }}</p>
                <p class="text-xs font-bold text-blue-600 mt-1">{{ flight.route?.originAirport?.iataCode ?? flight.originAirportIata }}</p>
                <p class="text-xs text-gray-400 mt-0.5 max-w-[72px] truncate">{{ flight.route?.originAirport?.city ?? '' }}</p>
              </div>

              <div class="flex-1 flex flex-col items-center gap-1.5">
                <p class="text-xs text-gray-400 font-medium flex items-center gap-1">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  {{ durationStr(flight) }}
                </p>
                <div class="w-full flex items-center gap-1">
                  <div class="flex-1 h-0.5 bg-gradient-to-r from-blue-200 to-indigo-200 rounded-full"></div>
                  <svg class="w-3.5 h-3.5 text-blue-400" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                  </svg>
                </div>
                <p class="text-xs text-gray-400">Directo</p>
              </div>

              <div class="text-center min-w-[72px]">
                <p class="text-3xl font-black text-gray-900 tracking-tight leading-none">{{ arrTime(flight) }}</p>
                <p class="text-xs font-bold text-blue-600 mt-1">{{ flight.route?.destinationAirport?.iataCode ?? flight.destinationAirportIata }}</p>
                <p class="text-xs text-gray-400 mt-0.5 max-w-[72px] truncate">{{ flight.route?.destinationAirport?.city ?? '' }}</p>
              </div>
            </div>
          </div>

          <!-- Classes / Prices -->
          <div class="border-t border-gray-50 px-6 pb-5 pt-4 space-y-3">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Clases disponibles</p>
            <div
              v-for="fc in flight.flightClasses ?? []"
              :key="fc.id"
              class="flex items-center justify-between p-3 rounded-xl bg-gray-50/80 hover:bg-blue-50/50 transition-colors"
            >
              <div class="flex items-center gap-2.5">
                <span class="text-base">{{ classIcon(fc.classType) }}</span>
                <span class="text-xs font-bold px-2.5 py-1 rounded-lg" :class="classColor(fc.classType)">
                  {{ classLabel(fc.classType) }}
                </span>
                <span class="text-xs text-gray-400">{{ fc.availableSeats }} asientos</span>
              </div>
              <div class="flex items-center gap-3">
                <div class="text-right">
                  <p class="text-xl font-black text-blue-600 leading-none">
                    ${{ (fc.basePrice * params.passengers).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </p>
                  <p v-if="params.passengers > 1" class="text-xs text-gray-400 mt-0.5">
                    ${{ fc.basePrice.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }} &times; {{ params.passengers }}
                  </p>
                </div>
                <button
                  @click="reserve(fc.id)"
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
    </div>
  </div>
</template>

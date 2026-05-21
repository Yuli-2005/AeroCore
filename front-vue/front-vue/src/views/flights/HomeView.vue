<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import AirportSearch from '../../components/AirportSearch.vue';
import { flightsService } from '../../services/flights.service';
import type { Flight } from '../../models/domain';
import heroImg from '../../assets/hero.png';

interface RouteCard {
  from: string;
  to: string;
  fromCity: string;
  toCity: string;
  price: number;
  date: string;
  color: string;
}

const ROUTE_COLORS = [
  'from-blue-500 to-blue-700',
  'from-indigo-500 to-purple-700',
  'from-teal-500 to-cyan-700',
  'from-orange-500 to-red-600',
  'from-emerald-500 to-lime-700',
  'from-sky-500 to-indigo-700',
];

function dateOnly(value: string | null | undefined): string {
  if (!value) return new Date().toISOString().split('T')[0];
  return value.split('T')[0];
}

function lowestPrice(flight: Flight): number | null {
  const prices = (flight.flightClasses ?? [])
    .filter(fc => fc.availableSeats > 0)
    .map(fc => Number(fc.basePrice))
    .filter(price => Number.isFinite(price) && price > 0);

  return prices.length ? Math.min(...prices) : null;
}

function buildRecommendedRoutes(flights: Flight[]): RouteCard[] {
  const routes = new Map<string, RouteCard>();

  for (const flight of flights) {
    if (flight.status !== 'SCHEDULED' && flight.status !== 'DELAYED') continue;

    const price = lowestPrice(flight);
    if (price === null) continue;

    const from = flight.route?.originAirport?.iataCode ?? flight.originAirportIata;
    const to = flight.route?.destinationAirport?.iataCode ?? flight.destinationAirportIata;
    if (!from || !to) continue;

    const key = `${from}-${to}`;
    const route: RouteCard = {
      from,
      to,
      fromCity: flight.route?.originAirport?.city || from,
      toCity: flight.route?.destinationAirport?.city || to,
      price,
      date: dateOnly(flight.departureDate),
      color: ROUTE_COLORS[routes.size % ROUTE_COLORS.length],
    };

    const current = routes.get(key);
    if (!current || route.price < current.price) routes.set(key, route);
  }

  return [...routes.values()].sort((a, b) => a.price - b.price).slice(0, 6);
}

const router = useRouter();

const today = new Date().toISOString().split('T')[0];
const passengers = ref(1);
const routes = ref<RouteCard[]>([]);
const loadingRoutes = ref(true);
const routeError = ref('');

const origin = ref('');
const destination = ref('');
const date = ref(today);
const classType = ref('');
const submitted = ref(false);

const originSearchRef = ref<any>(null);
const destinationSearchRef = ref<any>(null);

onMounted(() => {
  loadRecommendedRoutes();
});

function changePassengers(delta: number) {
  passengers.value = Math.min(9, Math.max(1, passengers.value + delta));
}

function swap() {
  const o = origin.value;
  origin.value = destination.value;
  destination.value = o;
}

function quickSearch(routeCard: RouteCard) {
  const params = new URLSearchParams({
    origin: routeCard.from,
    destination: routeCard.to,
    date: routeCard.date,
    passengers: '1',
  });
  router.push(`/results?${params}`);
}

function onSearch() {
  submitted.value = true;
  routeError.value = '';

  const finalOrigin = origin.value || originSearchRef.value?.resolveCurrentValue() || '';
  const finalDestination = destination.value || destinationSearchRef.value?.resolveCurrentValue() || '';

  origin.value = finalOrigin;
  destination.value = finalDestination;

  if (!finalOrigin || !finalDestination || !date.value) return;
  if (finalOrigin === finalDestination) {
    routeError.value = 'Origen y destino no pueden ser el mismo aeropuerto.';
    return;
  }

  const queryParams: Record<string, string> = {
    origin: finalOrigin,
    destination: finalDestination,
    date: date.value,
    passengers: String(passengers.value),
  };
  if (classType.value) {
    queryParams.class = classType.value;
  }

  const params = new URLSearchParams(queryParams);
  router.push(`/results?${params}`);
}

async function loadRecommendedRoutes() {
  loadingRoutes.value = true;
  try {
    const list = await flightsService.getAll();
    routes.value = buildRecommendedRoutes(list);
  } catch {
    routes.value = [];
  } finally {
    loadingRoutes.value = false;
  }
}
</script>

<template>
  <div>
    <!-- ═══════ HERO SECTION ═══════ -->
    <section class="relative min-h-[600px] lg:min-h-[700px] flex items-center overflow-hidden">
      <!-- Background image -->
      <div class="absolute inset-0">
        <img :src="heroImg" alt="Avión volando sobre las nubes al atardecer" class="w-full h-full object-cover" />
        <div class="absolute inset-0 bg-gradient-to-r from-slate-900/90 via-slate-900/70 to-slate-900/30"></div>
        <div class="absolute inset-0 bg-gradient-to-t from-slate-900/80 via-transparent to-transparent"></div>
      </div>

      <!-- Decorative floating particles -->
      <div class="absolute top-20 left-10 w-2 h-2 bg-blue-400/30 rounded-full animate-float" style="animation-delay: 0s"></div>
      <div class="absolute top-40 right-20 w-3 h-3 bg-purple-400/20 rounded-full animate-float" style="animation-delay: 1s"></div>
      <div class="absolute bottom-40 left-1/4 w-2 h-2 bg-cyan-400/25 rounded-full animate-float" style="animation-delay: 2s"></div>

      <!-- Content -->
      <div class="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-20 w-full">
        <div class="max-w-2xl animate-fade-up">
          <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/10 border border-white/20 text-blue-300 text-xs font-medium mb-6 backdrop-blur-sm">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            Reservas disponibles ahora
          </div>
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] tracking-tight mb-5">
            Encuentra tu
            <span class="bg-gradient-to-r from-blue-400 via-purple-400 to-cyan-400 bg-clip-text text-transparent"> próximo vuelo</span>
          </h1>
          <p class="text-lg text-slate-300 leading-relaxed max-w-lg mb-8">
            Busca entre cientos de destinos, compara precios y reserva en segundos. Tu aventura comienza aquí.
          </p>
        </div>

        <!-- ═══════ SEARCH CARD ═══════ -->
        <div class="glass rounded-2xl p-6 sm:p-8 shadow-2xl max-w-5xl animate-fade-up" style="animation-delay: 0.15s">
          <div class="grid grid-cols-1 sm:grid-cols-[1fr_auto_1fr_1fr] gap-3 items-start mb-4">
            <!-- Origen -->
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
                <svg class="inline w-3.5 h-3.5 mr-1 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                </svg>
                Origen
              </label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-400 z-10 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                </svg>
                <AirportSearch ref="originSearchRef" v-model="origin" placeholder="Ciudad o aeropuerto de salida" />
              </div>
              <p v-if="submitted && !origin" class="text-xs text-red-500 mt-1">Selecciona el origen</p>
            </div>

            <!-- Swap Button -->
            <button
              type="button"
              @click="swap"
              class="w-10 h-10 flex items-center justify-center bg-blue-50 hover:bg-blue-100 text-blue-500 hover:text-blue-700 rounded-xl transition-all duration-200 mt-7 self-start hover:rotate-180"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
              </svg>
            </button>

            <!-- Destino -->
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
                <svg class="inline w-3.5 h-3.5 mr-1 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
                Destino
              </label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-400 z-10 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
                <AirportSearch ref="destinationSearchRef" v-model="destination" placeholder="Ciudad o aeropuerto de llegada" />
              </div>
              <p v-if="submitted && !destination" class="text-xs text-red-500 mt-1">Selecciona el destino</p>
            </div>

            <!-- Fecha -->
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Fecha de salida</label>
              <input
                v-model="date"
                type="date"
                :min="today"
                class="w-full border-2 border-gray-200 rounded-xl px-3 py-2.5 text-sm text-gray-900 focus:ring-2 focus:ring-blue-500 focus:border-blue-400 outline-none transition-colors bg-white/80"
              />
              <p v-if="submitted && !date" class="text-xs text-red-500 mt-1">Selecciona la fecha</p>
            </div>
          </div>

          <!-- Passengers, Cabin Class & Submit -->
          <div class="flex flex-col sm:flex-row items-start sm:items-end gap-3">
            <!-- Passengers Count -->
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Pasajeros</label>
              <div class="flex items-center gap-2 border-2 border-gray-200 rounded-xl px-3 py-2 bg-white/80">
                <button
                  type="button"
                  @click="changePassengers(-1)"
                  :disabled="passengers <= 1"
                  class="w-7 h-7 flex items-center justify-center rounded-lg bg-gray-100 hover:bg-blue-100 text-gray-600 hover:text-blue-600 disabled:opacity-40 transition-all duration-200"
                >
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
                  </svg>
                </button>
                <span class="w-8 text-center text-sm font-bold text-gray-900 select-none">{{ passengers }}</span>
                <button
                  type="button"
                  @click="changePassengers(1)"
                  :disabled="passengers >= 9"
                  class="w-7 h-7 flex items-center justify-center rounded-lg bg-gray-100 hover:bg-blue-100 text-gray-600 hover:text-blue-600 disabled:opacity-40 transition-all duration-200"
                >
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                </button>
                <span class="text-xs text-gray-400 ml-1 select-none">{{ passengers === 1 ? 'adulto' : 'adultos' }}</span>
              </div>
            </div>

            <!-- Cabin Class -->
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Clase</label>
              <select
                v-model="classType"
                class="border-2 border-gray-200 rounded-xl px-3 py-2.5 text-sm text-gray-700 focus:ring-2 focus:ring-blue-500 focus:border-blue-400 outline-none bg-white/80 transition-colors"
              >
                <option value="">Cualquier clase</option>
                <option value="ECONOMY">Económica</option>
                <option value="BUSINESS">Business</option>
                <option value="FIRST">Primera clase</option>
              </select>
            </div>

            <!-- Search Button -->
            <button
              type="button"
              @click="onSearch"
              class="sm:ml-auto flex items-center justify-center gap-2 gradient-brand text-white font-semibold px-8 py-3 rounded-xl transition-all duration-300 shadow-lg hover:shadow-xl hover:shadow-blue-500/25 hover:scale-[1.03] active:scale-95 w-full sm:w-auto"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0" />
              </svg>
              Buscar vuelos
            </button>
          </div>

          <p v-if="routeError" class="text-xs text-red-500 mt-3">{{ routeError }}</p>
        </div>

        <!-- Quick Search Badges -->
        <div v-if="loadingRoutes || routes.length > 0" class="max-w-5xl mt-5 animate-fade-up" style="animation-delay: 0.3s">
          <p class="text-slate-400 text-xs font-medium mb-2">Rutas disponibles:</p>
          <div v-if="loadingRoutes" class="text-xs text-slate-300">Cargando rutas desde la base...</div>
          <div v-else class="flex flex-wrap gap-2">
            <button
              v-for="r in routes"
              :key="r.from + '-' + r.to"
              type="button"
              @click="quickSearch(r)"
              class="flex items-center gap-1.5 bg-white/10 hover:bg-white/20 text-white text-xs px-4 py-2 rounded-full transition-all duration-200 border border-white/15 backdrop-blur-sm hover:scale-105"
            >
              {{ r.fromCity }} &rarr; {{ r.toCity }}
              <span class="text-blue-300 font-semibold">desde ${{ r.price.toLocaleString('es-EC', { maximumFractionDigits: 0 }) }}</span>
            </button>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════ FEATURES SECTION ═══════ -->
    <section class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
      <div class="text-center mb-14">
        <h2 class="text-3xl font-extrabold text-gray-900 mb-3">¿Por qué <span class="gradient-brand-text">AeroCore</span>?</h2>
        <p class="text-gray-500 max-w-lg mx-auto">Todo lo que necesitas para viajar, en un solo lugar.</p>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-8">
        <div class="text-center group card-hover bg-white rounded-2xl p-8 border border-gray-100 shadow-sm">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 mb-5 shadow-lg shadow-blue-500/20 group-hover:scale-110 transition-transform duration-300">
            <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </div>
          <h3 class="font-bold text-gray-900 mb-2 text-lg">Múltiples aerolíneas</h3>
          <p class="text-sm text-gray-500 leading-relaxed">Compara vuelos con las aerolíneas disponibles en la base.</p>
        </div>
        <div class="text-center group card-hover bg-white rounded-2xl p-8 border border-gray-100 shadow-sm">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 mb-5 shadow-lg shadow-emerald-500/20 group-hover:scale-110 transition-transform duration-300">
            <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <h3 class="font-bold text-gray-900 mb-2 text-lg">Reserva segura</h3>
          <p class="text-sm text-gray-500 leading-relaxed">Tus datos y pago están protegidos en todo momento.</p>
        </div>
        <div class="text-center group card-hover bg-white rounded-2xl p-8 border border-gray-100 shadow-sm">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-violet-500 to-purple-600 mb-5 shadow-lg shadow-violet-500/20 group-hover:scale-110 transition-transform duration-300">
            <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h3 class="font-bold text-gray-900 mb-2 text-lg">Confirmación inmediata</h3>
          <p class="text-sm text-gray-500 leading-relaxed">Recibe tu código de reserva al instante.</p>
        </div>
      </div>
    </section>

    <!-- ═══════ RECOMMENDED FLIGHTS ═══════ -->
    <section class="bg-gradient-to-br from-slate-50 via-blue-50/50 to-indigo-50/30 py-20 px-4">
      <div class="max-w-6xl mx-auto">
        <div class="flex items-center justify-between mb-10">
          <div>
            <h2 class="text-3xl font-extrabold text-gray-900">Ofertas <span class="gradient-brand-text">recomendadas</span></h2>
            <p class="text-sm text-gray-500 mt-2">Rutas reales disponibles en la base de datos</p>
          </div>
        </div>

        <div v-if="loadingRoutes" class="glass rounded-2xl px-6 py-8 text-sm text-gray-500 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
            Cargando ofertas desde la base...
          </div>
        </div>

        <div v-else-if="routes.length === 0" class="glass rounded-2xl px-6 py-8 text-sm text-gray-500 shadow-sm">
          No hay vuelos con asientos disponibles para recomendar.
        </div>

        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <button
            v-for="(r, idx) in routes"
            :key="r.from + '::' + r.to"
            type="button"
            @click="quickSearch(r)"
            class="text-white rounded-2xl p-6 text-left hover:scale-[1.03] active:scale-95 transition-all duration-300 shadow-xl hover:shadow-2xl bg-gradient-to-br group relative overflow-hidden"
            :class="r.color"
            :style="{ animationDelay: idx * 0.08 + 's' }"
          >
            <!-- Decorative glow -->
            <div class="absolute -top-10 -right-10 w-32 h-32 bg-white/10 rounded-full blur-2xl group-hover:scale-150 transition-transform duration-500"></div>

            <div class="relative z-10">
              <div class="flex items-center justify-between mb-4">
                <div class="text-center">
                  <span class="text-2xl font-black tracking-tight">{{ r.from }}</span>
                  <p class="text-xs opacity-75 mt-0.5">{{ r.fromCity }}</p>
                </div>
                <div class="flex flex-col items-center gap-1 mx-3">
                  <svg class="w-5 h-5 opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                  <div class="w-16 h-px bg-white/30"></div>
                </div>
                <div class="text-center">
                  <span class="text-2xl font-black tracking-tight">{{ r.to }}</span>
                  <p class="text-xs opacity-75 mt-0.5">{{ r.toCity }}</p>
                </div>
              </div>
              <div class="border-t border-white/20 pt-4 mt-2">
                <p class="text-xs opacity-70">desde</p>
                <p class="text-3xl font-black">${{ r.price.toLocaleString('es-EC', { maximumFractionDigits: 0 }) }}</p>
                <p class="text-xs opacity-70 mt-0.5">por persona &middot; ida</p>
              </div>
            </div>
          </button>
        </div>
      </div>
    </section>
  </div>
</template>

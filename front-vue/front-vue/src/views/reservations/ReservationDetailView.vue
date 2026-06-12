<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { reservationsService } from '../../services/reservations.service';
import { paymentsService } from '../../services/payments.service';
import { invoicesService } from '../../services/invoices.service';
import type { Reservation, Payment, Invoice } from '../../models/domain';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

const route = useRoute();
const router = useRouter();

const loading = ref(true);
const error = ref<string | null>(null);
const reservation = ref<Reservation | null>(null);
const payment = ref<Payment | null>(null);
const invoice = ref<Invoice | null>(null);
const cancelLoading = ref(false);
const cancelError = ref<string | null>(null);

// Seat picker state
const activePaxIdx = ref<number | null>(null);
const occupiedSeats = ref<string[]>([]);
const seatLoading = ref(false);
const seatError = ref<string | null>(null);

// ── Helpers ────────────────────────────────────────
const firstSeg = computed(() => reservation.value?.flight?.segments?.[0] ?? null);
const lastSeg = computed(() => {
  const segs = reservation.value?.flight?.segments ?? [];
  return segs.length ? segs[segs.length - 1] : null;
});

function fmtDate(dt?: string | null, pattern = "d 'de' MMMM yyyy, HH:mm") {
  if (!dt) return '---';
  try { return format(new Date(dt), pattern, { locale: es }); } catch { return dt ?? '---'; }
}

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

function getClassType(flightClassId?: string) {
  if (!flightClassId) return 'ECONOMY';
  return reservation.value?.flight?.flightClasses?.find((fc: any) => fc.id === flightClassId)?.classType ?? 'ECONOMY';
}

function classLabel(t: string) {
  if (t === 'ECONOMY') return 'Económica';
  if (t === 'BUSINESS') return 'Business';
  if (t === 'FIRST') return 'Primera clase';
  return t;
}

function classColor(t: string) {
  if (t === 'FIRST') return 'bg-purple-100 text-purple-700 border-purple-200';
  if (t === 'BUSINESS') return 'bg-amber-100 text-amber-700 border-amber-200';
  return 'bg-sky-50 text-sky-700 border-sky-200';
}

function qrUrl(pax: any) {
  const code = reservation.value?.reservationCode ?? '';
  const name = `${pax.firstName}+${pax.lastName}`;
  const seat = pax.seatNumber || 'N/A';
  return `https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=RESERVA:${code}|PASAJERO:${name}|ASIENTO:${seat}`;
}

function printTickets() {
  window.print();
}

// ── Seat grid ──────────────────────────────────────
function buildSeatGrid(classType: string) {
  if (classType === 'FIRST') {
    return { rows: [1, 2, 3, 4, 5, 6], cols: ['A', 'B', 'C', 'D'], aisleAfter: 1 };
  }
  if (classType === 'BUSINESS') {
    return { rows: Array.from({ length: 8 }, (_, i) => i + 7), cols: ['A', 'B', 'C', 'D'], aisleAfter: 1 };
  }
  return {
    rows: Array.from({ length: 21 }, (_, i) => i + 15),
    cols: ['A', 'B', 'C', 'D', 'E', 'F'],
    aisleAfter: 2,
  };
}

const activeSeatGrid = computed(() => {
  if (activePaxIdx.value === null) return null;
  const pax = reservation.value?.passengers?.[activePaxIdx.value];
  if (!pax) return null;
  return buildSeatGrid(getClassType(pax.flightClassId));
});

const activePax = computed(() =>
  activePaxIdx.value !== null ? reservation.value?.passengers?.[activePaxIdx.value] ?? null : null
);

function seatNum(row: number, col: string) {
  return `${row}${col}`;
}

function seatState(row: number, col: string): 'my-seat' | 'other-pax' | 'occupied' | 'available' {
  const seat = seatNum(row, col);
  const pax = activePax.value;
  if (pax?.seatNumber === seat) return 'my-seat';
  if (reservation.value?.passengers?.some((p, i) => i !== activePaxIdx.value && p.seatNumber === seat)) {
    return 'other-pax';
  }
  if (occupiedSeats.value.includes(seat)) return 'occupied';
  return 'available';
}

function seatClass(state: string) {
  if (state === 'my-seat') return 'bg-blue-500 text-white border-2 border-blue-600 shadow-md shadow-blue-500/30 scale-105';
  if (state === 'other-pax') return 'bg-indigo-200 text-indigo-600 border-2 border-indigo-300 cursor-not-allowed opacity-80';
  if (state === 'occupied') return 'bg-gray-200 text-gray-400 border-2 border-gray-200 cursor-not-allowed';
  return 'bg-white text-gray-700 border-2 border-gray-200 hover:border-blue-400 hover:bg-blue-50 cursor-pointer hover:scale-110 transition-transform';
}

// ── Seat picker actions ────────────────────────────
async function toggleSeatPicker(index: number) {
  if (activePaxIdx.value === index) {
    activePaxIdx.value = null;
    return;
  }
  const pax = reservation.value?.passengers?.[index];
  if (!pax?.id || !pax.flightClassId) return;

  activePaxIdx.value = index;
  seatLoading.value = true;
  seatError.value = null;
  try {
    occupiedSeats.value = await reservationsService.occupiedSeats(pax.flightClassId);
  } catch (err: any) {
    seatError.value = err?.message || 'Error al cargar el mapa de asientos';
  } finally {
    seatLoading.value = false;
  }
}

async function pickSeat(row: number, col: string) {
  if (!reservation.value || activePaxIdx.value === null) return;
  const pax = reservation.value.passengers?.[activePaxIdx.value];
  if (!pax?.id) return;
  const seat = seatNum(row, col);
  if (seatState(row, col) === 'occupied' || seatState(row, col) === 'other-pax') return;

  seatLoading.value = true;
  seatError.value = null;
  try {
    await reservationsService.setSeat(reservation.value.id, pax.id, seat);
    const prev = pax.seatNumber;
    pax.seatNumber = seat;
    if (prev) occupiedSeats.value = occupiedSeats.value.filter(s => s !== prev);
    if (!occupiedSeats.value.includes(seat)) occupiedSeats.value.push(seat);
    activePaxIdx.value = null;
  } catch (err: any) {
    seatError.value = err?.message || 'Error al asignar asiento. Inténtalo de nuevo.';
  } finally {
    seatLoading.value = false;
  }
}

// ── Cancel ─────────────────────────────────────────
async function cancelReservation() {
  if (!reservation.value) return;
  if (!confirm('¿Confirmas la cancelación de esta reserva? Esta acción no se puede deshacer.')) return;
  cancelLoading.value = true;
  cancelError.value = null;
  try {
    await reservationsService.cancel(reservation.value.id);
    reservation.value.status = 'CANCELLED';
    activePaxIdx.value = null;
  } catch (err: any) {
    cancelError.value = err?.message || 'Error al cancelar la reserva';
  } finally {
    cancelLoading.value = false;
  }
}

// ── Load data ──────────────────────────────────────
onMounted(async () => {
  const id = route.params.id as string;
  try {
    reservation.value = await reservationsService.getById(id);
    const pays = await paymentsService.byReservation(id);
    if (pays.length) {
      payment.value = pays[0];
      try { invoice.value = await invoicesService.byPayment(pays[0].id); } catch { /* no invoice yet */ }
    }
  } catch (err: any) {
    error.value = err?.message || 'Error al cargar la reserva';
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/30 min-h-screen">

    <!-- Header (no-print) -->
    <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-8 no-print">
      <div class="max-w-3xl mx-auto">
        <button
          @click="router.push({ name: 'my-trips' })"
          class="flex items-center gap-2 text-slate-300 hover:text-white text-sm font-medium transition-colors mb-4"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Mis viajes
        </button>

        <template v-if="!loading && reservation">
          <!-- Ruta visible en el header -->
          <div class="flex items-center gap-2 mb-2">
            <span class="text-2xl font-black tracking-tight">
              {{ firstSeg?.originAirport?.iataCode ?? '---' }}
            </span>
            <svg class="w-5 h-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            <span class="text-2xl font-black tracking-tight">
              {{ lastSeg?.destinationAirport?.iataCode ?? '---' }}
            </span>
            <span class="mx-2 text-slate-500">·</span>
            <span class="font-mono font-bold text-lg tracking-wider">{{ reservation.reservationCode }}</span>
            <span class="text-xs px-3 py-1 rounded-full font-semibold border ml-1" :class="statusBadge(reservation.status)">
              {{ statusText(reservation.status) }}
            </span>
          </div>
          <p class="text-slate-400 text-sm">
            {{ fmtDate(reservation.createdAt, "d MMM yyyy") }}
            <span v-if="firstSeg?.originAirport?.city?.name"> · {{ firstSeg.originAirport.city.name }}</span>
            <span v-if="lastSeg?.destinationAirport?.city?.name"> → {{ lastSeg.destinationAirport.city.name }}</span>
          </p>
        </template>
        <template v-else-if="!loading">
          <h1 class="text-2xl font-extrabold">Detalle de reserva</h1>
        </template>
      </div>
    </div>

    <!-- Content -->
    <div class="max-w-3xl mx-auto px-4 py-8 space-y-5">

      <!-- Loading -->
      <div v-if="loading" class="flex flex-col items-center py-20 gap-4 no-print">
        <div class="relative w-14 h-14">
          <div class="absolute inset-0 rounded-full border-4 border-blue-100"></div>
          <div class="absolute inset-0 rounded-full border-4 border-blue-500 border-t-transparent animate-spin"></div>
        </div>
        <p class="text-sm text-gray-400 font-medium">Cargando reserva...</p>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl p-5 no-print">
        <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm text-red-700">{{ error }}</p>
      </div>

      <template v-else-if="reservation">

        <!-- ── 1. FLIGHT INFO ──────────────────────────────── -->
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden no-print">
          <div class="px-6 pt-5 pb-4 border-b border-gray-50">
            <h2 class="font-bold text-gray-900 text-sm flex items-center gap-2">
              <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
              Información del vuelo
            </h2>
          </div>
          <div class="px-6 py-5">
            <div class="flex items-center gap-4 mb-5">
              <div class="text-center min-w-[72px]">
                <p class="text-4xl font-black text-gray-900 tracking-tight leading-none">
                  {{ firstSeg?.originAirport?.iataCode ?? '---' }}
                </p>
                <p class="text-xs font-bold text-blue-600 mt-1">{{ firstSeg?.originAirport?.iataCode ?? '' }}</p>
                <p class="text-xs text-gray-400 mt-0.5 max-w-[72px] truncate">{{ firstSeg?.originAirport?.city?.name ?? '' }}</p>
              </div>

              <div class="flex-1 flex flex-col items-center gap-1.5">
                <p class="text-xs text-gray-400 font-medium">{{ (reservation.flight?.segments?.length ?? 0) > 1 ? 'Con escala' : 'Vuelo directo' }}</p>
                <div class="w-full flex items-center gap-1">
                  <div class="flex-1 h-0.5 bg-gradient-to-r from-blue-200 to-indigo-200 rounded-full"></div>
                  <svg class="w-3.5 h-3.5 text-blue-400" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                  </svg>
                </div>
                <p class="text-xs text-gray-400">{{ firstSeg?.airline?.name ?? '' }}</p>
              </div>

              <div class="text-center min-w-[72px]">
                <p class="text-4xl font-black text-gray-900 tracking-tight leading-none">
                  {{ lastSeg?.destinationAirport?.iataCode ?? '---' }}
                </p>
                <p class="text-xs font-bold text-blue-600 mt-1">{{ lastSeg?.destinationAirport?.iataCode ?? '' }}</p>
                <p class="text-xs text-gray-400 mt-0.5 max-w-[72px] truncate">{{ lastSeg?.destinationAirport?.city?.name ?? '' }}</p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div class="bg-gray-50 rounded-xl px-4 py-3">
                <p class="text-xs text-gray-400 font-medium mb-0.5">Salida</p>
                <p class="text-sm font-bold text-gray-800">{{ fmtDate(firstSeg?.departureDateTime) }}</p>
              </div>
              <div class="bg-gray-50 rounded-xl px-4 py-3">
                <p class="text-xs text-gray-400 font-medium mb-0.5">Llegada</p>
                <p class="text-sm font-bold text-gray-800">{{ fmtDate(lastSeg?.arrivalDateTime) }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- ── 2. PASE DE ABORDAR ──────────────────────────── -->
        <div id="ticket-print-area" class="space-y-4">
          <!-- Título + botón imprimir -->
          <div class="flex items-center justify-between px-1 no-print">
            <h2 class="text-xs font-bold text-gray-400 uppercase tracking-wider">
              🎫 Pase{{ (reservation.passengers?.length ?? 0) > 1 ? 's' : '' }} de abordar
            </h2>
            <button
              @click="printTickets"
              class="flex items-center gap-1.5 text-xs font-bold px-4 py-2 rounded-xl gradient-brand text-white hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.03] transition-all active:scale-95"
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              Imprimir / Guardar PDF
            </button>
          </div>

          <!-- Una tarjeta por pasajero -->
          <div
            v-for="pax in reservation.passengers"
            :key="pax.id"
            class="bg-white border border-gray-200 rounded-3xl overflow-hidden shadow-md flex flex-col md:flex-row ticket-card-print"
          >
            <!-- Lado izquierdo: info del vuelo -->
            <div class="flex-1 p-6 relative">
              <div class="absolute right-4 top-4 opacity-5 pointer-events-none select-none">
                <svg class="w-32 h-32" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </div>

              <!-- Cabecera del boleto -->
              <div class="flex justify-between items-start border-b border-dashed border-gray-200 pb-4 mb-4">
                <div class="flex items-center gap-2">
                  <div class="w-8 h-8 rounded-lg gradient-brand flex items-center justify-center text-white flex-shrink-0">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                    </svg>
                  </div>
                  <div>
                    <span class="font-extrabold text-sm text-gray-800">AeroCore</span>
                    <span class="text-[9px] text-gray-400 font-bold uppercase tracking-widest block leading-none">Tarjeta de Abordaje</span>
                  </div>
                </div>
                <div class="text-right">
                  <span class="text-[10px] text-gray-400 font-bold uppercase tracking-wider block">Código de Reserva</span>
                  <span class="font-mono font-black text-indigo-600 text-sm tracking-wider">{{ reservation.reservationCode }}</span>
                </div>
              </div>

              <!-- Ruta del vuelo -->
              <div class="flex justify-between items-center mb-5">
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block">Origen</span>
                  <span class="text-3xl font-black text-gray-900 leading-none">{{ firstSeg?.originAirport?.iataCode ?? '---' }}</span>
                  <span class="text-xs text-gray-500 font-semibold block mt-0.5 max-w-[110px] truncate">{{ firstSeg?.originAirport?.city?.name ?? '' }}</span>
                </div>

                <div class="flex-1 flex flex-col items-center px-3">
                  <span class="text-[8px] text-gray-400 font-bold uppercase tracking-widest mb-1">{{ firstSeg?.airline?.name ?? 'AeroCore' }}</span>
                  <div class="w-full flex items-center gap-1">
                    <div class="flex-1 h-[2px] bg-slate-200"></div>
                    <svg class="w-4 h-4 text-slate-400 transform rotate-90" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                    </svg>
                    <div class="flex-1 h-[2px] bg-slate-200"></div>
                  </div>
                  <span class="text-[9px] text-slate-400 font-mono mt-1">{{ (reservation as any).flight?.flightNumber ?? '' }}</span>
                </div>

                <div class="text-right">
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block">Destino</span>
                  <span class="text-3xl font-black text-gray-900 leading-none">{{ lastSeg?.destinationAirport?.iataCode ?? '---' }}</span>
                  <span class="text-xs text-gray-500 font-semibold block mt-0.5 max-w-[110px] truncate text-right">{{ lastSeg?.destinationAirport?.city?.name ?? '' }}</span>
                </div>
              </div>

              <!-- Grid de datos del pasajero -->
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 bg-slate-50 rounded-2xl p-4 border border-slate-100">
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Pasajero</span>
                  <span class="text-xs font-bold text-slate-800 block truncate">{{ pax.firstName }} {{ pax.lastName }}</span>
                  <span class="text-[9px] text-slate-400 font-mono block leading-none mt-0.5">{{ pax.documentNumber }}</span>
                </div>
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Fecha y Hora</span>
                  <span class="text-xs font-bold text-slate-800 block">{{ fmtDate(firstSeg?.departureDateTime, 'd MMM yyyy, HH:mm') }}</span>
                </div>
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Clase</span>
                  <span class="text-xs font-bold text-slate-800 block">{{ classLabel(getClassType(pax.flightClassId)) }}</span>
                </div>
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Asiento</span>
                  <span class="text-sm font-black text-indigo-600 block font-mono leading-none">{{ pax.seatNumber || 'N/A' }}</span>
                </div>
              </div>
            </div>

            <!-- Separador punteado -->
            <div class="hidden md:flex flex-col items-center justify-between py-4 relative">
              <div class="w-4 h-4 bg-slate-50 rounded-full border-b border-gray-200 absolute -top-2 z-10"></div>
              <div class="w-[1px] h-full border-r-2 border-dashed border-gray-200"></div>
              <div class="w-4 h-4 bg-slate-50 rounded-full border-t border-gray-200 absolute -bottom-2 z-10"></div>
            </div>

            <!-- Lado derecho: talón con QR -->
            <div class="bg-slate-50/50 p-6 flex flex-col justify-between items-center border-t md:border-t-0 md:border-l border-gray-100 min-w-[190px] text-center">
              <div class="w-full">
                <span class="text-[8px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Talón de Embarque</span>
                <p class="text-xs font-black text-slate-800 truncate">{{ pax.firstName }} {{ pax.lastName }}</p>
                <p class="text-[9px] text-slate-400 font-mono leading-none">
                  {{ firstSeg?.originAirport?.iataCode ?? '---' }} → {{ lastSeg?.destinationAirport?.iataCode ?? '---' }}
                </p>
              </div>

              <!-- QR Code -->
              <div class="my-4">
                <img
                  :src="qrUrl(pax)"
                  class="w-24 h-24 border p-1 bg-white rounded-lg shadow-sm"
                  alt="QR Code boarding pass"
                />
              </div>

              <div>
                <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block leading-none mb-1">Asiento</span>
                <span class="text-2xl font-black text-indigo-600 font-mono leading-none">{{ pax.seatNumber || 'N/A' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- ── 3. PASAJEROS Y CAMBIO DE ASIENTO ──────────── -->
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden no-print">
          <div class="px-6 pt-5 pb-4 border-b border-gray-50 flex items-center justify-between">
            <h2 class="font-bold text-gray-900 text-sm flex items-center gap-2">
              <svg class="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              Pasajeros y asientos
            </h2>
            <span class="text-xs text-gray-400">{{ reservation.passengers?.length ?? 0 }} pasajero{{ (reservation.passengers?.length ?? 0) !== 1 ? 's' : '' }}</span>
          </div>

          <div class="divide-y divide-gray-50">
            <div v-for="(pax, idx) in reservation.passengers" :key="pax.id ?? idx">
              <!-- Fila del pasajero -->
              <div class="px-6 py-4 flex items-center justify-between gap-4">
                <div class="flex items-center gap-3 min-w-0">
                  <div class="w-9 h-9 bg-indigo-50 rounded-xl flex items-center justify-center flex-shrink-0">
                    <svg class="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-bold text-gray-800 truncate">{{ pax.firstName }} {{ pax.lastName }}</p>
                    <p class="text-xs text-gray-400 font-mono">{{ pax.documentNumber }}</p>
                  </div>
                </div>

                <div class="flex items-center gap-3 flex-shrink-0">
                  <span class="hidden sm:inline text-xs px-2.5 py-1 rounded-lg font-semibold border" :class="classColor(getClassType(pax.flightClassId))">
                    {{ classLabel(getClassType(pax.flightClassId)) }}
                  </span>

                  <div v-if="pax.seatNumber" class="text-center">
                    <span class="font-mono font-black text-blue-600 text-base">{{ pax.seatNumber }}</span>
                  </div>

                  <button
                    v-if="reservation.status === 'CONFIRMED'"
                    @click="toggleSeatPicker(idx)"
                    class="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-xl transition-all"
                    :class="activePaxIdx === idx
                      ? 'bg-blue-600 text-white shadow-md shadow-blue-500/25'
                      : 'bg-gray-100 text-gray-600 hover:bg-blue-50 hover:text-blue-700'"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                    </svg>
                    {{ pax.seatNumber ? 'Cambiar' : 'Asignar asiento' }}
                    <svg class="w-3 h-3 transition-transform" :class="activePaxIdx === idx ? 'rotate-180' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>

                  <span v-else-if="!pax.seatNumber" class="text-xs text-gray-400 italic">Sin asiento</span>
                </div>
              </div>

              <!-- Mapa de asientos (inline) -->
              <div
                v-if="activePaxIdx === idx && activeSeatGrid"
                class="border-t border-blue-100 bg-blue-50/40 px-6 py-5"
              >
                <div class="flex items-center justify-between mb-4">
                  <p class="text-xs font-bold text-gray-600 uppercase tracking-wide">
                    Asiento para <span class="text-blue-700">{{ pax.firstName }}</span>
                  </p>
                  <div class="flex items-center gap-3 text-[10px] text-gray-500">
                    <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-blue-500 inline-block"></span> Tu asiento</span>
                    <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-gray-200 inline-block"></span> Ocupado</span>
                    <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-white border-2 border-gray-200 inline-block"></span> Libre</span>
                  </div>
                </div>

                <div v-if="seatLoading" class="flex items-center justify-center py-8 gap-2">
                  <svg class="w-4 h-4 animate-spin text-blue-500" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span class="text-sm text-gray-400">Cargando mapa de asientos...</span>
                </div>

                <div v-else-if="seatError" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-3">
                  {{ seatError }}
                </div>

                <div v-else class="overflow-x-auto">
                  <div class="flex justify-center mb-3">
                    <div class="flex items-center gap-2 text-xs text-gray-400 font-medium">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                      </svg>
                      Frente del avión
                    </div>
                  </div>
                  <div class="inline-block min-w-full">
                    <div class="flex items-center gap-1 mb-2 pl-9">
                      <template v-for="(col, ci) in activeSeatGrid.cols" :key="col">
                        <div v-if="ci === activeSeatGrid.aisleAfter + 1" class="w-5"></div>
                        <div class="w-9 text-center text-xs font-bold text-gray-400">{{ col }}</div>
                      </template>
                    </div>
                    <div v-for="row in activeSeatGrid.rows" :key="row" class="flex items-center gap-1 mb-1">
                      <div class="w-8 text-center text-xs font-medium text-gray-400 flex-shrink-0">{{ row }}</div>
                      <template v-for="(col, ci) in activeSeatGrid.cols" :key="col">
                        <div v-if="ci === activeSeatGrid.aisleAfter + 1" class="w-5 flex items-center justify-center">
                          <div class="w-px h-6 bg-gray-300"></div>
                        </div>
                        <button
                          class="w-9 h-9 rounded-lg text-[11px] font-bold flex items-center justify-center flex-shrink-0 transition-all duration-150"
                          :class="seatClass(seatState(row, col))"
                          :disabled="seatState(row, col) === 'occupied' || seatState(row, col) === 'other-pax' || seatLoading"
                          :title="seatNum(row, col)"
                          @click="pickSeat(row, col)"
                        >
                          {{ col }}
                        </button>
                      </template>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- ── 4. PAGO COMPACTO ──────────────────────────── -->
        <div v-if="payment" class="bg-white rounded-2xl border border-gray-100 shadow-sm px-6 py-4 no-print">
          <div class="flex items-center justify-between gap-4 flex-wrap">
            <!-- Método de pago -->
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 bg-emerald-50 rounded-xl flex items-center justify-center flex-shrink-0">
                <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-bold text-gray-800">
                  Pagado con {{ payment.provider }}
                  <span v-if="invoice" class="text-gray-400 font-normal"> · ${{ Number(invoice.total).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </p>
                <p class="text-xs text-gray-400">
                  <span v-if="invoice">Factura {{ invoice.invoiceNumber }} · {{ fmtDate(invoice.createdAt, 'd MMM yyyy') }}</span>
                  <span v-else class="flex items-center gap-1">
                    <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                    </svg>
                    Factura en proceso de generación...
                  </span>
                </p>
              </div>
            </div>

            <!-- Total destacado -->
            <div v-if="invoice" class="text-right">
              <p class="text-xs text-gray-400 font-medium">Total pagado</p>
              <p class="text-xl font-black text-blue-700">${{ Number(invoice.total).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</p>
            </div>
          </div>
        </div>

        <!-- ── 5. CANCELAR ──────────────────────────────── -->
        <div v-if="reservation.status === 'CONFIRMED'" class="bg-white rounded-2xl border border-gray-100 shadow-sm px-6 py-5 no-print">
          <p class="text-sm text-gray-500 mb-3">¿Necesitas cancelar este viaje? Los asientos serán devueltos al inventario.</p>
          <div v-if="cancelError" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-2 mb-3">
            {{ cancelError }}
          </div>
          <button
            @click="cancelReservation"
            :disabled="cancelLoading"
            class="flex items-center gap-2 text-sm font-bold px-5 py-2.5 rounded-xl border-2 border-red-200 text-red-600 hover:bg-red-50 hover:border-red-400 transition-all disabled:opacity-50"
          >
            <svg v-if="cancelLoading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
            {{ cancelLoading ? 'Cancelando...' : 'Cancelar reserva' }}
          </button>
        </div>

        <!-- Banner reserva cancelada -->
        <div v-else-if="reservation.status === 'CANCELLED'" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl px-6 py-4 no-print">
          <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
          <p class="text-sm text-red-700 font-medium">Esta reserva fue cancelada. Los asientos han sido devueltos.</p>
        </div>

      </template>
    </div>
  </div>
</template>

<style>
@media print {
  /* Ocultar navbar, footer y todo lo marcado como no-print */
  header,
  footer,
  nav,
  button,
  .no-print {
    display: none !important;
  }

  html, body {
    background: white !important;
    color: black !important;
    margin: 0 !important;
    padding: 0 !important;
  }

  /* El área de boletos ocupa toda la página */
  #ticket-print-area {
    position: fixed !important;
    inset: 0 !important;
    padding: 1.5rem !important;
    background: white !important;
    overflow: visible !important;
  }

  /* Cada boleto: forzar layout horizontal y evitar cortes */
  .ticket-card-print {
    display: flex !important;
    flex-direction: row !important;
    page-break-inside: avoid !important;
    break-inside: avoid !important;
    margin-bottom: 2rem !important;
    border: 2px solid #cbd5e1 !important;
    box-shadow: none !important;
    border-radius: 1.25rem !important;
    background: white !important;
    overflow: hidden !important;
  }
}
</style>

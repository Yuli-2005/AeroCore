<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { reservationsService } from '../../services/reservations.service';
import { paymentsService } from '../../services/payments.service';
import { promotionsService } from '../../services/promotions.service';
import { invoicesService } from '../../services/invoices.service';
import type { PromotionValidation, Invoice, Reservation } from '../../models/domain';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

const CARD_PROVIDERS = [
  { value: 'VISA', label: 'Visa' },
  { value: 'MASTERCARD', label: 'Mastercard' },
  { value: 'AMEX', label: 'American Express' },
  { value: 'PAYPAL', label: 'PayPal' },
];

function generateTxId() {
  return `TXN-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
}

const route = useRoute();
const router = useRouter();

const flightClassId = ref('');
const step = ref<1 | 2 | 3 | 4>(1);
const errorMsg = ref<string | null>(null);
const payLoading = ref(false);
const promoLoading = ref(false);
const promoError = ref<string | null>(null);
const promoResult = ref<PromotionValidation | null>(null);
const successData = ref<{ reservationId: string; reservationCode: string; invoice: Invoice | null } | null>(null);
const promoCode = ref('');
const cardDisplay = ref('');
const cardProviders = CARD_PROVIDERS;

const steps = [
  { n: 1, label: 'Pasajeros' },
  { n: 2, label: 'Pago' },
  { n: 3, label: 'Asiento' },
  { n: 4, label: 'Boleto' },
];

const passengers = ref([{ firstName: '', lastName: '', documentNumber: '' }]);
const submitted1 = ref(false);

const paymentForm = ref({
  provider: 'VISA',
  cardholderName: '',
  cardNumber: '',
  expiry: '',
  cvv: '',
});
const submitted2 = ref(false);
const isCvvFocused = ref(false);
const basePrice = ref(0);

const createdReservation = ref<Reservation | null>(null);

// Seat picker state
const activePaxIdx = ref<number | null>(null);
const occupiedSeats = ref<string[]>([]);
const seatLoading = ref(false);
const seatError = ref<string | null>(null);

const pricingBreakdown = computed(() => {
  const passengerCount = passengers.value.length;
  const subtotal = basePrice.value * passengerCount;
  const discount = promoResult.value ? promoResult.value.discountAmount : 0;
  const taxable = Math.max(0, subtotal - discount);
  const tax = taxable * 0.15;
  const total = taxable + tax;
  return {
    subtotal,
    discount,
    tax,
    total
  };
});

const allSeatsAssigned = computed(() => {
  return createdReservation.value?.passengers?.every((p: any) => p.seatNumber) ?? false;
});

const firstSeg = computed(() => createdReservation.value?.flight?.segments?.[0] ?? null);
const lastSeg = computed(() => {
  const segs = createdReservation.value?.flight?.segments ?? [];
  return segs.length ? segs[segs.length - 1] : null;
});

function getCardBgClass(provider: string) {
  switch (provider) {
    case 'VISA':
      return 'from-indigo-600 via-violet-800 to-slate-900';
    case 'MASTERCARD':
      return 'from-purple-600 via-pink-700 to-slate-900';
    case 'AMEX':
      return 'from-teal-600 via-indigo-700 to-purple-900';
    case 'PAYPAL':
      return 'from-blue-600 via-indigo-700 to-slate-900';
    default:
      return 'from-indigo-600 via-violet-800 to-slate-900';
  }
}

onMounted(() => {
  flightClassId.value = (route.params.flightClassId as string) || '';
  basePrice.value = Number(route.query.price) || 0;
});

function addPassenger() {
  passengers.value.push({ firstName: '', lastName: '', documentNumber: '' });
}

function removePassenger(index: number) {
  if (passengers.value.length > 1) {
    passengers.value.splice(index, 1);
  }
}

function stepClass(n: number) {
  if (step.value === n) return 'gradient-brand text-white shadow-lg shadow-blue-500/30';
  if (step.value > n) return 'bg-emerald-500 text-white';
  return 'bg-gray-200 text-gray-500';
}

function goBack() {
  if (step.value === 2) {
    step.value = 1;
    createdReservation.value = null;
  } else {
    router.push('/results');
  }
}

function nextStep() {
  submitted1.value = true;
  const valid = passengers.value.every(
    p => p.firstName.trim() && p.lastName.trim() && p.documentNumber.trim()
  );
  if (!valid) return;

  step.value = 2;
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function validatePromo() {
  if (!promoCode.value) return;
  promoLoading.value = true;
  promoError.value = null;
  const base = (basePrice.value || 100) * passengers.value.length;
  try {
    const res = await promotionsService.validate(promoCode.value, base);
    promoResult.value = res;
    createdReservation.value = null; // Clear cached reservation if promo changes
  } catch (err: any) {
    promoError.value = err?.message || 'Código inválido';
    promoResult.value = null;
    createdReservation.value = null;
  } finally {
    promoLoading.value = false;
  }
}

function onCardInput(e: Event) {
  const inp = e.target as HTMLInputElement;
  const fmt = inp.value.replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim();
  cardDisplay.value = fmt;
  paymentForm.value.cardNumber = fmt;
}

function onExpiryInput(e: Event) {
  const inp = e.target as HTMLInputElement;
  let v = inp.value.replace(/\D/g, '').slice(0, 4);
  if (v.length >= 3) {
    v = v.slice(0, 2) + '/' + v.slice(2);
  }
  inp.value = v;
  paymentForm.value.expiry = v;
}

async function submitPayment() {
  submitted2.value = true;
  const cardClean = paymentForm.value.cardNumber.replace(/\s/g, '');
  const expiryClean = paymentForm.value.expiry.replace(/\D/g, '');
  const cvvClean = paymentForm.value.cvv.replace(/\D/g, '');

  const valid =
    paymentForm.value.provider &&
    paymentForm.value.cardholderName.trim() &&
    cardClean.length === 16 &&
    expiryClean.length === 4 &&
    (cvvClean.length === 3 || cvvClean.length === 4);

  if (!valid) {
    window.scrollTo({ top: 0, behavior: 'smooth' });
    return;
  }

  payLoading.value = true;
  errorMsg.value = null;

  try {
    let reservation = createdReservation.value;

    if (!reservation) {
      reservation = await reservationsService.create({
        flightClassId: flightClassId.value,
        passengers: passengers.value,
        promotionCode: promoResult.value ? promoCode.value : undefined,
      });
      createdReservation.value = reservation;
    }

    const payment = await paymentsService.create({
      reservationId: reservation.id,
      amount: Number(reservation.totalAmount),
      provider: paymentForm.value.provider,
      transactionId: generateTxId(),
    });

    setTimeout(async () => {
      try {
        const invoice = await invoicesService.byPayment(payment.id);
        payLoading.value = false;
        successData.value = {
          reservationId: reservation.id,
          reservationCode: reservation.reservationCode,
          invoice,
        };
      } catch {
        payLoading.value = false;
        successData.value = {
          reservationId: reservation.id,
          reservationCode: reservation.reservationCode,
          invoice: null,
        };
      }

      // Load full reservation details with passenger IDs, flight classes etc.
      try {
        const fullRes = await reservationsService.getById(reservation.id);
        createdReservation.value = fullRes;
        step.value = 3;
        activePaxIdx.value = 0;
        if (fullRes.passengers?.[0]?.flightClassId) {
          occupiedSeats.value = await reservationsService.occupiedSeats(fullRes.passengers[0].flightClassId);
        }
      } catch (err: any) {
        errorMsg.value = 'El pago fue exitoso, pero ocurrió un error al cargar la información para la asignación de asientos. Por favor, reintenta desde Mis viajes.';
        console.error(err);
      }
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }, 1200);
  } catch (err: any) {
    errorMsg.value = err?.response?.data?.error?.message || err?.message || 'Error al procesar el pago';
    payLoading.value = false;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
}

// ── Helpers ────────────────────────────────────────────
function fmtDate(dt?: string | null, pattern = "d 'de' MMMM yyyy, HH:mm") {
  if (!dt) return '---';
  try { return format(new Date(dt), pattern, { locale: es }); } catch { return dt ?? '---'; }
}

function getClassType(flightClassId?: string) {
  if (!flightClassId) return 'ECONOMY';
  return createdReservation.value?.flight?.flightClasses?.find((fc: any) => fc.id === flightClassId)?.classType ?? 'ECONOMY';
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

// ── Seat grid ──────────────────────────────────────────
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
  const pax = createdReservation.value?.passengers?.[activePaxIdx.value];
  if (!pax) return null;
  return buildSeatGrid(getClassType(pax.flightClassId));
});

const activePax = computed(() =>
  activePaxIdx.value !== null ? createdReservation.value?.passengers?.[activePaxIdx.value] ?? null : null
);

function seatNum(row: number, col: string) {
  return `${row}${col}`;
}

function seatState(row: number, col: string): 'my-seat' | 'other-pax' | 'occupied' | 'available' {
  const seat = seatNum(row, col);
  const pax = activePax.value;
  if (pax?.seatNumber === seat) return 'my-seat';
  if (createdReservation.value?.passengers?.some((p: any, i: number) => i !== activePaxIdx.value && p.seatNumber === seat)) {
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

async function selectPax(index: number) {
  if (!createdReservation.value?.passengers) return;
  const pax = createdReservation.value.passengers[index];
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
  const currentIdx = activePaxIdx.value;
  if (!createdReservation.value?.passengers || currentIdx === null) return;
  const pax = createdReservation.value.passengers[currentIdx];
  if (!pax?.id) return;
  const seat = seatNum(row, col);
  if (seatState(row, col) === 'occupied' || seatState(row, col) === 'other-pax') return;

  seatLoading.value = true;
  seatError.value = null;
  try {
    await reservationsService.setSeat(createdReservation.value.id, pax.id, seat);
    const prev = pax.seatNumber;
    pax.seatNumber = seat;
    if (prev) occupiedSeats.value = occupiedSeats.value.filter(s => s !== prev);
    if (!occupiedSeats.value.includes(seat)) occupiedSeats.value.push(seat);
    
    // Automatically select next passenger if available
    if (currentIdx < createdReservation.value.passengers.length - 1) {
      const nextIdx = currentIdx + 1;
      activePaxIdx.value = nextIdx;
      const nextPax = createdReservation.value.passengers[nextIdx];
      if (nextPax && nextPax.flightClassId) {
        occupiedSeats.value = await reservationsService.occupiedSeats(nextPax.flightClassId);
      }
    }
  } catch (err: any) {
    seatError.value = err?.message || 'Error al asignar asiento. Inténtalo de nuevo.';
  } finally {
    seatLoading.value = false;
  }
}

function printTickets() {
  window.print();
}

function finalizeBooking() {
  step.value = 4;
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/30 min-h-screen">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-8 no-print">
      <div class="max-w-2xl mx-auto">
        <button
          v-if="step <= 2"
          @click="goBack"
          class="flex items-center gap-2 text-slate-300 hover:text-white text-sm font-medium transition-colors mb-4"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          {{ step === 2 ? 'Volver a datos de pasajeros' : 'Volver' }}
        </button>

        <h1 class="text-2xl font-extrabold tracking-tight mb-1">
          {{ step === 1 ? 'Datos de pasajeros' : step === 2 ? 'Información de pago' : step === 3 ? 'Selección de asientos' : '¡Compra completada con éxito!' }}
        </h1>
        <p class="text-slate-300 text-sm">
          {{ step === 1 ? 'Ingresa los datos de todos los pasajeros' : step === 2 ? 'Completa los datos de tu tarjeta' : step === 3 ? 'Selecciona un asiento para cada pasajero' : 'Aquí están tus pases de abordar. Puedes imprimirlos o guardarlos como PDF.' }}
        </p>

        <!-- Step progress -->
        <div class="flex items-center gap-3 mt-6">
          <div v-for="(s, i) in steps" :key="s.n" class="flex items-center gap-2 flex-1">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 transition-all duration-300"
              :class="stepClass(s.n)"
            >
              <svg v-if="step > s.n" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              <span v-else>{{ s.n }}</span>
            </div>
            <span class="text-sm font-bold" :class="step === s.n ? 'text-white' : step > s.n ? 'text-emerald-400' : 'text-slate-500'">{{ s.label }}</span>
            <div
              v-if="i < steps.length - 1"
              class="flex-1 h-0.5 mx-2 rounded-full transition-colors duration-300"
              :class="step > s.n ? 'bg-emerald-400' : 'bg-slate-700'"
            ></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Form content -->
    <div class="mx-auto px-4 py-8 transition-all duration-300" :class="step === 2 || step === 3 ? 'max-w-5xl' : 'max-w-2xl'">
      <!-- Error -->
      <div v-if="errorMsg" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl p-4 mb-6 no-print">
        <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm text-red-700 font-medium">{{ errorMsg }}</p>
      </div>

      <!-- STEP 1: Passengers -->
      <div v-if="step === 1" class="space-y-5 animate-fade-up">
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <div class="flex items-center justify-between mb-5">
            <h2 class="font-bold text-gray-900 text-sm flex items-center gap-2">
              <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              Pasajeros
            </h2>
            <button
              type="button"
              @click="addPassenger"
              class="flex items-center gap-1.5 text-xs text-blue-600 hover:text-blue-700 font-bold transition-colors"
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Añadir pasajero
            </button>
          </div>

          <div class="space-y-4">
            <div
              v-for="(pg, i) in passengers"
              :key="i"
              class="bg-gray-50 rounded-xl p-5 border border-gray-100"
            >
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-bold text-gray-700 flex items-center gap-2">
                  <div class="w-6 h-6 gradient-brand rounded-full flex items-center justify-center text-white text-xs font-black">{{ i + 1 }}</div>
                  Pasajero {{ i + 1 }}
                </h3>
                <button
                  v-if="passengers.length > 1"
                  type="button"
                  @click="removePassenger(i)"
                  class="text-red-400 hover:text-red-600 transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-semibold text-gray-500 mb-1.5">Nombre</label>
                  <input
                    v-model="pg.firstName"
                    placeholder="Yulieth"
                    class="w-full border-2 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none bg-white transition-all"
                    :class="submitted1 && !pg.firstName ? 'border-red-400' : 'border-gray-200'"
                  />
                  <p v-if="submitted1 && !pg.firstName" class="text-xs text-red-500 mt-1">Requerido</p>
                </div>
                <div>
                  <label class="block text-xs font-semibold text-gray-500 mb-1.5">Apellido</label>
                  <input
                    v-model="pg.lastName"
                    placeholder="Galarza"
                    class="w-full border-2 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none bg-white transition-all"
                    :class="submitted1 && !pg.lastName ? 'border-red-400' : 'border-gray-200'"
                  />
                  <p v-if="submitted1 && !pg.lastName" class="text-xs text-red-500 mt-1">Requerido</p>
                </div>
                <div class="sm:col-span-2">
                  <label class="block text-xs font-semibold text-gray-500 mb-1.5">N° documento</label>
                  <input
                    v-model="pg.documentNumber"
                    placeholder="A1234567"
                    class="w-full border-2 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none bg-white transition-all"
                    :class="submitted1 && !pg.documentNumber ? 'border-red-400' : 'border-gray-200'"
                  />
                  <p v-if="submitted1 && !pg.documentNumber" class="text-xs text-red-500 mt-1">Requerido</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Promo code -->
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <h2 class="font-bold text-gray-900 mb-4 flex items-center gap-2">
            <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
            </svg>
            ¿Tienes un código de descuento?
          </h2>
          <div class="flex gap-2">
            <input
              v-model="promoCode"
              placeholder="Ej: VERANO25"
              class="flex-1 border-2 border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none uppercase font-bold tracking-widest transition-all"
            />
            <button
              type="button"
              @click="validatePromo"
              :disabled="promoLoading || !promoCode"
              class="px-5 py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm font-bold rounded-xl transition-colors disabled:opacity-50"
            >
              <svg v-if="promoLoading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <span v-else>Aplicar</span>
            </button>
          </div>
          <div v-if="promoResult" class="mt-3 flex items-center gap-2 text-emerald-700 text-sm bg-emerald-50 border border-emerald-200 rounded-xl px-4 py-3 font-medium">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Código <strong>{{ promoResult.code }}</strong> &mdash; Ahorro: ${{ promoResult.discountAmount.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
          </div>
          <p v-if="promoError" class="mt-2 text-xs text-red-500 font-medium">{{ promoError }}</p>
        </div>

        <button
          type="button"
          @click="nextStep"
          class="w-full flex items-center justify-center gap-2 gradient-brand text-white font-bold py-4 rounded-2xl transition-all hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.02] active:scale-95"
        >
          Continuar al pago
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      <!-- STEP 2: Payment -->
      <div v-if="step === 2" class="animate-fade-up">
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          <!-- Left Column: Virtual Card & Summary -->
          <div class="lg:col-span-5 space-y-6 lg:sticky lg:top-24">
            <!-- Card Virtual -->
            <div class="perspective-1000 w-full aspect-[1.586/1] max-w-[400px] mx-auto lg:max-w-none">
              <div class="relative w-full h-full duration-700 transform-style-3d shadow-2xl rounded-2xl transition-all" :class="{ 'rotate-y-180': isCvvFocused }">
                <!-- Front of Card -->
                <div class="absolute inset-0 backface-hidden rounded-2xl p-6 flex flex-col justify-between text-white border border-white/10 shadow-lg overflow-hidden bg-gradient-to-br" :class="getCardBgClass(paymentForm.provider)">
                  <div class="absolute inset-0 bg-white/[0.03] backdrop-blur-[2px] pointer-events-none"></div>
                  <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white/12 via-transparent to-transparent pointer-events-none"></div>
                  
                  <div class="flex justify-between items-start z-10">
                    <div class="w-11 h-8 bg-gradient-to-br from-amber-200 via-yellow-400 to-amber-500 rounded-md relative shadow-sm overflow-hidden flex flex-col justify-between p-1.5 border border-amber-300/30">
                      <div class="w-full h-[1px] bg-black/10"></div>
                      <div class="w-full h-[1px] bg-black/10"></div>
                      <div class="w-full h-[1px] bg-black/10"></div>
                    </div>
                    <div class="h-8 flex items-center">
                      <svg v-if="paymentForm.provider === 'VISA'" class="h-6 text-white fill-current" viewBox="0 0 24 24">
                        <path d="M19.8 4L15.3 18.2H12.1L9.4 6.9C9.2 6.1 8.8 5.7 8.1 5.3C7 4.7 5.2 4.2 3.8 3.9L3.9 3.6H9.1C10.2 3.6 11.2 4.4 11.5 5.5L13.7 15.6L16.9 5.5C17.2 4.6 18 4 19 4H19.8ZM23.4 4L20.4 18.2H17.4L20.4 4H23.4ZM7.2 4.1L5.3 12.8C5.2 13 5 13.2 4.8 13.3C4.2 13.6 3.2 13.9 2 14.1L3.9 4H7.2Z" />
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'MASTERCARD'" class="h-7" viewBox="0 0 24 24">
                        <circle cx="8" cy="12" r="7" fill="#EB001B" fill-opacity="0.85"/>
                        <circle cx="16" cy="12" r="7" fill="#F79E1B" fill-opacity="0.85"/>
                        <path d="M12 12m-7 0a7 7 0 0 1 7-7a7 7 0 0 1 7 7a7 7 0 0 1-7 7a7 7 0 0 1-7-7Z" fill="#FF5F00" fill-opacity="0.5"/>
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'AMEX'" class="h-6 text-white fill-current" viewBox="0 0 24 24">
                        <path d="M2 3H22V21H2V3ZM6.5 15.5H8.7L9.5 13.2H11.5L12.3 15.5H14.5L11.5 7H9.5L6.5 15.5ZM10.5 9.7L11.2 11.7H9.8L10.5 9.7ZM15.5 15.5H17.5V11H19.5V9.2H17.5V7H15.5V15.5Z"/>
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'PAYPAL'" class="h-6 text-white fill-current" viewBox="0 0 24 24">
                        <path d="M20 7.5c0 3.7-2.6 6.8-6.1 7.4-.5.1-1 .1-1.5.1H9.8l-1.9 8.2c-.1.3-.3.4-.6.4H3.9c-.3 0-.5-.3-.4-.6L7.1 2.9c.1-.4.4-.7.8-.7h6c3.4 0 6.1 2.4 6.1 5.3zM16.4 8c0-2-1.4-3.4-3.5-3.4H8.7L7.5 11.1c-.1.3 0 .5.3.5h2c2.1 0 3.5-.8 4.2-2.3.4-.7.6-1.4.6-2.1z"/>
                      </svg>
                      <span v-else class="font-black italic text-lg tracking-tight select-none uppercase">{{ paymentForm.provider }}</span>
                    </div>
                  </div>

                  <div class="text-xl sm:text-2xl font-mono tracking-widest font-bold my-4 z-10 drop-shadow-md">
                    {{ cardDisplay || '•••• •••• •••• ••••' }}
                  </div>

                  <div class="flex justify-between items-end z-10">
                    <div class="flex flex-col max-w-[70%]">
                      <span class="text-[9px] uppercase tracking-wider text-white/50">Titular de Tarjeta</span>
                      <span class="text-xs sm:text-sm font-bold tracking-wide truncate uppercase">{{ paymentForm.cardholderName || 'Nombre Completo' }}</span>
                    </div>
                    <div class="flex flex-col">
                      <span class="text-[9px] uppercase tracking-wider text-white/50">Expira</span>
                      <span class="text-xs sm:text-sm font-mono font-bold">{{ paymentForm.expiry || 'MM/AA' }}</span>
                    </div>
                  </div>
                </div>

                <!-- Back of Card -->
                <div class="absolute inset-0 backface-hidden rotate-y-180 rounded-2xl py-6 flex flex-col justify-between text-white border border-white/10 shadow-lg overflow-hidden bg-gradient-to-br" :class="getCardBgClass(paymentForm.provider)">
                  <div class="w-full h-10 bg-black/80 mt-2"></div>
                  
                  <div class="px-6 flex flex-col gap-1 mt-2">
                    <div class="flex justify-end text-[9px] uppercase tracking-wider text-white/50">CVV / CVC</div>
                    <div class="w-full h-9 bg-white/20 rounded flex items-center justify-end px-3 font-mono font-bold text-black border border-white/10 relative overflow-hidden">
                      <div class="absolute left-0 top-0 bottom-0 w-[75%] bg-gradient-to-r from-gray-100 to-gray-200 opacity-90 flex items-center px-3 text-[9px] text-gray-500 font-sans italic select-none">Firma Autorizada</div>
                      <span class="z-10 text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">{{ paymentForm.cvv || '•••' }}</span>
                    </div>
                  </div>

                  <div class="px-6 flex justify-between items-center text-[8px] text-white/40">
                    <span>AeroCore Payments Inc.</span>
                    <span>Soporte: 1-800-AERO-CORE</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Reservation Summary -->
            <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
              <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Resumen de la reserva</p>
              
              <div class="space-y-2 max-h-32 overflow-y-auto pr-1">
                <div
                  v-for="(p, i) in passengers"
                  :key="i"
                  class="flex items-center gap-2.5 text-sm text-gray-700"
                >
                  <div class="w-5 h-5 bg-indigo-50 text-indigo-600 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <span class="truncate font-medium">{{ p.firstName }} {{ p.lastName }} &mdash; <span class="font-mono text-gray-400 text-xs">{{ p.documentNumber }}</span></span>
                </div>
              </div>

              <div class="border-t border-gray-100 pt-4 space-y-2">
                <div class="flex justify-between text-sm text-gray-500">
                  <span>Tarifa Base (x{{ passengers.length }})</span>
                  <span class="font-medium">${{ pricingBreakdown.subtotal.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </div>
                <div v-if="pricingBreakdown.discount > 0" class="flex justify-between text-sm text-emerald-600 font-bold bg-emerald-50/50 rounded-xl px-3 py-1.5 my-1.5 border border-emerald-100">
                  <span>Descuento ({{ promoResult?.code }})</span>
                  <span>-${{ pricingBreakdown.discount.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </div>
                <div class="flex justify-between text-sm text-gray-500">
                  <span>IVA (15%)</span>
                  <span class="font-medium">${{ pricingBreakdown.tax.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </div>
                <div class="flex justify-between text-base font-black text-gray-900 border-t border-dashed border-gray-200 pt-3 mt-2">
                  <span>Total a pagar</span>
                  <span class="text-xl text-indigo-600 font-extrabold">${{ pricingBreakdown.total.toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Column: Checkout Form -->
          <div class="lg:col-span-7 space-y-6">
            <div class="bg-white rounded-2xl border border-gray-100 shadow-md p-6 sm:p-8 space-y-6">
              <div class="flex items-center justify-between">
                <h2 class="font-black text-gray-900 text-lg flex items-center gap-2">
                  <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                  </svg>
                  Información de Pago
                </h2>
                <span class="text-xs text-gray-400 font-medium flex items-center gap-1.5">
                  <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> Conexión Segura
                </span>
              </div>

              <div>
                <label class="block text-xs font-bold text-gray-400 mb-3 uppercase tracking-wider">Selecciona tu método de pago</label>
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <label v-for="p in cardProviders" :key="p.value" class="cursor-pointer group">
                    <input type="radio" v-model="paymentForm.provider" :value="p.value" class="sr-only peer" />
                    <div class="border-2 border-gray-100 peer-checked:border-indigo-600 peer-checked:bg-indigo-50/50 rounded-xl p-3 text-center flex flex-col items-center justify-center gap-2 text-gray-500 peer-checked:text-indigo-700 transition-all duration-300 hover:border-gray-200 hover:shadow-sm group-hover:scale-[1.02] active:scale-[0.98]">
                      <div class="h-6 flex items-center justify-center">
                        <svg v-if="p.value === 'VISA'" class="h-5 fill-current text-indigo-600" viewBox="0 0 24 24">
                          <path d="M19.8 4L15.3 18.2H12.1L9.4 6.9C9.2 6.1 8.8 5.7 8.1 5.3C7 4.7 5.2 4.2 3.8 3.9L3.9 3.6H9.1C10.2 3.6 11.2 4.4 11.5 5.5L13.7 15.6L16.9 5.5C17.2 4.6 18 4 19 4H19.8ZM23.4 4L20.4 18.2H17.4L20.4 4H23.4ZM7.2 4.1L5.3 12.8C5.2 13 5 13.2 4.8 13.3C4.2 13.6 3.2 13.9 2 14.1L3.9 4H7.2Z" />
                        </svg>
                        <svg v-else-if="p.value === 'MASTERCARD'" class="h-6" viewBox="0 0 24 24">
                          <circle cx="8" cy="12" r="7" fill="#EB001B" fill-opacity="0.85"/>
                          <circle cx="16" cy="12" r="7" fill="#F79E1B" fill-opacity="0.85"/>
                          <path d="M12 12m-7 0a7 7 0 0 1 7-7a7 7 0 0 1 7 7a7 7 0 0 1-7 7a7 7 0 0 1-7-7Z" fill="#FF5F00" fill-opacity="0.5"/>
                        </svg>
                        <svg v-else-if="p.value === 'AMEX'" class="h-5 fill-current text-blue-600" viewBox="0 0 24 24">
                          <path d="M2 3H22V21H2V3ZM6.5 15.5H8.7L9.5 13.2H11.5L12.3 15.5H14.5L11.5 7H9.5L6.5 15.5ZM10.5 9.7L11.2 11.7H9.8L10.5 9.7ZM15.5 15.5H17.5V11H19.5V9.2H17.5V7H15.5V15.5Z"/>
                        </svg>
                        <svg v-else-if="p.value === 'PAYPAL'" class="h-5 fill-current text-sky-600" viewBox="0 0 24 24">
                          <path d="M20 7.5c0 3.7-2.6 6.8-6.1 7.4-.5.1-1 .1-1.5.1H9.8l-1.9 8.2c-.1.3-.3.4-.6.4H3.9c-.3 0-.5-.3-.4-.6L7.1 2.9c.1-.4.4-.7.8-.7h6c3.4 0 6.1 2.4 6.1 5.3zM16.4 8c0-2-1.4-3.4-3.5-3.4H8.7L7.5 11.1c-.1.3 0 .5.3.5h2c2.1 0 3.5-.8 4.2-2.3.4-.7.6-1.4.6-2.1z"/>
                        </svg>
                      </div>
                      <span class="text-[10px] font-bold tracking-wider uppercase">{{ p.label }}</span>
                    </div>
                  </label>
                </div>
              </div>

              <div class="space-y-4">
                <div>
                  <label class="block text-xs font-bold text-gray-400 mb-1.5 uppercase tracking-wider">Nombre en la tarjeta</label>
                  <input
                    v-model="paymentForm.cardholderName"
                    placeholder="YULIETH GALARZA"
                    class="w-full border-2 rounded-xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none uppercase font-bold tracking-wider transition-all duration-300"
                    :class="submitted2 && !paymentForm.cardholderName ? 'border-red-400 bg-red-50/10' : 'border-gray-200'"
                  />
                  <p v-if="submitted2 && !paymentForm.cardholderName" class="text-xs text-red-500 mt-1 font-medium flex items-center gap-1">
                    <span class="w-1 h-1 rounded-full bg-red-500"></span> Requerido
                  </p>
                </div>

                <div>
                  <label class="block text-xs font-bold text-gray-400 mb-1.5 uppercase tracking-wider">Número de tarjeta</label>
                  <div class="relative">
                    <input
                      placeholder="1234 5678 9012 3456"
                      :value="cardDisplay"
                      @input="onCardInput"
                      class="w-full border-2 rounded-xl pl-4 pr-10 py-3 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none font-mono tracking-widest transition-all duration-300"
                      :class="submitted2 && paymentForm.cardNumber.replace(/\s/g, '').length !== 16 ? 'border-red-400 bg-red-50/10' : 'border-gray-200'"
                    />
                    <div class="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 flex items-center">
                      <svg v-if="paymentForm.provider === 'VISA'" class="h-4 fill-current text-indigo-600" viewBox="0 0 24 24">
                        <path d="M19.8 4L15.3 18.2H12.1L9.4 6.9C9.2 6.1 8.8 5.7 8.1 5.3C7 4.7 5.2 4.2 3.8 3.9L3.9 3.6H9.1C10.2 3.6 11.2 4.4 11.5 5.5L13.7 15.6L16.9 5.5C17.2 4.6 18 4 19 4H19.8ZM23.4 4L20.4 18.2H17.4L20.4 4H23.4ZM7.2 4.1L5.3 12.8C5.2 13 5 13.2 4.8 13.3C4.2 13.6 3.2 13.9 2 14.1L3.9 4H7.2Z" />
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'MASTERCARD'" class="h-5" viewBox="0 0 24 24">
                        <circle cx="8" cy="12" r="7" fill="#EB001B" fill-opacity="0.85"/>
                        <circle cx="16" cy="12" r="7" fill="#F79E1B" fill-opacity="0.85"/>
                        <path d="M12 12m-7 0a7 7 0 0 1 7-7a7 7 0 0 1 7 7a7 7 0 0 1-7 7a7 7 0 0 1-7-7Z" fill="#FF5F00" fill-opacity="0.5"/>
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'AMEX'" class="h-4 fill-current text-blue-600" viewBox="0 0 24 24">
                        <path d="M2 3H22V21H2V3ZM6.5 15.5H8.7L9.5 13.2H11.5L12.3 15.5H14.5L11.5 7H9.5L6.5 15.5ZM10.5 9.7L11.2 11.7H9.8L10.5 9.7ZM15.5 15.5H17.5V11H19.5V9.2H17.5V7H15.5V15.5Z"/>
                      </svg>
                      <svg v-else-if="paymentForm.provider === 'PAYPAL'" class="h-4 fill-current text-sky-600" viewBox="0 0 24 24">
                        <path d="M20 7.5c0 3.7-2.6 6.8-6.1 7.4-.5.1-1 .1-1.5.1H9.8l-1.9 8.2c-.1.3-.3.4-.6.4H3.9c-.3 0-.5-.3-.4-.6L7.1 2.9c.1-.4.4-.7.8-.7h6c3.4 0 6.1 2.4 6.1 5.3zM16.4 8c0-2-1.4-3.4-3.5-3.4H8.7L7.5 11.1c-.1.3 0 .5.3.5h2c2.1 0 3.5-.8 4.2-2.3.4-.7.6-1.4.6-2.1z"/>
                      </svg>
                    </div>
                  </div>
                  <p v-if="submitted2 && paymentForm.cardNumber.replace(/\s/g, '').length !== 16" class="text-xs text-red-500 mt-1 font-medium flex items-center gap-1">
                    <span class="w-1 h-1 rounded-full bg-red-500"></span> Ingresa los 16 dígitos de tu tarjeta
                  </p>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-xs font-bold text-gray-400 mb-1.5 uppercase tracking-wider">Vencimiento</label>
                    <input
                      placeholder="MM/AA"
                      maxlength="5"
                      :value="paymentForm.expiry"
                      @input="onExpiryInput"
                      class="w-full border-2 rounded-xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none font-mono transition-all duration-300"
                      :class="submitted2 && paymentForm.expiry.replace(/\D/g, '').length !== 4 ? 'border-red-400 bg-red-50/10' : 'border-gray-200'"
                    />
                    <p v-if="submitted2 && paymentForm.expiry.replace(/\D/g, '').length !== 4" class="text-xs text-red-500 mt-1 font-medium flex items-center gap-1">
                      <span class="w-1 h-1 rounded-full bg-red-500"></span> Formato MM/AA
                    </p>
                  </div>
                  <div>
                    <label class="block text-xs font-bold text-gray-400 mb-1.5 uppercase tracking-wider">CVV</label>
                    <input
                      v-model="paymentForm.cvv"
                      type="password"
                      placeholder="•••"
                      maxlength="4"
                      @focus="isCvvFocused = true"
                      @blur="isCvvFocused = false"
                      class="w-full border-2 rounded-xl px-4 py-3 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition-all duration-300"
                      :class="submitted2 && (paymentForm.cvv.replace(/\D/g, '').length < 3 || paymentForm.cvv.replace(/\D/g, '').length > 4) ? 'border-red-400 bg-red-50/10' : 'border-gray-200'"
                    />
                    <p v-if="submitted2 && (paymentForm.cvv.replace(/\D/g, '').length < 3 || paymentForm.cvv.replace(/\D/g, '').length > 4)" class="text-xs text-red-500 mt-1 font-medium flex items-center gap-1">
                      <span class="w-1 h-1 rounded-full bg-red-500"></span> CVV inválido
                    </p>
                  </div>
                </div>
              </div>

              <div class="flex items-center gap-2.5 text-[11px] text-gray-400 pt-4 border-t border-gray-100">
                <svg class="w-4 h-4 text-emerald-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                <span>Transacción cifrada y protegida. Sus datos financieros están seguros.</span>
              </div>
            </div>

            <button
              type="button"
              @click="submitPayment"
              :disabled="payLoading"
              class="w-full flex items-center justify-center gap-2 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 disabled:opacity-60 text-white font-bold py-4 rounded-2xl transition-all hover:shadow-lg hover:shadow-emerald-500/25 hover:scale-[1.02] active:scale-95 disabled:hover:scale-100 shadow-md shadow-emerald-500/10"
            >
              <svg v-if="payLoading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
              {{ payLoading ? 'Procesando pago...' : 'Confirmar y pagar' }}
            </button>
          </div>
        </div>
      </div>

      <!-- STEP 3: Seat Selection -->
      <div v-if="step === 3" class="space-y-6 animate-fade-up">
        <div class="bg-white rounded-3xl shadow-xl border border-gray-100 p-6 sm:p-8">
          <h2 class="font-black text-gray-900 text-lg flex items-center gap-2 mb-6">
            <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
            </svg>
            Selección de Asientos
          </h2>

          <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            <!-- Left: Passengers selection -->
            <div class="lg:col-span-4 space-y-3">
              <p class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Pasajeros de la reserva</p>
              <button
                v-for="(pax, idx) in createdReservation?.passengers"
                :key="pax.id || idx"
                type="button"
                @click="selectPax(idx)"
                class="w-full flex items-center justify-between p-4 rounded-2xl border-2 text-left transition-all duration-200"
                :class="activePaxIdx === idx
                  ? 'border-indigo-600 bg-indigo-50/40 shadow-sm'
                  : 'border-gray-100 bg-white hover:border-gray-200'"
              >
                <div class="flex items-center gap-2.5 min-w-0">
                  <div class="w-8 h-8 rounded-full flex items-center justify-center font-bold text-xs"
                    :class="pax.seatNumber ? 'bg-emerald-500 text-white' : 'bg-gray-100 text-gray-500'">
                    <svg v-if="pax.seatNumber" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
                    </svg>
                    <span v-else>{{ idx + 1 }}</span>
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-bold text-gray-800 truncate">{{ pax.firstName }}</p>
                    <p class="text-xs text-gray-400 font-mono">{{ pax.documentNumber }}</p>
                  </div>
                </div>
                <div class="flex items-center gap-1.5 flex-shrink-0">
                  <span v-if="pax.seatNumber" class="font-mono font-black text-indigo-600 bg-indigo-50 px-2.5 py-1 rounded-lg text-sm border border-indigo-100">{{ pax.seatNumber }}</span>
                  <span v-else class="text-xs text-amber-500 font-bold bg-amber-50 border border-amber-100 px-2 py-0.5 rounded-lg">Pendiente</span>
                </div>
              </button>
            </div>

            <!-- Right: Interactive map -->
            <div class="lg:col-span-8 bg-slate-50 border border-slate-100 rounded-2xl p-6 flex flex-col items-center">
              <div v-if="activePaxIdx !== null && activePax" class="w-full text-center">
                <p class="text-xs font-bold text-slate-500 mb-4">
                  Eligiendo asiento para <strong class="text-indigo-600">{{ activePax.firstName }} {{ activePax.lastName }}</strong>
                  <span class="ml-1 text-[10px] px-2 py-0.5 rounded-md border" :class="classColor(getClassType(activePax.flightClassId))">
                    {{ classLabel(getClassType(activePax.flightClassId)) }}
                  </span>
                </p>

                <!-- Loading occupied seats -->
                <div v-if="seatLoading" class="flex items-center justify-center py-12 gap-2">
                  <svg class="w-5 h-5 animate-spin text-indigo-600" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span class="text-sm text-slate-400 font-medium">Cargando mapa de asientos...</span>
                </div>

                <div v-else-if="seatError" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-3 mb-4">
                  {{ seatError }}
                </div>

                <!-- Seat grid -->
                <div v-else-if="activeSeatGrid" class="flex flex-col items-center overflow-x-auto w-full max-w-md mx-auto">
                  <div class="flex items-center gap-1.5 text-xs text-slate-400 font-medium mb-5 uppercase tracking-wider bg-slate-100/50 px-3 py-1 rounded-full border border-slate-200/50">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                    </svg>
                    Frente del Avión
                  </div>

                  <!-- Column headers -->
                  <div class="flex items-center gap-1 mb-2 pl-9">
                    <template v-for="(col, ci) in activeSeatGrid.cols" :key="col">
                      <div v-if="Number(ci) === activeSeatGrid.aisleAfter + 1" class="w-6"></div>
                      <div class="w-9 text-center text-xs font-bold text-slate-400">{{ col }}</div>
                    </template>
                  </div>

                  <!-- Seat rows -->
                  <div class="max-h-[350px] overflow-y-auto w-full pr-1">
                    <div
                      v-for="row in activeSeatGrid.rows"
                      :key="row"
                      class="flex items-center gap-1 mb-1.5 justify-center"
                    >
                      <div class="w-8 text-center text-xs font-bold text-slate-400 flex-shrink-0">{{ row }}</div>

                      <template v-for="(col, ci) in activeSeatGrid.cols" :key="col">
                        <div v-if="Number(ci) === activeSeatGrid.aisleAfter + 1" class="w-6 flex items-center justify-center">
                          <div class="w-px h-6 bg-slate-200"></div>
                        </div>

                        <button
                          type="button"
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

                  <!-- Seat legends -->
                  <div class="flex justify-center gap-4 text-[10px] text-slate-500 mt-6 border-t border-slate-200/60 pt-4 w-full">
                    <span class="flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded bg-blue-500 inline-block border border-blue-600"></span> Tu asiento</span>
                    <span class="flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded bg-gray-200 inline-block border border-gray-200"></span> Ocupado</span>
                    <span class="flex items-center gap-1.5"><span class="w-3.5 h-3.5 rounded bg-white inline-block border border-slate-200"></span> Libre</span>
                  </div>
                </div>
              </div>

              <div class="text-slate-400 text-sm py-12" v-else>
                Selecciona un pasajero a la izquierda para empezar a elegir asiento.
              </div>
            </div>
          </div>
        </div>

        <button
          type="button"
          @click="finalizeBooking"
          :disabled="!allSeatsAssigned"
          class="w-full flex items-center justify-center gap-2 bg-gradient-to-r from-indigo-600 to-blue-700 hover:from-indigo-700 hover:to-blue-800 disabled:opacity-60 text-white font-bold py-4 rounded-2xl transition-all hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.02] active:scale-95 disabled:hover:scale-100 shadow-md"
        >
          Confirmar asientos y generar boletos
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      <!-- STEP 4: Success & Boarding Passes -->
      <div v-if="step === 4" class="space-y-6 animate-fade-up">
        <!-- Success Card (no-print) -->
        <div class="bg-white rounded-3xl shadow-xl p-8 border border-gray-100 text-center no-print success-info-card">
          <div class="relative inline-flex items-center justify-center w-20 h-20 mb-4">
            <div class="absolute inset-0 rounded-full bg-emerald-100 animate-pulse"></div>
            <div class="relative w-16 h-16 rounded-full bg-emerald-500 flex items-center justify-center shadow-lg shadow-emerald-500/30">
              <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>

          <h1 class="text-2xl font-black text-gray-900 tracking-tight mb-1">¡Compra finalizada con éxito!</h1>
          <p class="text-sm text-gray-500 mb-6">Tu pago ha sido procesado y tus asientos han sido reservados.</p>

          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <button
              type="button"
              @click="printTickets"
              class="flex items-center justify-center gap-2 bg-gradient-to-r from-blue-600 to-indigo-700 hover:from-blue-700 hover:to-indigo-800 text-white font-bold px-6 py-3.5 rounded-2xl shadow-lg shadow-indigo-500/20 transition-all hover:scale-[1.02] active:scale-95"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              Imprimir Boletos / Guardar PDF
            </button>
            <button
              type="button"
              @click="router.push('/')"
              class="bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold px-6 py-3.5 rounded-2xl transition-all active:scale-95"
            >
              Volver a inicio
            </button>
          </div>
        </div>

        <!-- Printable Area -->
        <div id="ticket-print-area" class="space-y-6">
          <h2 class="text-xs font-bold text-gray-400 uppercase tracking-wider px-2 no-print">Tus Pases de Abordar</h2>
          
          <div
            v-for="pax in createdReservation?.passengers"
            :key="pax.id"
            class="bg-white border border-gray-200 rounded-3xl overflow-hidden shadow-md flex flex-col md:flex-row ticket-card-print"
          >
            <!-- Left side of Boarding Pass: Main Ticket -->
            <div class="flex-1 p-6 relative">
              <div class="absolute right-4 top-4 opacity-5 pointer-events-none">
                <svg class="w-36 h-36" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </div>

              <!-- Ticket Header -->
              <div class="flex justify-between items-start border-b border-dashed border-gray-200 pb-4 mb-4">
                <div class="flex items-center gap-2">
                  <div class="w-8 h-8 rounded-lg gradient-brand flex items-center justify-center text-white">
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
                  <span class="font-mono font-black text-indigo-600 text-sm tracking-wider">{{ successData?.reservationCode }}</span>
                </div>
              </div>

              <!-- Flight details -->
              <div class="flex justify-between items-center mb-6">
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block">Origen</span>
                  <span class="text-3xl font-black text-gray-900 leading-none">{{ firstSeg?.originAirport?.iataCode ?? '---' }}</span>
                  <span class="text-xs text-gray-500 font-semibold block mt-0.5 max-w-[120px] truncate">{{ firstSeg?.originAirport?.city?.name ?? '' }}</span>
                </div>
                
                <div class="flex-1 flex flex-col items-center px-4">
                  <span class="text-[8px] text-gray-400 font-bold uppercase tracking-widest mb-1">{{ firstSeg?.airline?.name ?? 'AeroCore' }}</span>
                  <div class="w-full flex items-center gap-1">
                    <div class="flex-1 h-[2px] bg-slate-200"></div>
                    <svg class="w-4 h-4 text-slate-400 transform rotate-90" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2L2 12l10-2v12l10-10-10-2V2z" />
                    </svg>
                    <div class="flex-1 h-[2px] bg-slate-200"></div>
                  </div>
                  <span class="text-[9px] text-slate-400 font-mono mt-1">Vuelo {{ createdReservation?.flight?.flightNumber ?? 'AC01' }}</span>
                </div>

                <div class="text-right">
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block">Destino</span>
                  <span class="text-3xl font-black text-gray-900 leading-none">{{ lastSeg?.destinationAirport?.iataCode ?? '---' }}</span>
                  <span class="text-xs text-gray-500 font-semibold block mt-0.5 max-w-[120px] truncate">{{ lastSeg?.destinationAirport?.city?.name ?? '' }}</span>
                </div>
              </div>

              <!-- Info Grid -->
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 bg-slate-50 rounded-2xl p-4 border border-slate-100">
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Pasajero</span>
                  <span class="text-xs font-bold text-slate-800 block truncate">{{ pax.firstName }} {{ pax.lastName }}</span>
                  <span class="text-[9px] text-slate-400 font-mono block leading-none mt-0.5">{{ pax.documentNumber }}</span>
                </div>
                <div>
                  <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Fecha y Hora</span>
                  <span class="text-xs font-bold text-slate-800 block">{{ fmtDate(firstSeg?.departureDateTime, "d MMM yyyy, HH:mm") }}</span>
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

            <!-- Dotted Separator Line -->
            <div class="hidden md:flex flex-col items-center justify-between py-4 relative">
              <div class="w-4 h-4 bg-slate-50 rounded-full border-b border-gray-200 absolute -top-2 z-10"></div>
              <div class="w-[1px] h-full border-r-2 border-dashed border-gray-200"></div>
              <div class="w-4 h-4 bg-slate-50 rounded-full border-t border-gray-200 absolute -bottom-2 z-10"></div>
            </div>

            <!-- Right side of Boarding Pass: Stub -->
            <div class="bg-slate-50/50 p-6 flex flex-col justify-between items-center border-t md:border-t-0 md:border-l border-gray-100 min-w-[200px] text-center">
              <div class="w-full">
                <span class="text-[8px] text-gray-400 font-bold uppercase tracking-wider block mb-0.5">Talón de Embarque</span>
                <p class="text-xs font-black text-slate-800 truncate">{{ pax.firstName }} {{ pax.lastName }}</p>
                <p class="text-[9px] text-slate-400 font-mono leading-none">{{ firstSeg?.originAirport?.iataCode }} → {{ lastSeg?.destinationAirport?.iataCode }}</p>
              </div>

              <!-- QR Code -->
              <div class="my-4">
                <img
                  :src="'https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=RESERVA:' + successData?.reservationCode + '|PASAJERO:' + pax.firstName + '+' + pax.lastName + '|ASIENTO:' + (pax.seatNumber || 'N/A')"
                  class="w-24 h-24 border p-1 bg-white rounded-lg shadow-sm"
                  alt="QR Code"
                />
              </div>

              <div>
                <span class="text-[9px] text-gray-400 font-bold uppercase tracking-wider block leading-none">Asiento</span>
                <span class="text-2xl font-black text-indigo-600 font-mono leading-none">{{ pax.seatNumber || 'N/A' }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.perspective-1000 {
  perspective: 1000px;
}
.transform-style-3d {
  transform-style: preserve-3d;
}
.backface-hidden {
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}
.rotate-y-180 {
  transform: rotateY(180deg);
}

@media print {
  body {
    background: white !important;
    color: black !important;
  }
  header, footer, nav, button, .no-print, .success-info-card {
    display: none !important;
  }
  .print-only {
    display: block !important;
  }
  #ticket-print-area {
    display: block !important;
    position: absolute !important;
    left: 0 !important;
    top: 0 !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
    background: white !important;
  }
  .ticket-card-print {
    page-break-inside: avoid;
    break-inside: avoid;
    margin-bottom: 2rem;
    border: 2px solid #cbd5e1 !important;
    box-shadow: none !important;
  }
}
</style>

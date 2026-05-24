<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { reservationsService } from '../../services/reservations.service';
import { paymentsService } from '../../services/payments.service';
import { promotionsService } from '../../services/promotions.service';
import { invoicesService } from '../../services/invoices.service';
import type { PromotionValidation, Invoice } from '../../models/domain';

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
const step = ref<1 | 2>(1);
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

const createdReservation = ref<any | null>(null);

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
    }, 1200);
  } catch (err: any) {
    errorMsg.value = err?.response?.data?.error?.message || err?.message || 'Error al procesar el pago';
    payLoading.value = false;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
}
</script>

<template>
  <div class="bg-gradient-to-br from-slate-50 to-blue-50/30 min-h-screen">
    <!-- Success Screen -->
    <div v-if="successData" class="max-w-lg mx-auto px-4 py-16 animate-fade-up">
      <div class="bg-white rounded-3xl shadow-xl p-10 border border-gray-100 text-center">
        <!-- Success animation ring -->
        <div class="relative inline-flex items-center justify-center w-24 h-24 mb-6">
          <div class="absolute inset-0 rounded-full bg-emerald-100 animate-pulse"></div>
          <div class="relative w-20 h-20 rounded-full bg-emerald-500 flex items-center justify-center shadow-lg shadow-emerald-500/30">
            <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        </div>

        <h1 class="text-3xl font-black text-gray-900 tracking-tight mb-1">¡Pago exitoso!</h1>
        <p class="text-gray-500 mb-8">Tu reserva ha sido confirmada y procesada</p>

        <!-- Reservation summary card -->
        <div class="bg-gray-50 rounded-2xl border border-gray-200 divide-y divide-gray-100 text-left overflow-hidden mb-6">
          <div class="flex items-center justify-between px-5 py-4">
            <span class="text-sm text-gray-500 font-medium">Código de reserva</span>
            <span class="font-mono font-black text-blue-600 text-lg select-all tracking-wider">{{ successData.reservationCode }}</span>
          </div>
          <template v-if="successData.invoice">
            <div class="flex items-center justify-between px-5 py-3">
              <span class="text-sm text-gray-500">N° Factura</span>
              <span class="font-mono font-semibold text-gray-800">{{ successData.invoice.invoiceNumber }}</span>
            </div>
            <div class="flex items-center justify-between px-5 py-3">
              <span class="text-sm text-gray-500">Subtotal</span>
              <span class="text-sm font-semibold text-gray-700">${{ Number(successData.invoice.subtotal).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
            </div>
            <div class="flex items-center justify-between px-5 py-3">
              <span class="text-sm text-gray-500">IVA 15%</span>
              <span class="text-sm font-semibold text-gray-700">${{ Number(successData.invoice.taxAmount).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
            </div>
            <div class="flex items-center justify-between px-5 py-4 bg-blue-50">
              <span class="font-bold text-gray-800">Total pagado</span>
              <span class="text-2xl font-black text-blue-600">${{ Number(successData.invoice.total).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
            </div>
          </template>
          <div v-else class="flex items-center justify-between px-5 py-4 bg-blue-50">
            <span class="font-bold text-gray-800">Total pagado</span>
            <span class="text-2xl font-black text-blue-600">&mdash;</span>
          </div>
        </div>

        <p class="text-xs text-gray-400 mb-6">La factura fue generada automáticamente y está disponible en el detalle de tu reserva.</p>

        <button
          @click="router.push(`/my-trips/${successData.reservationId}`)"
          class="w-full gradient-brand text-white font-bold py-3.5 rounded-2xl transition-all hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.02] active:scale-95"
        >
          Ver mi reserva
        </button>
      </div>
    </div>

    <!-- Step Flow -->
    <template v-else>
      <!-- Header -->
      <div class="bg-gradient-to-r from-slate-900 via-blue-950 to-indigo-900 text-white px-4 py-8">
        <div class="max-w-2xl mx-auto">
          <button
            @click="goBack"
            class="flex items-center gap-2 text-slate-300 hover:text-white text-sm font-medium transition-colors mb-4"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            {{ step === 2 ? 'Volver a datos de pasajeros' : 'Volver' }}
          </button>

          <h1 class="text-2xl font-extrabold tracking-tight mb-1">
            {{ step === 1 ? 'Datos de pasajeros' : 'Información de pago' }}
          </h1>
          <p class="text-slate-300 text-sm">
            {{ step === 1 ? 'Ingresa los datos de todos los pasajeros' : 'Completa los datos de tu tarjeta' }}
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
      <div class="mx-auto px-4 py-8 transition-all duration-300" :class="step === 2 ? 'max-w-5xl' : 'max-w-2xl'">
        <!-- Error -->
        <div v-if="errorMsg" class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-2xl p-4 mb-6">
          <svg class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm text-red-700 font-medium">{{ errorMsg }}</p>
        </div>

        <!-- STEP 1: Passengers -->
        <div v-if="step === 1" class="space-y-5 animate-fade-up">
          <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <div class="flex items-center justify-between mb-5">
              <h2 class="font-bold text-gray-900 flex items-center gap-2">
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
            
            <!-- Left Column: Virtual Card & Summary (5 columns) -->
            <div class="lg:col-span-5 space-y-6 lg:sticky lg:top-24">
              <!-- Card Virtual -->
              <div class="perspective-1000 w-full aspect-[1.586/1] max-w-[400px] mx-auto lg:max-w-none">
                <div class="relative w-full h-full duration-700 transform-style-3d shadow-2xl rounded-2xl transition-all" :class="{ 'rotate-y-180': isCvvFocused }">
                  <!-- Front of Card -->
                  <div class="absolute inset-0 backface-hidden rounded-2xl p-6 flex flex-col justify-between text-white border border-white/10 shadow-lg overflow-hidden bg-gradient-to-br" :class="getCardBgClass(paymentForm.provider)">
                    <!-- Card design overlay / glass effect -->
                    <div class="absolute inset-0 bg-white/[0.03] backdrop-blur-[2px] pointer-events-none"></div>
                    <!-- Shiny grid overlay -->
                    <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white/12 via-transparent to-transparent pointer-events-none"></div>
                    
                    <!-- Card Header: Chip and Provider Logo -->
                    <div class="flex justify-between items-start z-10">
                      <!-- Chip -->
                      <div class="w-11 h-8 bg-gradient-to-br from-amber-200 via-yellow-400 to-amber-500 rounded-md relative shadow-sm overflow-hidden flex flex-col justify-between p-1.5 border border-amber-300/30">
                        <div class="w-full h-[1px] bg-black/10"></div>
                        <div class="w-full h-[1px] bg-black/10"></div>
                        <div class="w-full h-[1px] bg-black/10"></div>
                      </div>
                      <!-- Logo -->
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

                    <!-- Card Number -->
                    <div class="text-xl sm:text-2xl font-mono tracking-widest font-bold my-4 z-10 drop-shadow-md">
                      {{ cardDisplay || '•••• •••• •••• ••••' }}
                    </div>

                    <!-- Card Footer: Cardholder and Expiry -->
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
                    <!-- Magnetic Stripe -->
                    <div class="w-full h-10 bg-black/80 mt-2"></div>
                    
                    <!-- CVV Area -->
                    <div class="px-6 flex flex-col gap-1 mt-2">
                      <div class="flex justify-end text-[9px] uppercase tracking-wider text-white/50">CVV / CVC</div>
                      <div class="w-full h-9 bg-white/20 rounded flex items-center justify-end px-3 font-mono font-bold text-black border border-white/10 relative overflow-hidden">
                        <div class="absolute left-0 top-0 bottom-0 w-[75%] bg-gradient-to-r from-gray-100 to-gray-200 opacity-90 flex items-center px-3 text-[9px] text-gray-500 font-sans italic select-none">Firma Autorizada</div>
                        <span class="z-10 text-white drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">{{ paymentForm.cvv || '•••' }}</span>
                      </div>
                    </div>

                    <!-- Back Footer info -->
                    <div class="px-6 flex justify-between items-center text-[8px] text-white/40">
                      <span>AeroCore Payments Inc.</span>
                      <span>Soporte: 1-800-AERO-CORE</span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Reservation Summary & Details -->
              <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
                <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Resumen de la reserva</p>
                
                <!-- Passengers list -->
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

                <!-- Price Breakdown -->
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

            <!-- Right Column: Checkout Form (7 columns) -->
            <div class="lg:col-span-7 space-y-6">
              <!-- Payment form -->
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

                <!-- Provider Selector Premium -->
                <div>
                  <label class="block text-xs font-bold text-gray-400 mb-3 uppercase tracking-wider">Selecciona tu método de pago</label>
                  <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <label v-for="p in cardProviders" :key="p.value" class="cursor-pointer group">
                      <input type="radio" v-model="paymentForm.provider" :value="p.value" class="sr-only peer" />
                      <div class="border-2 border-gray-100 peer-checked:border-indigo-600 peer-checked:bg-indigo-50/50 rounded-xl p-3 text-center flex flex-col items-center justify-center gap-2 text-gray-500 peer-checked:text-indigo-700 transition-all duration-300 hover:border-gray-200 hover:shadow-sm group-hover:scale-[1.02] active:scale-[0.98]">
                        <!-- SVG icons -->
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

                <!-- Input Fields -->
                <div class="space-y-4">
                  <!-- Name on Card -->
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

                  <!-- Card Number -->
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
                      <!-- Mini Logo inside input -->
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

                  <!-- Expiry and CVV (Grid) -->
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

                <!-- Security details -->
                <div class="flex items-center gap-2.5 text-[11px] text-gray-400 pt-4 border-t border-gray-100">
                  <svg class="w-4 h-4 text-emerald-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                  <span>Transacción cifrada y protegida. Sus datos financieros están seguros.</span>
                </div>
              </div>

              <!-- Action buttons -->
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
      </div>
    </template>
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
</style>

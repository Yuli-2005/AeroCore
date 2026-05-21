<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  reservationId: string;
  flightClassId: string;
  firstName: string;
  lastName: string;
  documentNumber: string;
  seatNumber?: string;
  reservation?: { reservationCode: string };
  flightClass?: { cabinClass: string; flight?: { originAirportIata: string; destinationAirportIata: string } };
};

const items = ref<Row[]>([]);
const reservations = ref<any[]>([]);
const flightClasses = ref<any[]>([]);

const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const errorMsg = ref('');

const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);

const columns: TableColumn[] = [
  { key: 'reservation', label: 'Reserva', render: (r: Row) => r.reservation?.reservationCode || r.reservationId },
  { key: 'passenger', label: 'Pasajero', render: (r: Row) => `${r.firstName} ${r.lastName}` },
  { key: 'documentNumber', label: 'Documento' },
  { key: 'seatNumber', label: 'Asiento', render: (r: Row) => r.seatNumber || 'Sin asignar' },
  { key: 'flightClass', label: 'Clase', render: (r: Row) => r.flightClass ? `${r.flightClass.cabinClass} (${r.flightClass.flight?.originAirportIata}-${r.flightClass.flight?.destinationAirportIata})` : r.flightClassId },
];

const form = ref({
  reservationId: '',
  flightClassId: '',
  firstName: '',
  lastName: '',
  documentNumber: '',
  seatNumber: '',
});

onMounted(() => {
  load();
  loadCatalogs();
});

async function loadCatalogs() {
  try {
    const [res, fc] = await Promise.all([
      adminService.getReservations(),
      adminService.getFlightClasses(),
    ]);
    reservations.value = res;
    flightClasses.value = fc;
  } catch (err) {
    console.error('Error cargando catálogos:', err);
  }
}

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getReservationPassengers();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  errorMsg.value = '';
  form.value = {
    reservationId: '',
    flightClassId: '',
    firstName: '',
    lastName: '',
    documentNumber: '',
    seatNumber: '',
  };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row;
  errorMsg.value = '';
  form.value = {
    reservationId: row.reservationId || '',
    flightClassId: row.flightClassId || '',
    firstName: row.firstName || '',
    lastName: row.lastName || '',
    documentNumber: row.documentNumber || '',
    seatNumber: row.seatNumber || '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  const { reservationId, flightClassId, firstName, lastName, documentNumber, seatNumber } = form.value;
  if (!reservationId || !flightClassId || !firstName || !lastName || !documentNumber) return;

  errorMsg.value = '';
  isSaving.value = true;

  const body = {
    reservationId,
    flightClassId,
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    documentNumber: documentNumber.trim(),
    seatNumber: seatNumber.trim() || undefined,
  };

  try {
    if (editItem.value?.id) {
      await adminService.updateReservationPassenger(editItem.value.id, body);
    } else {
      await adminService.createReservationPassenger(body);
    }
    modalOpen.value = false;
    await load();
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al guardar el pasajero';
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteReservationPassenger(id);
    await load();
  } catch {
    //
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable
      title="Gestión de Pasajeros"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['firstName', 'lastName', 'documentNumber']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Pasajero' : 'Nuevo Pasajero'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
        {{ errorMsg }}
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div class="col-span-2">
          <label class="block text-xs font-semibold text-gray-500 mb-1">Reserva *</label>
          <select
            v-model="form.reservationId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione la reserva</option>
            <option v-for="r in reservations" :key="r.id" :value="r.id">
              {{ r.reservationCode }}
            </option>
          </select>
        </div>

        <div class="col-span-2">
          <label class="block text-xs font-semibold text-gray-500 mb-1">Clase de Vuelo *</label>
          <select
            v-model="form.flightClassId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione la clase</option>
            <option v-for="fc in flightClasses" :key="fc.id" :value="fc.id">
              {{ fc.cabinClass }} (Vuelo: {{ fc.flight?.originAirportIata || '?' }} → {{ fc.flight?.destinationAirportIata || '?' }})
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
          <input
            v-model="form.firstName"
            required
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Apellido *</label>
          <input
            v-model="form.lastName"
            required
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Documento *</label>
          <input
            v-model="form.documentNumber"
            required
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Número de Asiento</label>
          <input
            v-model="form.seatNumber"
            placeholder="Ej: 14A"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase"
          />
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

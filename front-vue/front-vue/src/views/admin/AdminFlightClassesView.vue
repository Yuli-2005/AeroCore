<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  flightId: string;
  cabinClass: string;
  availableSeats: number;
  basePrice: number;
  flight?: { originAirportIata: string; destinationAirportIata: string; departureDate: string };
};

const items = ref<Row[]>([]);
const flights = ref<any[]>([]);

const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const errorMsg = ref('');

const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);

const CABIN_CLASSES: Record<string, string> = {
  ECONOMY: 'Turista (Economy)',
  PREMIUM_ECONOMY: 'Premium Economy',
  BUSINESS: 'Ejecutiva (Business)',
  FIRST: 'Primera Clase',
};

const columns: TableColumn[] = [
  { key: 'flight', label: 'Vuelo', render: (r: Row) => r.flight ? `${r.flight.originAirportIata}-${r.flight.destinationAirportIata} (${new Date(r.flight.departureDate).toLocaleDateString('es-EC')})` : r.flightId },
  { key: 'cabinClass', label: 'Clase', render: (r: Row) => CABIN_CLASSES[r.cabinClass] ?? r.cabinClass },
  { key: 'availableSeats', label: 'Asientos Disponibles' },
  { key: 'basePrice', label: 'Precio Base', render: (r: Row) => `$${Number(r.basePrice).toFixed(2)}` },
];

const form = ref({
  flightId: '',
  cabinClass: 'ECONOMY',
  availableSeats: 100,
  basePrice: 0,
});

onMounted(() => {
  load();
  loadCatalogs();
});

async function loadCatalogs() {
  try {
    flights.value = await adminService.getFlights();
  } catch (err) {
    console.error('Error cargando vuelos:', err);
  }
}

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getFlightClasses();
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
    flightId: '',
    cabinClass: 'ECONOMY',
    availableSeats: 100,
    basePrice: 0,
  };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row;
  errorMsg.value = '';
  form.value = {
    flightId: row.flightId || '',
    cabinClass: row.cabinClass || 'ECONOMY',
    availableSeats: row.availableSeats || 0,
    basePrice: Number(row.basePrice) || 0,
  };
  modalOpen.value = true;
}

async function onSubmit() {
  const { flightId, cabinClass, availableSeats, basePrice } = form.value;
  if (!flightId || !cabinClass) return;

  errorMsg.value = '';
  isSaving.value = true;

  const body = {
    flightId,
    cabinClass,
    availableSeats: Number(availableSeats),
    basePrice: Number(basePrice),
  };

  try {
    if (editItem.value?.id) {
      await adminService.updateFlightClass(editItem.value.id, body);
    } else {
      await adminService.createFlightClass(body);
    }
    modalOpen.value = false;
    await load();
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al guardar la clase de vuelo';
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteFlightClass(id);
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
      title="Gestión de Clases de Vuelo"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['cabinClass']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Clase de Vuelo' : 'Nueva Clase de Vuelo'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
        {{ errorMsg }}
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Vuelo *</label>
          <select
            v-model="form.flightId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione el vuelo</option>
            <option v-for="f in flights" :key="f.id" :value="f.id">
              {{ f.originAirportIata }} → {{ f.destinationAirportIata }} ({{ new Date(f.departureDate).toLocaleDateString('es-EC') }})
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Clase de Cabina *</label>
          <select
            v-model="form.cabinClass"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="ECONOMY">Turista (Economy)</option>
            <option value="PREMIUM_ECONOMY">Premium Economy</option>
            <option value="BUSINESS">Ejecutiva (Business)</option>
            <option value="FIRST">Primera Clase</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Asientos Disponibles *</label>
          <input
            v-model="form.availableSeats"
            type="number"
            required
            min="0"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Precio Base (USD) *</label>
          <input
            v-model="form.basePrice"
            type="number"
            required
            min="0"
            step="0.01"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  originAirportIata: string;
  destinationAirportIata: string;
  departureDate: string;
  status: string;
  flightNumber?: string;
  airline?: { id: string; name: string; iataCode: string };
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const errorMsg = ref('');

const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);

const STATUS_LABELS: Record<string, string> = {
  SCHEDULED: 'Programado',
  DELAYED: 'Retrasado',
  CANCELLED: 'Cancelado',
  COMPLETED: 'Completado',
};

const columns: TableColumn[] = [
  { key: 'route', label: 'Ruta', render: (r: Row) => `${r.originAirportIata ?? '?'} &rarr; ${r.destinationAirportIata ?? '?'}` },
  { key: 'airline', label: 'Aerolínea', render: (r: Row) => r.airline ? `${r.airline.name} (${r.airline.iataCode})` : '—' },
  { key: 'flightNumber', label: 'N° Vuelo', render: (r: Row) => r.flightNumber ?? '—' },
  { key: 'departureDate', label: 'Fecha', render: (r: Row) => r.departureDate ? new Date(r.departureDate).toLocaleDateString('es-EC') : '—' },
  { key: 'status', label: 'Estado', render: (r: Row) => STATUS_LABELS[r.status] ?? r.status },
];

const form = ref({
  originAirportIata: '',
  destinationAirportIata: '',
  departureDate: '',
  status: 'SCHEDULED',
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getFlights();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

function toDateInput(iso: string) {
  return iso ? iso.slice(0, 10) : '';
}

function openAdd() {
  editItem.value = null;
  errorMsg.value = '';
  form.value = {
    originAirportIata: '',
    destinationAirportIata: '',
    departureDate: '',
    status: 'SCHEDULED',
  };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row;
  errorMsg.value = '';
  form.value = {
    originAirportIata: row.originAirportIata || '',
    destinationAirportIata: row.destinationAirportIata || '',
    departureDate: toDateInput(row.departureDate),
    status: row.status || 'SCHEDULED',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  const origin = form.value.originAirportIata.trim().toUpperCase();
  const dest = form.value.destinationAirportIata.trim().toUpperCase();

  if (!origin || !dest || !form.value.departureDate) return;

  if (origin === dest) {
    errorMsg.value = 'Origen y destino no pueden ser el mismo aeropuerto.';
    return;
  }

  errorMsg.value = '';
  isSaving.value = true;

  const body = {
    originAirportIata: origin,
    destinationAirportIata: dest,
    departureDate: form.value.departureDate,
    status: form.value.status,
  };

  try {
    if (editItem.value?.id) {
      await adminService.updateFlight(editItem.value.id, body);
    } else {
      await adminService.createFlight(body);
    }
    modalOpen.value = false;
    await load();
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al guardar el vuelo';
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteFlight(id);
    await load();
  } catch {
    // Manejo de error
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable
      title="Gestión de Vuelos"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['originAirportIata', 'destinationAirportIata', 'status', 'flightNumber']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Vuelo' : 'Nuevo Vuelo'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
        {{ errorMsg }}
      </div>

      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Origen IATA *</label>
        <input
          v-model="form.originAirportIata"
          maxlength="3"
          placeholder="Ej: UIO"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase font-semibold"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Destino IATA *</label>
        <input
          v-model="form.destinationAirportIata"
          maxlength="3"
          placeholder="Ej: BOG"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase font-semibold"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Fecha de Salida *</label>
        <input
          v-model="form.departureDate"
          type="date"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Estado</label>
        <select
          v-model="form.status"
          class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        >
          <option value="SCHEDULED">Programado</option>
          <option value="DELAYED">Retrasado</option>
          <option value="CANCELLED">Cancelado</option>
          <option value="COMPLETED">Completado</option>
        </select>
      </div>
    </AdminFormModal>
  </div>
</template>

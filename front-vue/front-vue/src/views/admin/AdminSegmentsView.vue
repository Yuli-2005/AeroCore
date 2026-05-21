<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  segmentNumber: string;
  originAirportId: string;
  destinationAirportId: string;
  departureDateTime: string;
  arrivalDateTime: string;
  airlineId: string;
  aircraftId?: string;
  estimatedDuration: number;
  flightId?: string;
  flight?: { originAirportIata: string; destinationAirportIata: string; departureDate: string };
  originAirport?: { iataCode: string };
  destinationAirport?: { iataCode: string };
  airline?: { name: string; iataCode: string };
};

const items = ref<Row[]>([]);
const flights = ref<any[]>([]);
const airports = ref<any[]>([]);
const airlines = ref<any[]>([]);
const aircraft = ref<any[]>([]);

const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const errorMsg = ref('');

const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);

const columns: TableColumn[] = [
  { key: 'segmentNumber', label: 'N° Segmento' },
  { key: 'route', label: 'Ruta', render: (r: Row) => `${r.originAirport?.iataCode ?? '?'} → ${r.destinationAirport?.iataCode ?? '?'}` },
  { key: 'departure', label: 'Salida', render: (r: Row) => new Date(r.departureDateTime).toLocaleString('es-EC') },
  { key: 'arrival', label: 'Llegada', render: (r: Row) => new Date(r.arrivalDateTime).toLocaleString('es-EC') },
  { key: 'airline', label: 'Aerolínea', render: (r: Row) => r.airline ? `${r.airline.name} (${r.airline.iataCode})` : '—' },
  { key: 'flight', label: 'Vuelo', render: (r: Row) => r.flightId ? `${r.flight?.originAirportIata}-${r.flight?.destinationAirportIata}` : 'Sin Vuelo' },
];

const form = ref({
  segmentNumber: '',
  originAirportId: '',
  destinationAirportId: '',
  departureDateTime: '',
  arrivalDateTime: '',
  airlineId: '',
  aircraftId: '',
  estimatedDuration: 0,
  flightId: '',
});

onMounted(() => {
  load();
  loadCatalogs();
});

async function loadCatalogs() {
  try {
    const [fl, airp, airl, airc] = await Promise.all([
      adminService.getFlights(),
      adminService.getAirports(),
      adminService.getAirlines(),
      adminService.getAircraft(),
    ]);
    flights.value = fl;
    airports.value = airp;
    airlines.value = airl;
    aircraft.value = airc;
  } catch (err) {
    console.error('Error cargando catálogos:', err);
  }
}

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getSegments();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

function toDateTimeInput(iso: string) {
  if (!iso) return '';
  const d = new Date(iso);
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
}

function openAdd() {
  editItem.value = null;
  errorMsg.value = '';
  form.value = {
    segmentNumber: '',
    originAirportId: '',
    destinationAirportId: '',
    departureDateTime: '',
    arrivalDateTime: '',
    airlineId: '',
    aircraftId: '',
    estimatedDuration: 0,
    flightId: '',
  };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row;
  errorMsg.value = '';
  form.value = {
    segmentNumber: row.segmentNumber || '',
    originAirportId: row.originAirportId || '',
    destinationAirportId: row.destinationAirportId || '',
    departureDateTime: toDateTimeInput(row.departureDateTime),
    arrivalDateTime: toDateTimeInput(row.arrivalDateTime),
    airlineId: row.airlineId || '',
    aircraftId: row.aircraftId || '',
    estimatedDuration: row.estimatedDuration || 0,
    flightId: row.flightId || '',
  };
  modalOpen.value = true;
}

function calculateDuration() {
  if (form.value.departureDateTime && form.value.arrivalDateTime) {
    const start = new Date(form.value.departureDateTime).getTime();
    const end = new Date(form.value.arrivalDateTime).getTime();
    if (end > start) {
      form.value.estimatedDuration = Math.floor((end - start) / 60000); // en minutos
    }
  }
}

async function onSubmit() {
  const { segmentNumber, originAirportId, destinationAirportId, departureDateTime, arrivalDateTime, airlineId } = form.value;
  if (!segmentNumber || !originAirportId || !destinationAirportId || !departureDateTime || !arrivalDateTime || !airlineId) return;

  if (originAirportId === destinationAirportId) {
    errorMsg.value = 'Origen y destino no pueden ser el mismo aeropuerto.';
    return;
  }

  errorMsg.value = '';
  isSaving.value = true;

  const body = {
    segmentNumber: segmentNumber.trim(),
    originAirportId,
    destinationAirportId,
    departureDateTime: new Date(departureDateTime).toISOString(),
    arrivalDateTime: new Date(arrivalDateTime).toISOString(),
    airlineId,
    aircraftId: form.value.aircraftId || undefined,
    estimatedDuration: Number(form.value.estimatedDuration),
    flightId: form.value.flightId || undefined,
  };

  try {
    if (editItem.value?.id) {
      await adminService.updateSegment(editItem.value.id, body);
    } else {
      await adminService.createSegment(body);
    }
    modalOpen.value = false;
    await load();
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al guardar el segmento';
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteSegment(id);
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
      title="Gestión de Segmentos"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['segmentNumber']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Segmento' : 'Nuevo Segmento'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
        {{ errorMsg }}
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">N° Segmento *</label>
          <input
            v-model="form.segmentNumber"
            placeholder="Ej: AV101"
            required
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase font-semibold"
          />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Vuelo (Opcional)</label>
          <select
            v-model="form.flightId"
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="">Sin asociar</option>
            <option v-for="f in flights" :key="f.id" :value="f.id">
              {{ f.originAirportIata }} → {{ f.destinationAirportIata }} ({{ new Date(f.departureDate).toLocaleDateString('es-EC') }})
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Origen *</label>
          <select
            v-model="form.originAirportId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione aeropuerto</option>
            <option v-for="a in airports" :key="a.id" :value="a.id">{{ a.name }} ({{ a.iataCode }})</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Destino *</label>
          <select
            v-model="form.destinationAirportId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione aeropuerto</option>
            <option v-for="a in airports" :key="a.id" :value="a.id">{{ a.name }} ({{ a.iataCode }})</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Salida *</label>
          <input
            v-model="form.departureDateTime"
            type="datetime-local"
            required
            @change="calculateDuration"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Llegada *</label>
          <input
            v-model="form.arrivalDateTime"
            type="datetime-local"
            required
            @change="calculateDuration"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Aerolínea *</label>
          <select
            v-model="form.airlineId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione aerolínea</option>
            <option v-for="a in airlines" :key="a.id" :value="a.id">{{ a.name }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Aeronave (Opcional)</label>
          <select
            v-model="form.aircraftId"
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="">Sin asociar</option>
            <option v-for="a in aircraft" :key="a.id" :value="a.id">{{ a.modelName }} ({{ a.registration }})</option>
          </select>
        </div>
        
        <div class="col-span-2">
          <label class="block text-xs font-semibold text-gray-500 mb-1">Duración (minutos) *</label>
          <input
            v-model="form.estimatedDuration"
            type="number"
            required
            min="0"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

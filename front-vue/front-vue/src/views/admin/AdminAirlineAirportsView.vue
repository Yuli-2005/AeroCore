<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  airlineId: string;
  airportId: string;
  airline?: { name: string; iataCode: string };
  airport?: { name: string; iataCode: string };
};

const items = ref<Row[]>([]);
const airlines = ref<any[]>([]);
const airports = ref<any[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const modalOpen = ref(false);
const errorMsg = ref('');
const form = ref({ airlineId: '', airportId: '' });

const columns: TableColumn[] = [
  { key: 'airline', label: 'Aerolínea', render: (r: Row) => r.airline ? `${r.airline.iataCode} — ${r.airline.name}` : r.airlineId },
  { key: 'airport', label: 'Aeropuerto', render: (r: Row) => r.airport ? `${r.airport.iataCode} — ${r.airport.name}` : r.airportId },
];

onMounted(async () => {
  load();
  try {
    const [al, ap] = await Promise.all([adminService.getAirlines(), adminService.getAirports()]);
    airlines.value = al; airports.value = ap;
  } catch { }
});

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getAirlineAirports(); } catch { items.value = []; } finally { isLoading.value = false; }
}

function openAdd() {
  errorMsg.value = '';
  form.value = { airlineId: '', airportId: '' };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.airlineId || !form.value.airportId) return;
  isSaving.value = true; errorMsg.value = '';
  try {
    await adminService.createAirlineAirport({ airlineId: form.value.airlineId, airportId: form.value.airportId });
    modalOpen.value = false; await load();
  } catch (e: any) { errorMsg.value = e?.message || 'Error al guardar'; } finally { isSaving.value = false; }
}

async function onDelete(row: any) {
  isDeleting.value = true;
  try { await adminService.deleteAirlineAirport(row.airlineId, row.airportId); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Aeropuertos por Aerolínea" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="[]" :show-edit="false" @add="openAdd" @delete="(id) => onDelete(items.find(i => i.airlineId + i.airportId === id) ?? { airlineId: '', airportId: id })" />
    <AdminFormModal title="Agregar Aeropuerto a Aerolínea" :open="modalOpen" :is-loading="isSaving"
      @close="modalOpen = false" @submit="onSubmit">
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">{{ errorMsg }}</div>
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Aerolínea *</label>
          <select v-model="form.airlineId" required class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
            <option value="" disabled>Seleccione aerolínea</option>
            <option v-for="a in airlines" :key="a.id" :value="a.id">{{ a.iataCode }} — {{ a.name }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Aeropuerto *</label>
          <select v-model="form.airportId" required class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
            <option value="" disabled>Seleccione aeropuerto</option>
            <option v-for="a in airports" :key="a.id" :value="a.id">{{ a.iataCode }} — {{ a.name }}</option>
          </select>
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

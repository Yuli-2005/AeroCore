<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';
import type { Aircraft, Airline } from '../../models/domain';

const items = ref<Aircraft[]>([]);
const airlines = ref<Airline[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);

const modalOpen = ref(false);
const editItem = ref<Partial<Aircraft> | null>(null);

const columns: TableColumn[] = [
  { key: 'modelName', label: 'Modelo' },
  { key: 'registration', label: 'Matrícula', renderHtml: (r: Aircraft) => `<span class="font-mono font-bold text-blue-600">${r.registration}</span>` },
  { key: 'airline', label: 'Aerolínea', render: (row: Aircraft) => row.airline?.name || '—' },
];

const form = ref({
  modelName: '',
  registration: '',
  airlineId: '',
  hasWifi: false,
  hasUsb: false,
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    const [aircraftData, airlinesData] = await Promise.all([
      adminService.getAircraft(),
      adminService.getAirlines(),
    ]);
    items.value = aircraftData;
    airlines.value = airlinesData;
  } catch {
    items.value = [];
    airlines.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  form.value = {
    modelName: '',
    registration: '',
    airlineId: airlines.value[0]?.id || '',
    hasWifi: false,
    hasUsb: false,
  };
  modalOpen.value = true;
}

function openEdit(row: Aircraft) {
  editItem.value = row;
  form.value = {
    modelName: row.modelName || '',
    registration: row.registration || '',
    airlineId: row.airlineId || '',
    hasWifi: !!row.hasWifi,
    hasUsb: !!row.hasUsb,
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.modelName.trim() || !form.value.registration.trim() || !form.value.airlineId) return;
  isSaving.value = true;
  try {
    if (editItem.value?.id) {
      await adminService.updateAircraft(editItem.value.id, form.value);
    } else {
      await adminService.createAircraft(form.value);
    }
    modalOpen.value = false;
    await load();
  } catch {
    // Manejo de error
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteAircraft(id);
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
      title="Gestión de Aviones"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['modelName', 'registration']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Avión' : 'Agregar Avión'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Modelo de Avión *</label>
        <input
          v-model="form.modelName"
          placeholder="Ej: Airbus A320neo"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Matrícula *</label>
        <input
          v-model="form.registration"
          placeholder="Ej: HC-CNA"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase font-semibold"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Aerolínea *</label>
        <select
          v-model="form.airlineId"
          required
          class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        >
          <option v-for="a in airlines" :key="a.id" :value="a.id">{{ a.name }}</option>
        </select>
      </div>
      <div class="flex gap-4 items-center pt-2 select-none">
        <label class="flex items-center gap-2 text-sm font-semibold text-gray-700 cursor-pointer">
          <input v-model="form.hasWifi" type="checkbox" class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" /> WiFi a bordo
        </label>
        <label class="flex items-center gap-2 text-sm font-semibold text-gray-700 cursor-pointer">
          <input v-model="form.hasUsb" type="checkbox" class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" /> Puertos USB
        </label>
      </div>
    </AdminFormModal>
  </div>
</template>

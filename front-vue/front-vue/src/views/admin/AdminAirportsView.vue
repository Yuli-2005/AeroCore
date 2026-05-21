<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';
import type { Airport, City } from '../../models/domain';

const items = ref<Airport[]>([]);
const cities = ref<City[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);

const modalOpen = ref(false);
const editItem = ref<Partial<Airport> | null>(null);

const columns: TableColumn[] = [
  { key: 'iataCode', label: 'Código IATA' },
  { key: 'name', label: 'Nombre' },
  { key: 'city', label: 'Ciudad', render: (row: Airport) => row.city?.name || '—' },
];

const form = ref({
  name: '',
  iataCode: '',
  cityId: '',
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    const [airportsData, citiesData] = await Promise.all([
      adminService.getAirports(),
      adminService.getCities(),
    ]);
    items.value = airportsData;
    cities.value = citiesData;
  } catch {
    items.value = [];
    cities.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  form.value = {
    name: '',
    iataCode: '',
    cityId: cities.value[0]?.id || '',
  };
  modalOpen.value = true;
}

function openEdit(row: Airport) {
  editItem.value = row;
  form.value = {
    name: row.name || '',
    iataCode: row.iataCode || '',
    cityId: row.cityId || '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.name.trim() || !form.value.iataCode.trim() || !form.value.cityId) return;
  isSaving.value = true;
  try {
    if (editItem.value?.id) {
      await adminService.updateAirport(editItem.value.id, form.value);
    } else {
      await adminService.createAirport(form.value);
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
    await adminService.deleteAirport(id);
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
      title="Gestión de Aeropuertos"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['name', 'iataCode']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Aeropuerto' : 'Agregar Aeropuerto'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
        <input
          v-model="form.name"
          placeholder="Ej: Aeropuerto Mariscal Sucre"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Código IATA *</label>
        <input
          v-model="form.iataCode"
          placeholder="Ej: UIO"
          maxlength="3"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Ciudad *</label>
        <select
          v-model="form.cityId"
          required
          class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        >
          <option v-for="c in cities" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
    </AdminFormModal>
  </div>
</template>

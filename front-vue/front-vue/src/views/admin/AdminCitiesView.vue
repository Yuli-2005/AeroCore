<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';
import type { City, Country } from '../../models/domain';

const items = ref<City[]>([]);
const countries = ref<Country[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);

const modalOpen = ref(false);
const editItem = ref<Partial<City> | null>(null);

const columns: TableColumn[] = [
  { key: 'name', label: 'Nombre' },
  { key: 'country', label: 'País', render: (row: City) => row.country?.name || '—' },
];

const form = ref({
  name: '',
  countryId: '',
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    const [citiesData, countriesData] = await Promise.all([
      adminService.getCities(),
      adminService.getCountries(),
    ]);
    items.value = citiesData;
    countries.value = countriesData;
  } catch {
    items.value = [];
    countries.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  form.value = {
    name: '',
    countryId: countries.value[0]?.id || '',
  };
  modalOpen.value = true;
}

function openEdit(row: City) {
  editItem.value = row;
  form.value = {
    name: row.name || '',
    countryId: row.countryId || '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.name.trim() || !form.value.countryId) return;
  isSaving.value = true;
  try {
    if (editItem.value?.id) {
      await adminService.updateCity(editItem.value.id, form.value);
    } else {
      await adminService.createCity(form.value);
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
    await adminService.deleteCity(id);
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
      title="Gestión de Ciudades"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['name']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Ciudad' : 'Agregar Ciudad'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
        <input
          v-model="form.name"
          placeholder="Ej: Quito"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">País *</label>
        <select
          v-model="form.countryId"
          required
          class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        >
          <option v-for="c in countries" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
    </AdminFormModal>
  </div>
</template>

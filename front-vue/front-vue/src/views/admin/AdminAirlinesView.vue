<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';
import type { Airline } from '../../models/domain';

const items = ref<Airline[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);

const modalOpen = ref(false);
const editItem = ref<Partial<Airline> | null>(null);

const columns: TableColumn[] = [
  { key: 'iataCode', label: 'Código IATA' },
  { key: 'name', label: 'Nombre' },
];

const form = ref({
  name: '',
  iataCode: '',
  logoUrl: '',
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getAirlines();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  form.value = {
    name: '',
    iataCode: '',
    logoUrl: '',
  };
  modalOpen.value = true;
}

function openEdit(row: Airline) {
  editItem.value = row;
  form.value = {
    name: row.name || '',
    iataCode: row.iataCode || '',
    logoUrl: row.logoUrl || '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.name.trim() || !form.value.iataCode.trim()) return;
  isSaving.value = true;
  try {
    if (editItem.value?.id) {
      await adminService.updateAirline(editItem.value.id, form.value);
    } else {
      await adminService.createAirline(form.value);
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
    await adminService.deleteAirline(id);
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
      title="Gestión de Aerolíneas"
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
      :title="editItem ? 'Editar Aerolínea' : 'Agregar Aerolínea'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
        <input
          v-model="form.name"
          placeholder="Ej: LATAM Airlines"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Código IATA *</label>
        <input
          v-model="form.iataCode"
          placeholder="Ej: LA"
          maxlength="3"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">URL del Logo (Opcional)</label>
        <input
          v-model="form.logoUrl"
          placeholder="Ej: https://example.com/logo.png"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
    </AdminFormModal>
  </div>
</template>

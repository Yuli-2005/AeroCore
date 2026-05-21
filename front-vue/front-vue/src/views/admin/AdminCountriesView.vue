<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';
import type { Country } from '../../models/domain';

const items = ref<Country[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);

const modalOpen = ref(false);
const editItem = ref<Partial<Country> | null>(null);

const columns: TableColumn[] = [
  { key: 'name', label: 'Nombre' },
  { key: 'isoCode', label: 'Código ISO' },
  { key: 'phoneCode', label: 'Código de Teléfono' },
  { key: 'currencyCode', label: 'Código de Moneda' },
];

const form = ref({
  name: '',
  isoCode: '',
  phoneCode: '',
  currencyCode: '',
});

onMounted(() => {
  load();
});

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getCountries();
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
    isoCode: '',
    phoneCode: '',
    currencyCode: '',
  };
  modalOpen.value = true;
}

function openEdit(row: Country) {
  editItem.value = row;
  form.value = {
    name: row.name || '',
    isoCode: row.isoCode || '',
    phoneCode: row.phoneCode || '',
    currencyCode: row.currencyCode || '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.name.trim() || !form.value.isoCode.trim()) return;
  isSaving.value = true;
  try {
    if (editItem.value?.id) {
      await adminService.updateCountry(editItem.value.id, form.value);
    } else {
      await adminService.createCountry(form.value);
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
    await adminService.deleteCountry(id);
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
      title="Gestión de Países"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['name', 'isoCode']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar País' : 'Agregar País'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
        <input
          v-model="form.name"
          placeholder="Ej: Ecuador"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Código ISO *</label>
        <input
          v-model="form.isoCode"
          placeholder="Ej: EC"
          maxlength="3"
          required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Código de Teléfono</label>
        <input
          v-model="form.phoneCode"
          placeholder="Ej: +593"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">Código de Moneda</label>
        <input
          v-model="form.currencyCode"
          placeholder="Ej: USD"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase"
        />
      </div>
    </AdminFormModal>
  </div>
</template>

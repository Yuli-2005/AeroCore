<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = { id: string; name: string; description: string | null; category: string | null };

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);
const errorMsg = ref('');
const form = ref({ name: '', description: '', category: '' });

const columns: TableColumn[] = [
  { key: 'name',        label: 'Nombre' },
  { key: 'category',    label: 'Categoría',   render: (r: Row) => r.category ?? '---' },
  { key: 'description', label: 'Descripción', render: (r: Row) => r.description ?? '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getServices(); } catch { items.value = []; } finally { isLoading.value = false; }
}

function openAdd() {
  editItem.value = null; errorMsg.value = '';
  form.value = { name: '', description: '', category: '' };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row; errorMsg.value = '';
  form.value = { name: row.name, description: row.description ?? '', category: row.category ?? '' };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.name) return;
  isSaving.value = true; errorMsg.value = '';
  const body = { name: form.value.name.trim(), description: form.value.description || null, category: form.value.category || null };
  try {
    if (editItem.value?.id) await adminService.updateService(editItem.value.id, body);
    else await adminService.createService(body);
    modalOpen.value = false; await load();
  } catch (e: any) { errorMsg.value = e?.message || 'Error al guardar'; } finally { isSaving.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteService(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Catálogo de Servicios" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['name','category']" @add="openAdd" @edit="openEdit" @delete="onDelete" />
    <AdminFormModal :title="editItem ? 'Editar Servicio' : 'Nuevo Servicio'" :open="modalOpen" :is-loading="isSaving"
      @close="modalOpen = false" @submit="onSubmit">
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">{{ errorMsg }}</div>
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre *</label>
          <input v-model="form.name" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Categoría</label>
          <input v-model="form.category" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Descripción</label>
          <textarea v-model="form.description" rows="2" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

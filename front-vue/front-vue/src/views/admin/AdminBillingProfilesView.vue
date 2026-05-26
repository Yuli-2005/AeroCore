<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  userId: string;
  legalName: string;
  taxId: string;
  address: string | null;
  email: string | null;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);
const errorMsg = ref('');
const form = ref({ userId: '', legalName: '', taxId: '', address: '', email: '' });

const columns: TableColumn[] = [
  { key: 'legalName', label: 'Nombre Legal' },
  { key: 'taxId',     label: 'RUC / CI' },
  { key: 'email',     label: 'Email',     render: (r: Row) => r.email ?? '---' },
  { key: 'address',   label: 'Dirección', render: (r: Row) => r.address ?? '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getBillingProfiles(); } catch { items.value = []; } finally { isLoading.value = false; }
}

function openEdit(row: Row) {
  editItem.value = row; errorMsg.value = '';
  form.value = { userId: row.userId, legalName: row.legalName, taxId: row.taxId, address: row.address ?? '', email: row.email ?? '' };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.legalName || !form.value.taxId) return;
  isSaving.value = true; errorMsg.value = '';
  const body = { legalName: form.value.legalName, taxId: form.value.taxId, address: form.value.address || null, email: form.value.email || null };
  try {
    if (editItem.value?.id) await adminService.updateBillingProfile(editItem.value.id, body);
    modalOpen.value = false; await load();
  } catch (e: any) { errorMsg.value = e?.message || 'Error al guardar'; } finally { isSaving.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteBillingProfile(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Perfiles de Facturación" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['legalName','taxId','email']" :show-add="false" @edit="openEdit" @delete="onDelete" />
    <AdminFormModal title="Editar Perfil" :open="modalOpen" :is-loading="isSaving" @close="modalOpen = false" @submit="onSubmit">
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">{{ errorMsg }}</div>
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Nombre Legal *</label>
          <input v-model="form.legalName" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">RUC / CI *</label>
          <input v-model="form.taxId" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Email</label>
          <input v-model="form.email" type="email" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Dirección</label>
          <input v-model="form.address" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

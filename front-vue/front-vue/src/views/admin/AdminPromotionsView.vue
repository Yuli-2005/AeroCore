<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  code: string;
  discountType: string;
  discountValue: number;
  isActive: boolean;
  maxUsages: number | null;
  currentUsages: number;
  expiresAt: string | null;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);
const errorMsg = ref('');
const form = ref({ code: '', discountType: 'PERCENTAGE', discountValue: 10, isActive: true, maxUsages: '', expiresAt: '' });

const columns: TableColumn[] = [
  { key: 'code',          label: 'Código' },
  { key: 'discountType',  label: 'Tipo',     render: (r: Row) => r.discountType === 'PERCENTAGE' ? `%` : '$' },
  { key: 'discountValue', label: 'Valor',    render: (r: Row) => r.discountType === 'PERCENTAGE' ? `${r.discountValue}%` : `$${r.discountValue}` },
  { key: 'isActive',      label: 'Activo',   render: (r: Row) => r.isActive ? '✅' : '❌' },
  { key: 'currentUsages', label: 'Usos',     render: (r: Row) => `${r.currentUsages} / ${r.maxUsages ?? '∞'}` },
  { key: 'expiresAt',     label: 'Vence',    render: (r: Row) => r.expiresAt ? new Date(r.expiresAt).toLocaleDateString('es-EC') : 'Sin vencimiento' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getPromotions(); } catch { items.value = []; } finally { isLoading.value = false; }
}

function openAdd() {
  editItem.value = null; errorMsg.value = '';
  form.value = { code: '', discountType: 'PERCENTAGE', discountValue: 10, isActive: true, maxUsages: '', expiresAt: '' };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row; errorMsg.value = '';
  form.value = {
    code: row.code, discountType: row.discountType, discountValue: Number(row.discountValue),
    isActive: row.isActive, maxUsages: row.maxUsages?.toString() ?? '', expiresAt: row.expiresAt ? row.expiresAt.slice(0, 10) : '',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.code) return;
  isSaving.value = true; errorMsg.value = '';
  const body = {
    code: form.value.code.trim().toUpperCase(), discountType: form.value.discountType,
    discountValue: Number(form.value.discountValue), isActive: form.value.isActive,
    maxUsages: form.value.maxUsages ? Number(form.value.maxUsages) : null,
    expiresAt: form.value.expiresAt ? new Date(form.value.expiresAt).toISOString() : null,
  };
  try {
    if (editItem.value?.id) await adminService.updatePromotion(editItem.value.id, body);
    else await adminService.createPromotion(body);
    modalOpen.value = false; await load();
  } catch (e: any) { errorMsg.value = e?.message || 'Error al guardar'; } finally { isSaving.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deletePromotion(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Promociones" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['code']" @add="openAdd" @edit="openEdit" @delete="onDelete" />
    <AdminFormModal :title="editItem ? 'Editar Promoción' : 'Nueva Promoción'" :open="modalOpen" :is-loading="isSaving"
      @close="modalOpen = false" @submit="onSubmit">
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">{{ errorMsg }}</div>
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Código *</label>
          <input v-model="form.code" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm uppercase font-mono focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Tipo *</label>
            <select v-model="form.discountType" class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
              <option value="PERCENTAGE">Porcentaje (%)</option>
              <option value="FIXED_AMOUNT">Monto fijo ($)</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Valor *</label>
            <input v-model="form.discountValue" type="number" min="0" step="0.01" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Máx. usos</label>
            <input v-model="form.maxUsages" type="number" min="1" placeholder="Sin límite" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Vence</label>
            <input v-model="form.expiresAt" type="date" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
          <input v-model="form.isActive" type="checkbox" class="rounded" />
          Promoción activa
        </label>
      </div>
    </AdminFormModal>
  </div>
</template>

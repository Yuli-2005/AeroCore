<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  action: string;
  entity: string | null;
  entityId: string | null;
  userId: string | null;
  createdAt: string;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);

const columns: TableColumn[] = [
  { key: 'action',    label: 'Acción' },
  { key: 'entity',    label: 'Entidad',   render: (r: Row) => r.entity ?? '---' },
  { key: 'entityId',  label: 'ID Entidad', render: (r: Row) => r.entityId ? r.entityId.slice(0, 8) + '…' : '---' },
  { key: 'userId',    label: 'Usuario',   render: (r: Row) => r.userId ? r.userId.slice(0, 8) + '…' : 'Sistema' },
  { key: 'createdAt', label: 'Fecha',     render: (r: Row) => r.createdAt ? new Date(r.createdAt).toLocaleString('es-EC') : '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getAuditLogs(); } catch { items.value = []; } finally { isLoading.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Auditoría" :data="items" :columns="columns" :is-loading="isLoading"
      :search-keys="['action','entity']" :show-add="false" :show-edit="false" :show-delete="false" />
  </div>
</template>

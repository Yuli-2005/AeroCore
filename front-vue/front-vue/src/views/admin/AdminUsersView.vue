<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  email: string;
  firstName: string;
  firstLastName: string;
  role: string;
  isActive: boolean;
  createdAt: string;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);

const columns: TableColumn[] = [
  { key: 'firstName',     label: 'Nombre',   render: (r: Row) => `${r.firstName} ${r.firstLastName}` },
  { key: 'email',         label: 'Email' },
  { key: 'role',          label: 'Rol',      render: (r: Row) => r.role === 'ADMIN' ? '🔑 Admin' : '👤 Cliente' },
  { key: 'isActive',      label: 'Estado',   render: (r: Row) => r.isActive ? '✅ Activo' : '❌ Inactivo' },
  { key: 'createdAt',     label: 'Registro', render: (r: Row) => r.createdAt ? new Date(r.createdAt).toLocaleDateString('es-EC') : '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getUsers(); } catch { items.value = []; } finally { isLoading.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteUser(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Usuarios" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['email','firstName','firstLastName','role']"
      :show-add="false" :show-edit="false" @delete="onDelete" />
  </div>
</template>

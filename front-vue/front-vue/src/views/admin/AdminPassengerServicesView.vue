<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  passengerId: string;
  serviceId: string;
  quantity: number;
  totalPrice: number;
  passenger?: { firstName: string; lastName: string };
  service?: { name: string };
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);

const columns: TableColumn[] = [
  { key: 'passenger',  label: 'Pasajero',  render: (r: Row) => r.passenger ? `${r.passenger.firstName} ${r.passenger.lastName}` : r.passengerId.slice(0,8)+'…' },
  { key: 'service',    label: 'Servicio',  render: (r: Row) => r.service?.name ?? r.serviceId },
  { key: 'quantity',   label: 'Cantidad' },
  { key: 'totalPrice', label: 'Total',     render: (r: Row) => `$${Number(r.totalPrice).toFixed(2)}` },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getPassengerServices(); } catch { items.value = []; } finally { isLoading.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deletePassengerService(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Servicios por Pasajero" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="[]" :show-add="false" :show-edit="false" @delete="onDelete" />
  </div>
</template>

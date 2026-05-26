<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  invoiceId: string;
  description: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);

const columns: TableColumn[] = [
  { key: 'description', label: 'Descripción' },
  { key: 'quantity',    label: 'Cant.' },
  { key: 'unitPrice',   label: 'P. Unitario', render: (r: Row) => `$${Number(r.unitPrice).toFixed(2)}` },
  { key: 'totalPrice',  label: 'Total',        render: (r: Row) => `$${Number(r.totalPrice).toFixed(2)}` },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getInvoiceItems(); } catch { items.value = []; } finally { isLoading.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteInvoiceItem(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Ítems de Factura" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['description']" :show-add="false" :show-edit="false" @delete="onDelete" />
  </div>
</template>

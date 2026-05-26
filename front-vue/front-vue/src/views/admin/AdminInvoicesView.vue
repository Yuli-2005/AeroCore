<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  invoiceNumber: string;
  paymentId: string;
  subtotal: number;
  taxAmount: number;
  total: number;
  createdAt: string;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);

const columns: TableColumn[] = [
  { key: 'invoiceNumber', label: 'N° Factura' },
  { key: 'subtotal',      label: 'Subtotal',  render: (r: Row) => `$${Number(r.subtotal).toFixed(2)}` },
  { key: 'taxAmount',     label: 'IVA 15%',   render: (r: Row) => `$${Number(r.taxAmount).toFixed(2)}` },
  { key: 'total',         label: 'Total',     render: (r: Row) => `$${Number(r.total).toFixed(2)}` },
  { key: 'createdAt',     label: 'Fecha',     render: (r: Row) => r.createdAt ? new Date(r.createdAt).toLocaleDateString('es-EC') : '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getInvoices(); } catch { items.value = []; } finally { isLoading.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteInvoice(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Facturas" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="['invoiceNumber']" :show-add="false" :show-edit="false" @delete="onDelete" />
  </div>
</template>

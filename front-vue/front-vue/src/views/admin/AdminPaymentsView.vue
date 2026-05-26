<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  reservationId: string;
  amount: number;
  provider: string;
  transactionId: string;
  status: string;
  createdAt: string;
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);


const PROVIDER_ICONS: Record<string, string> = {
  VISA:       '💳 Visa',
  MASTERCARD: '💳 Mastercard',
  AMEX:       '💳 Amex',
  PAYPAL:     '🅿️ PayPal',
  TRANSFER:   '🏦 Transferencia',
};

const columns: TableColumn[] = [
  { key: 'reservationId', label: 'Reserva', render: (r: Row) => r.reservationId.slice(0, 8) + '…' },
  { key: 'provider',      label: 'Método',  render: (r: Row) => PROVIDER_ICONS[r.provider] ?? r.provider },
  { key: 'amount',        label: 'Monto',   render: (r: Row) => `$${Number(r.amount).toFixed(2)}` },
  { key: 'transactionId', label: 'Transacción', render: (r: Row) => r.transactionId },
  { key: 'status',        label: 'Estado',  render: (r: Row) => r.status },
  { key: 'createdAt',     label: 'Fecha',   render: (r: Row) => r.createdAt ? new Date(r.createdAt).toLocaleDateString('es-EC') : '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getPayments();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deletePayment(id);
    await load();
  } catch {
    //
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable
      title="Pagos"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['transactionId', 'provider', 'status']"
      :show-add="false"
      :show-edit="false"
      @delete="onDelete"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  boardingCode: string;
  seatNumber: string | null;
  status: string;
  createdAt: string;
  passenger?: { firstName: string; lastName: string; documentNumber: string };
  segment?: {
    originAirport?: { iataCode: string };
    destinationAirport?: { iataCode: string };
    airline?: { name: string };
    departureDateTime?: string;
  };
};

const items = ref<Row[]>([]);
const isLoading = ref(true);
const isDeleting = ref(false);

const columns: TableColumn[] = [
  { key: 'boardingCode', label: 'Código' },
  { key: 'passenger',    label: 'Pasajero', render: (r: Row) => r.passenger ? `${r.passenger.firstName} ${r.passenger.lastName}` : '---' },
  { key: 'segment',      label: 'Ruta', render: (r: Row) => r.segment ? `${r.segment.originAirport?.iataCode ?? '?'} → ${r.segment.destinationAirport?.iataCode ?? '?'}` : '---' },
  { key: 'seatNumber',   label: 'Asiento', render: (r: Row) => r.seatNumber ?? '---' },
  { key: 'status',       label: 'Estado' },
  { key: 'createdAt',    label: 'Fecha', render: (r: Row) => r.createdAt ? new Date(r.createdAt).toLocaleDateString('es-EC') : '---' },
];

onMounted(load);

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getBoardingPasses();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteBoardingPass(id);
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
      title="Pases de Abordar"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['boardingCode', 'status']"
      :show-add="false"
      :show-edit="false"
      @delete="onDelete"
    />
  </div>
</template>

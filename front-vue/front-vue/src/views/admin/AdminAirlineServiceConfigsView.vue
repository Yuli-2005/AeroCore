<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  airlineId: string;
  serviceId: string;
  price: number;
  isIncluded: boolean;
  airline?: { name: string };
  service?: { name: string };
};

const items = ref<Row[]>([]);
const airlines = ref<any[]>([]);
const services = ref<any[]>([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);
const errorMsg = ref('');
const form = ref({ airlineId: '', serviceId: '', price: 0, isIncluded: false });

const columns: TableColumn[] = [
  { key: 'airline',    label: 'Aerolínea',  render: (r: Row) => r.airline?.name ?? r.airlineId },
  { key: 'service',    label: 'Servicio',   render: (r: Row) => r.service?.name ?? r.serviceId },
  { key: 'price',      label: 'Precio',     render: (r: Row) => `$${Number(r.price).toFixed(2)}` },
  { key: 'isIncluded', label: 'Incluido',   render: (r: Row) => r.isIncluded ? '✅ Sí' : '❌ No' },
];

onMounted(async () => {
  load();
  try {
    const [al, sv] = await Promise.all([adminService.getAirlines(), adminService.getServices()]);
    airlines.value = al; services.value = sv;
  } catch { }
});

async function load() {
  isLoading.value = true;
  try { items.value = await adminService.getAirlineServiceConfigs(); } catch { items.value = []; } finally { isLoading.value = false; }
}

function openAdd() {
  editItem.value = null; errorMsg.value = '';
  form.value = { airlineId: '', serviceId: '', price: 0, isIncluded: false };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row; errorMsg.value = '';
  form.value = { airlineId: row.airlineId, serviceId: row.serviceId, price: Number(row.price), isIncluded: row.isIncluded };
  modalOpen.value = true;
}

async function onSubmit() {
  if (!form.value.airlineId || !form.value.serviceId) return;
  isSaving.value = true; errorMsg.value = '';
  const body = { airlineId: form.value.airlineId, serviceId: form.value.serviceId, price: Number(form.value.price), isIncluded: form.value.isIncluded };
  try {
    if (editItem.value?.id) await adminService.updateAirlineServiceConfig(editItem.value.id, body);
    else await adminService.createAirlineServiceConfig(body);
    modalOpen.value = false; await load();
  } catch (e: any) { errorMsg.value = e?.message || 'Error al guardar'; } finally { isSaving.value = false; }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try { await adminService.deleteAirlineServiceConfig(id); await load(); } catch { } finally { isDeleting.value = false; }
}
</script>

<template>
  <div class="space-y-6">
    <AdminTable title="Precios por Aerolínea" :data="items" :columns="columns" :is-loading="isLoading"
      :is-deleting="isDeleting" :search-keys="[]" @add="openAdd" @edit="openEdit" @delete="onDelete" />
    <AdminFormModal :title="editItem ? 'Editar Config.' : 'Nueva Config.'" :open="modalOpen" :is-loading="isSaving"
      @close="modalOpen = false" @submit="onSubmit">
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">{{ errorMsg }}</div>
      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Aerolínea *</label>
          <select v-model="form.airlineId" required class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
            <option value="" disabled>Seleccione aerolínea</option>
            <option v-for="a in airlines" :key="a.id" :value="a.id">{{ a.name }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Servicio *</label>
          <select v-model="form.serviceId" required class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
            <option value="" disabled>Seleccione servicio</option>
            <option v-for="s in services" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Precio (USD)</label>
          <input v-model="form.price" type="number" min="0" step="0.01" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
        </div>
        <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
          <input v-model="form.isIncluded" type="checkbox" class="rounded" />
          Incluido en el precio del tiquete
        </label>
      </div>
    </AdminFormModal>
  </div>
</template>

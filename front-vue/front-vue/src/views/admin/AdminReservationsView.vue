<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AdminTable, { type TableColumn } from '../../components/AdminTable.vue';
import AdminFormModal from '../../components/AdminFormModal.vue';
import { adminService } from '../../services/admin.service';

type Row = {
  id: string;
  reservationCode: string;
  userId: string;
  flightId: string;
  totalAmount: number;
  status: string;
  createdAt: string;
  user?: { firstName: string; firstLastName: string; email: string };
  flight?: { originAirportIata: string; destinationAirportIata: string; departureDate: string };
};

const items = ref<Row[]>([]);
const flights = ref<any[]>([]);
const users = ref<any[]>([]);

const isLoading = ref(true);
const isSaving = ref(false);
const isDeleting = ref(false);
const errorMsg = ref('');

const modalOpen = ref(false);
const editItem = ref<Partial<Row> | null>(null);

const STATUS_LABELS: Record<string, string> = {
  PENDING: 'Pendiente',
  CONFIRMED: 'Confirmada',
  CANCELLED: 'Cancelada',
};

const columns: TableColumn[] = [
  { key: 'reservationCode', label: 'Código' },
  { key: 'user', label: 'Cliente', render: (r: Row) => r.user ? `${r.user.firstName} ${r.user.firstLastName}` : r.userId },
  { key: 'flight', label: 'Vuelo', render: (r: Row) => r.flight ? `${r.flight.originAirportIata}-${r.flight.destinationAirportIata} (${new Date(r.flight.departureDate).toLocaleDateString('es-EC')})` : r.flightId },
  { key: 'totalAmount', label: 'Monto Total', render: (r: Row) => `$${Number(r.totalAmount).toFixed(2)}` },
  { key: 'status', label: 'Estado', render: (r: Row) => STATUS_LABELS[r.status] ?? r.status },
];

const form = ref({
  reservationCode: '',
  userId: '',
  flightId: '',
  totalAmount: 0,
  status: 'PENDING',
});

onMounted(() => {
  load();
  loadCatalogs();
});

async function loadCatalogs() {
  try {
    const [fl, us] = await Promise.all([
      adminService.getFlights(),
      adminService.getUsers(),
    ]);
    flights.value = fl;
    users.value = us;
  } catch (err) {
    console.error('Error cargando catálogos:', err);
  }
}

async function load() {
  isLoading.value = true;
  try {
    items.value = await adminService.getReservations();
  } catch {
    items.value = [];
  } finally {
    isLoading.value = false;
  }
}

function openAdd() {
  editItem.value = null;
  errorMsg.value = '';
  form.value = {
    reservationCode: `RES-${Math.random().toString(36).substring(2, 8).toUpperCase()}`,
    userId: '',
    flightId: '',
    totalAmount: 0,
    status: 'PENDING',
  };
  modalOpen.value = true;
}

function openEdit(row: Row) {
  editItem.value = row;
  errorMsg.value = '';
  form.value = {
    reservationCode: row.reservationCode || '',
    userId: row.userId || '',
    flightId: row.flightId || '',
    totalAmount: Number(row.totalAmount) || 0,
    status: row.status || 'PENDING',
  };
  modalOpen.value = true;
}

async function onSubmit() {
  const { reservationCode, userId, flightId, totalAmount, status } = form.value;
  if (!reservationCode || !userId || !flightId) return;

  errorMsg.value = '';
  isSaving.value = true;

  const body = {
    reservationCode: reservationCode.trim(),
    userId,
    flightId,
    totalAmount: Number(totalAmount),
    status,
  };

  try {
    if (editItem.value?.id) {
      await adminService.updateReservation(editItem.value.id, body);
    } else {
      await adminService.createReservation(body);
    }
    modalOpen.value = false;
    await load();
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al guardar la reserva';
  } finally {
    isSaving.value = false;
  }
}

async function onDelete(id: string) {
  isDeleting.value = true;
  try {
    await adminService.deleteReservation(id);
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
      title="Gestión de Reservas"
      :data="items"
      :columns="columns"
      :is-loading="isLoading"
      :is-deleting="isDeleting"
      :search-keys="['reservationCode']"
      @add="openAdd"
      @edit="openEdit"
      @delete="onDelete"
    />

    <AdminFormModal
      :title="editItem ? 'Editar Reserva' : 'Nueva Reserva'"
      :open="modalOpen"
      :is-loading="isSaving"
      @close="modalOpen = false"
      @submit="onSubmit"
    >
      <div v-if="errorMsg" class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
        {{ errorMsg }}
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Código de Reserva *</label>
          <input
            v-model="form.reservationCode"
            required
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none uppercase font-semibold"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Cliente *</label>
          <select
            v-model="form.userId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione el cliente</option>
            <option v-for="u in users" :key="u.id" :value="u.id">
              {{ u.firstName }} {{ u.firstLastName }} ({{ u.email }})
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Vuelo *</label>
          <select
            v-model="form.flightId"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="" disabled>Seleccione el vuelo</option>
            <option v-for="f in flights" :key="f.id" :value="f.id">
              {{ f.originAirportIata }} → {{ f.destinationAirportIata }} ({{ new Date(f.departureDate).toLocaleDateString('es-EC') }})
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Monto Total (USD) *</label>
          <input
            v-model="form.totalAmount"
            type="number"
            required
            min="0"
            step="0.01"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-gray-500 mb-1">Estado *</label>
          <select
            v-model="form.status"
            required
            class="w-full border border-gray-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          >
            <option value="PENDING">Pendiente</option>
            <option value="CONFIRMED">Confirmada</option>
            <option value="CANCELLED">Cancelada</option>
          </select>
        </div>
      </div>
    </AdminFormModal>
  </div>
</template>

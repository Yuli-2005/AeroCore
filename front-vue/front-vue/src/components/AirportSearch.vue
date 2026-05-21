<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { airportsService } from '../services/airports.service';

export interface AirportOption {
  iataCode: string;
  name: string;
  cityName: string;
  countryName: string;
  searchText: string;
}

const props = withDefaults(
  defineProps<{
    modelValue?: string;
    value?: string;
    placeholder?: string;
  }>(),
  {
    modelValue: '',
    value: '',
    placeholder: 'Ciudad o código IATA',
  }
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: string): void;
  (e: 'valueChange', val: string): void;
}>();

const elRef = ref<HTMLElement | null>(null);

const airports = ref<AirportOption[]>([]);
const loading = ref(true);
const open = ref(false);
const cursor = ref(-1);
const query = ref('');
const internalCode = ref('');

const selected = computed(() => !!internalCode.value);

// Normalizar texto (elimina acentos y convierte a minúsculas)
function normalizeText(value: string | null | undefined): string {
  return (value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

// Calcular la puntuación de relevancia del aeropuerto frente a la consulta
function airportScore(a: AirportOption, queryStr: string): number {
  if (!queryStr) return 1;

  const code = normalizeText(a.iataCode);
  const city = normalizeText(a.cityName);
  const name = normalizeText(a.name);
  const country = normalizeText(a.countryName);

  if (code === queryStr) return 100;
  if (city === queryStr) return 95;
  if (name === queryStr) return 90;
  if (code.startsWith(queryStr)) return 85;
  if (city.startsWith(queryStr)) return 80;
  if (name.startsWith(queryStr)) return 70;
  if (country.startsWith(queryStr)) return 60;
  if (a.searchText.includes(queryStr)) return 40;
  return 0;
}

// Filtrar y ordenar los aeropuertos según la búsqueda
const filtered = computed(() => {
  const q = normalizeText(query.value);
  if (q.length < 1) return airports.value.slice(0, 8);

  return airports.value
    .map((a) => ({ item: a, score: airportScore(a, q) }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score || a.item.cityName.localeCompare(b.item.cityName))
    .map(({ item }) => item)
    .slice(0, 10);
});

// Sincronizar la etiqueta visible con el código IATA seleccionado
function syncLabel() {
  const found = airports.value.find((a) => a.iataCode === internalCode.value);
  if (found) {
    query.value = `${found.iataCode} - ${found.cityName}`;
  } else {
    query.value = '';
  }
}

// Manejar cambios externos del valor de entrada
watch(
  () => props.modelValue || props.value,
  (newVal) => {
    const code = (newVal ?? '').trim().toUpperCase();
    if (code !== internalCode.value) {
      internalCode.value = code;
      syncLabel();
    }
  },
  { immediate: true }
);

// Almacenar aeropuertos al montar el componente
onMounted(async () => {
  try {
    const list = await airportsService.getAll();
    airports.value = list.map((a) => ({
      iataCode: a.iataCode.toUpperCase(),
      name: a.name,
      cityName: a.city?.name ?? a.name,
      countryName: a.city?.country?.name ?? '',
      searchText: normalizeText(
        `${a.iataCode} ${a.name} ${a.city?.name ?? ''} ${a.city?.country?.name ?? ''}`
      ),
    }));
    loading.value = false;
    syncLabel();
  } catch (err) {
    console.error('Error cargando aeropuertos:', err);
    airports.value = [];
    loading.value = false;
  }

  // Event listener para cerrar al hacer clic afuera
  window.addEventListener('click', handleDocClick);
});

onUnmounted(() => {
  window.removeEventListener('click', handleDocClick);
});

function handleDocClick(e: MouseEvent) {
  if (elRef.value && !elRef.value.contains(e.target as Node)) {
    open.value = false;
  }
}

function onInput() {
  internalCode.value = '';
  cursor.value = -1;
  open.value = true;
  emit('update:modelValue', '');
  emit('valueChange', '');
}

function select(a: AirportOption) {
  internalCode.value = a.iataCode;
  query.value = `${a.iataCode} - ${a.cityName}`;
  open.value = false;
  cursor.value = -1;
  emit('update:modelValue', a.iataCode);
  emit('valueChange', a.iataCode);
}

function resolveCurrentValue(): string {
  if (internalCode.value) return internalCode.value;
  if (!normalizeText(query.value)) return '';
  const match = filtered.value[0];
  if (!match) return '';
  select(match);
  return match.iataCode;
}

defineExpose({
  resolveCurrentValue,
});

function clear() {
  internalCode.value = '';
  query.value = '';
  open.value = false;
  emit('update:modelValue', '');
  emit('valueChange', '');
}

function onKey(e: KeyboardEvent) {
  const len = filtered.value.length;
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    cursor.value = Math.min(cursor.value + 1, len - 1);
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    cursor.value = Math.max(cursor.value - 1, -1);
  } else if (e.key === 'Enter' && cursor.value >= 0) {
    e.preventDefault();
    select(filtered.value[cursor.value]);
  } else if (e.key === 'Enter') {
    e.preventDefault();
    resolveCurrentValue();
  } else if (e.key === 'Escape') {
    open.value = false;
  }
}
</script>

<template>
  <div ref="elRef" class="relative">
    <div class="relative">
      <slot name="icon" />
      <input
        v-model="query"
        @input="onInput"
        @focus="open = true"
        @keydown="onKey"
        :placeholder="placeholder"
        autocomplete="off"
        class="w-full border-2 rounded-xl pl-9 pr-8 py-3 text-sm font-medium text-gray-900 focus:ring-2 focus:ring-blue-500 focus:border-blue-400 outline-none transition-colors placeholder:font-normal placeholder:text-gray-400"
        :class="selected ? 'border-blue-400' : 'border-gray-200'"
      />
      <button
        v-if="selected"
        type="button"
        @click="clear"
        class="absolute right-2 top-1/2 -translate-y-1/2 w-5 h-5 flex items-center justify-center rounded-full bg-gray-200 hover:bg-gray-300 text-gray-500 text-xs transition-colors"
      >
        x
      </button>
    </div>

    <!-- Dropdown results -->
    <div
      v-if="open && filtered.length > 0"
      class="absolute z-50 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-xl max-h-60 overflow-y-auto"
    >
      <button
        v-for="(a, i) in filtered"
        :key="a.iataCode"
        type="button"
        @click="select(a)"
        class="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-blue-50 transition-colors text-left"
        :class="{ 'bg-blue-50': i === cursor }"
      >
        <span class="w-10 flex-shrink-0 font-mono font-bold text-blue-600 text-sm">{{ a.iataCode }}</span>
        <div class="min-w-0">
          <p class="text-sm font-medium text-gray-900 truncate">
            {{ a.cityName }} <span class="text-gray-400 font-normal">{{ a.countryName }}</span>
          </p>
          <p class="text-xs text-gray-400 truncate">{{ a.name }}</p>
        </div>
      </button>
    </div>

    <!-- Empty State -->
    <div
      v-if="open && query.length >= 2 && filtered.length === 0 && !loading"
      class="absolute z-50 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-xl px-4 py-3 text-sm text-gray-400"
    >
      Sin resultados para "{{ query }}"
    </div>

    <!-- Loading State -->
    <div
      v-if="open && loading"
      class="absolute z-50 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-xl px-4 py-3 text-sm text-gray-400"
    >
      Cargando aeropuertos...
    </div>
  </div>
</template>

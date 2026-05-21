<script setup lang="ts">
import { onMounted, onUnmounted, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    title?: string;
    open?: boolean;
    isLoading?: boolean;
  }>(),
  {
    title: '',
    open: false,
    isLoading: false,
  }
);

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'submit', event: Event): void;
}>();

function handleOverlayClick(e: MouseEvent) {
  const target = e.target as HTMLElement;
  if (target.classList.contains('modal-overlay')) {
    emit('close');
  }
}

function handleEscape(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) {
    emit('close');
  }
}

// Escuchar el evento de la tecla Escape de forma nativa
onMounted(() => {
  window.addEventListener('keydown', handleEscape);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleEscape);
});

// Prevenir scroll en el fondo cuando el modal esté abierto
watch(
  () => props.open,
  (val) => {
    if (val) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
  }
);
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 modal-overlay"
      @click="handleOverlayClick"
    >
      <div
        class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col"
        @click.stop
      >
        <!-- Modal Header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-semibold text-gray-900">{{ title }}</h2>
          <button
            type="button"
            @click="emit('close')"
            class="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Modal Form Body -->
        <form @submit.prevent="emit('submit', $event)" class="flex flex-col flex-1 overflow-hidden">
          <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
            <slot />
          </div>

          <!-- Modal Footer Actions -->
          <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-xl">
            <button
              type="button"
              @click="emit('close')"
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              :disabled="isLoading"
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {{ isLoading ? 'Guardando...' : 'Guardar' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </Teleport>
</template>

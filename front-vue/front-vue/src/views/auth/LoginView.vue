<script setup lang="ts">
import { ref, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/auth';
import { authService } from '../../services/auth.service';
import heroImg from '../../assets/hero.png';

const router = useRouter();
const authStore = useAuthStore();

const form = reactive({
  email: '',
  password: '',
});

const touched = reactive({
  email: false,
  password: false,
});

const loading = ref(false);
const errorMsg = ref<string | null>(null);

// Validaciones locales
const isEmailValid = (val: string) => {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val);
};

const isPasswordValid = (val: string) => {
  return val.length >= 6;
};

const isFormInvalid = () => {
  return !isEmailValid(form.email) || !isPasswordValid(form.password);
};

async function onSubmit() {
  touched.email = true;
  touched.password = true;

  if (isFormInvalid()) return;

  loading.value = true;
  errorMsg.value = null;

  try {
    const res = await authService.login({
      email: form.email,
      password: form.password,
    });
    authStore.setAuth(res.user, res.token);
    if (authStore.isAdmin) {
      router.push('/admin/dashboard');
    } else {
      router.push('/');
    }
  } catch (err: any) {
    errorMsg.value = err?.message || 'Error al iniciar sesión';
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="min-h-screen flex">
    <!-- Left: Image panel (hidden on mobile) -->
    <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden">
      <img :src="heroImg" alt="Avión volando" class="absolute inset-0 w-full h-full object-cover" />
      <div class="absolute inset-0 bg-gradient-to-br from-blue-900/80 via-indigo-900/70 to-purple-900/60"></div>
      <div class="relative z-10 flex flex-col justify-center p-16 text-white">
        <div class="animate-fade-up">
          <div class="w-12 h-12 rounded-2xl gradient-brand flex items-center justify-center mb-8 shadow-lg">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </div>
          <h2 class="text-4xl font-extrabold leading-tight mb-4">
            Bienvenido de<br/>vuelta a <span class="bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">AeroCore</span>
          </h2>
          <p class="text-slate-300 text-lg leading-relaxed max-w-md">
            Inicia sesión para acceder a tus reservas, gestionar tus viajes y descubrir nuevos destinos.
          </p>
        </div>
      </div>
    </div>

    <!-- Right: Login form -->
    <div class="flex-1 flex items-center justify-center p-4 sm:p-8 bg-gradient-to-br from-slate-50 via-white to-blue-50/30">
      <div class="w-full max-w-md animate-fade-up">
        <div class="bg-white rounded-3xl shadow-xl p-8 sm:p-10 border border-gray-100/80">
          <div class="text-center mb-8">
            <div class="lg:hidden inline-flex items-center justify-center w-14 h-14 gradient-brand rounded-2xl mb-4 shadow-lg shadow-blue-500/20">
              <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </div>
            <h1 class="text-2xl font-extrabold text-gray-900">Iniciar sesión</h1>
            <p class="text-sm text-gray-500 mt-1.5">Ingresa tus credenciales para continuar</p>
          </div>

          <div v-if="errorMsg" class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl p-3 mb-6">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {{ errorMsg }}
          </div>

          <form @submit.prevent="onSubmit" class="space-y-5">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1.5">Correo electrónico</label>
              <div class="relative">
                <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                <input
                  v-model="form.email"
                  @blur="touched.email = true"
                  type="email"
                  placeholder="tu@email.com"
                  class="w-full pl-11 pr-4 py-3 border-2 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder:text-gray-400 bg-gray-50/50"
                  :class="touched.email && !isEmailValid(form.email) ? 'border-red-400 bg-red-50/30' : 'border-gray-200'"
                />
              </div>
              <p v-if="touched.email && !isEmailValid(form.email)" class="text-xs text-red-500 mt-1">Email inválido</p>
            </div>

            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1.5">Contraseña</label>
              <div class="relative">
                <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                <input
                  v-model="form.password"
                  @blur="touched.password = true"
                  type="password"
                  placeholder="••••••••"
                  class="w-full pl-11 pr-4 py-3 border-2 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder:text-gray-400 bg-gray-50/50"
                  :class="touched.password && !isPasswordValid(form.password) ? 'border-red-400 bg-red-50/30' : 'border-gray-200'"
                />
              </div>
              <p v-if="touched.password && !isPasswordValid(form.password)" class="text-xs text-red-500 mt-1">Mínimo 6 caracteres</p>
            </div>

            <button
              type="submit"
              :disabled="loading"
              class="w-full flex items-center justify-center gap-2 gradient-brand text-white font-semibold py-3 rounded-xl transition-all duration-300 hover:shadow-lg hover:shadow-blue-500/25 hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
            >
              <svg v-if="loading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              {{ loading ? 'Iniciando sesión...' : 'Iniciar sesión' }}
            </button>
          </form>

          <p class="text-center text-sm text-gray-500 mt-8">
            ¿No tienes cuenta?
            <RouterLink to="/register" class="gradient-brand-text font-bold hover:underline">Regístrate</RouterLink>
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

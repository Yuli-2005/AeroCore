import { createRouter, createWebHistory } from 'vue-router';
import type { RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';

// Importación directa de Layouts para tenerlos como base
import MainLayout from '../layouts/MainLayout.vue';
import AdminLayout from '../layouts/AdminLayout.vue';

const routes: RouteRecordRaw[] = [
  // Rutas de invitados (Páginas de login y registro)
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/auth/LoginView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('../views/auth/RegisterView.vue'),
    meta: { requiresGuest: true },
  },

  // Rutas del portal público / cliente bajo MainLayout
  {
    path: '/',
    component: MainLayout,
    children: [
      {
        path: '',
        name: 'home',
        component: () => import('../views/flights/HomeView.vue'),
      },
      {
        path: 'results',
        name: 'results',
        component: () => import('../views/flights/ResultsView.vue'),
      },
      {
        path: 'flights/:id',
        name: 'flight-detail',
        component: () => import('../views/flights/FlightDetailView.vue'),
      },
      // Rutas de cliente que requieren autenticación
      {
        path: 'reservations/new/:flightClassId',
        name: 'reservation-new',
        component: () => import('../views/reservations/ReservationView.vue'),
        meta: { requiresAuth: true },
      },
      {
        path: 'my-trips',
        name: 'my-trips',
        component: () => import('../views/reservations/MyTripsView.vue'),
        meta: { requiresAuth: true },
      },
      {
        path: 'my-trips/:id',
        name: 'reservation-detail',
        component: () => import('../views/reservations/ReservationDetailView.vue'),
        meta: { requiresAuth: true },
      },
    ],
  },

  // Rutas de administración bajo AdminLayout (requieren rol ADMIN)
  {
    path: '/admin',
    component: AdminLayout,
    meta: { requiresAdmin: true },
    children: [
      {
        path: '',
        redirect: '/admin/dashboard',
      },
      {
        path: 'dashboard',
        name: 'admin-dashboard',
        component: () => import('../views/admin/DashboardView.vue'),
      },
      {
        path: 'countries',
        name: 'admin-countries',
        component: () => import('../views/admin/AdminCountriesView.vue'),
      },
      {
        path: 'cities',
        name: 'admin-cities',
        component: () => import('../views/admin/AdminCitiesView.vue'),
      },
      {
        path: 'airports',
        name: 'admin-airports',
        component: () => import('../views/admin/AdminAirportsView.vue'),
      },
      {
        path: 'airlines',
        name: 'admin-airlines',
        component: () => import('../views/admin/AdminAirlinesView.vue'),
      },
      {
        path: 'aircraft',
        name: 'admin-aircraft',
        component: () => import('../views/admin/AdminAircraftView.vue'),
      },
      {
        path: 'flights',
        name: 'admin-flights',
        component: () => import('../views/admin/AdminFlightsView.vue'),
      },
      {
        path: 'segments',
        name: 'admin-segments',
        component: () => import('../views/admin/AdminSegmentsView.vue'),
      },
      {
        path: 'flight-classes',
        name: 'admin-flight-classes',
        component: () => import('../views/admin/AdminFlightClassesView.vue'),
      },
      {
        path: 'users',
        name: 'admin-users',
        component: () => import('../views/admin/AdminUsersView.vue'),
      },
      {
        path: 'reservations',
        name: 'admin-reservations',
        component: () => import('../views/admin/AdminReservationsView.vue'),
      },
      {
        path: 'payments',
        name: 'admin-payments',
        component: () => import('../views/admin/AdminPaymentsView.vue'),
      },
      {
        path: 'invoices',
        name: 'admin-invoices',
        component: () => import('../views/admin/AdminInvoicesView.vue'),
      },
      {
        path: 'boarding-passes',
        name: 'admin-boarding-passes',
        component: () => import('../views/admin/AdminBoardingPassesView.vue'),
      },
      {
        path: 'promotions',
        name: 'admin-promotions',
        component: () => import('../views/admin/AdminPromotionsView.vue'),
      },
      {
        path: 'services',
        name: 'admin-services',
        component: () => import('../views/admin/AdminServicesView.vue'),
      },
      {
        path: 'airline-service-configs',
        name: 'admin-airline-service-configs',
        component: () => import('../views/admin/AdminAirlineServiceConfigsView.vue'),
      },
      {
        path: 'airline-airports',
        name: 'admin-airline-airports',
        component: () => import('../views/admin/AdminAirlineAirportsView.vue'),
      },
      {
        path: 'billing-profiles',
        name: 'admin-billing-profiles',
        component: () => import('../views/admin/AdminBillingProfilesView.vue'),
      },
      {
        path: 'invoice-items',
        name: 'admin-invoice-items',
        component: () => import('../views/admin/AdminInvoiceItemsView.vue'),
      },
      {
        path: 'passenger-services',
        name: 'admin-passenger-services',
        component: () => import('../views/admin/AdminPassengerServicesView.vue'),
      },
      {
        path: 'reservation-passengers',
        name: 'admin-reservation-passengers',
        component: () => import('../views/admin/AdminReservationPassengersView.vue'),
      },
      {
        path: 'audit',
        name: 'admin-audit',
        component: () => import('../views/admin/AdminAuditView.vue'),
      },
    ],
  },

  // Fallback (Redirección si la ruta no existe)
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// Guardas de Navegación reactivas
router.beforeEach((to, _from, next) => {
  const authStore = useAuthStore();
  const authenticated = authStore.isAuthenticated;
  const isAdmin = authStore.isAdmin;

  if (to.matched.some((record) => record.meta.requiresAuth)) {
    if (!authenticated) {
      next({ name: 'login' });
    } else {
      next();
    }
  } else if (to.matched.some((record) => record.meta.requiresGuest)) {
    if (authenticated) {
      next({ name: 'home' });
    } else {
      next();
    }
  } else if (to.matched.some((record) => record.meta.requiresAdmin)) {
    if (!authenticated) {
      next({ name: 'login' });
    } else if (!isAdmin) {
      next({ name: 'home' });
    } else {
      next();
    }
  } else {
    next();
  }
});

export default router;

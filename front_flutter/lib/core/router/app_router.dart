import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../core/storage/token_storage.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/flights/screens/search_screen.dart';
import '../../features/reservations/screens/my_trips_screen.dart';
import '../../features/reservations/screens/reservation_detail_screen.dart';
import '../../features/reservations/screens/reservation_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/dashboard_screen.dart';
import '../../features/admin/screens/admin_crud_screen.dart';

final _publicRoutes = {'/login', '/register'};

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final token = await TokenStorage.read();
    final isPublic = _publicRoutes.contains(state.matchedLocation);
    if (token == null && !isPublic) return '/login';
    if (token != null && isPublic) return '/flights';
    return null;
  },
  routes: [
    GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/flights',  builder: (_, __) => const SearchScreen()),
    GoRoute(path: '/my-trips', builder: (_, __) => const MyTripsScreen()),
    GoRoute(
      path: '/my-trips/:id',
      builder: (_, s) => ReservationDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/reserve',
      builder: (_, s) => ReservationScreen(
        flightClassId: s.uri.queryParameters['flightClassId'] ?? '',
        price: double.tryParse(s.uri.queryParameters['price'] ?? '0') ?? 0,
      ),
    ),

    // ── Admin ──────────────────────────────────────────────
    ShellRoute(
      builder: (_, __, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/admin', builder: (_, __) => const DashboardScreen()),

        GoRoute(path: '/admin/countries', builder: (_, __) => const AdminCrudScreen(
          title: 'Países', endpoint: '/countries',
          columns: [
            AdminColumn('name',        'Nombre',   primary: true),
            AdminColumn('isoCode',     'ISO',      mono: true),
            AdminColumn('phoneCode',   'Teléfono'),
            AdminColumn('currencyCode','Moneda'),
          ],
        )),

        GoRoute(path: '/admin/cities', builder: (_, __) => const AdminCrudScreen(
          title: 'Ciudades', endpoint: '/cities',
          columns: [
            AdminColumn('name',        'Nombre',  primary: true),
            AdminColumn('countryId',   'País ID', mono: true),
          ],
        )),

        GoRoute(path: '/admin/airports', builder: (_, __) => const AdminCrudScreen(
          title: 'Aeropuertos', endpoint: '/airports',
          columns: [
            AdminColumn('iataCode', 'IATA', mono: true, primary: true),
            AdminColumn('name',     'Nombre'),
            AdminColumn('cityId',   'Ciudad ID', mono: true),
          ],
        )),

        GoRoute(path: '/admin/airlines', builder: (_, __) => const AdminCrudScreen(
          title: 'Aerolíneas', endpoint: '/airlines',
          columns: [
            AdminColumn('name',      'Nombre',    primary: true),
            AdminColumn('iataCode',  'IATA',      mono: true),
            AdminColumn('countryId', 'País ID',   mono: true),
          ],
        )),

        GoRoute(path: '/admin/aircraft', builder: (_, __) => const AdminCrudScreen(
          title: 'Aviones', endpoint: '/aircraft',
          columns: [
            AdminColumn('model',       'Modelo',     primary: true),
            AdminColumn('manufacturer','Fabricante'),
            AdminColumn('totalSeats',  'Asientos'),
            AdminColumn('airlineId',   'Aerolínea',  mono: true),
          ],
        )),

        GoRoute(path: '/admin/flights', builder: (_, __) => const AdminCrudScreen(
          title: 'Vuelos', endpoint: '/flights',
          columns: [
            AdminColumn('flightNumber',  'Número',      mono: true, primary: true),
            AdminColumn('status',        'Estado'),
            AdminColumn('departureTime', 'Salida'),
            AdminColumn('arrivalTime',   'Llegada'),
          ],
        )),

        GoRoute(path: '/admin/reservations', builder: (_, __) => const AdminCrudScreen(
          title: 'Reservas', endpoint: '/reservations',
          columns: [
            AdminColumn('reservationCode', 'Código',  mono: true, primary: true),
            AdminColumn('status',          'Estado'),
            AdminColumn('totalAmount',     'Total'),
            AdminColumn('createdAt',       'Fecha'),
          ],
        )),

        GoRoute(path: '/admin/payments', builder: (_, __) => const AdminCrudScreen(
          title: 'Pagos', endpoint: '/payments',
          columns: [
            AdminColumn('id',       'ID',       mono: true, primary: true),
            AdminColumn('provider', 'Proveedor'),
            AdminColumn('amount',   'Monto'),
            AdminColumn('status',   'Estado'),
          ],
        )),

        GoRoute(path: '/admin/users', builder: (_, __) => const AdminCrudScreen(
          title: 'Usuarios', endpoint: '/users',
          columns: [
            AdminColumn('email',     'Correo',  primary: true),
            AdminColumn('firstName', 'Nombre'),
            AdminColumn('lastName',  'Apellido'),
            AdminColumn('role',      'Rol'),
          ],
        )),

        GoRoute(path: '/admin/promotions', builder: (_, __) => const AdminCrudScreen(
          title: 'Promociones', endpoint: '/promotions',
          columns: [
            AdminColumn('code',           'Código',    mono: true, primary: true),
            AdminColumn('discountAmount', 'Descuento'),
            AdminColumn('expiresAt',      'Vence'),
          ],
        )),

        GoRoute(path: '/admin/invoices', builder: (_, __) => const AdminCrudScreen(
          title: 'Facturas', endpoint: '/invoices',
          columns: [
            AdminColumn('invoiceNumber', 'Número',   mono: true, primary: true),
            AdminColumn('totalAmount',   'Total'),
            AdminColumn('issuedAt',      'Fecha'),
          ],
        )),

        GoRoute(path: '/admin/audit', builder: (_, __) => const AdminCrudScreen(
          title: 'Auditoría', endpoint: '/audit-logs',
          columns: [
            AdminColumn('action',    'Acción',  primary: true),
            AdminColumn('entity',    'Entidad'),
            AdminColumn('userId',    'Usuario', mono: true),
            AdminColumn('createdAt', 'Fecha'),
          ],
        )),
      ],
    ),
  ],

  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Página no encontrada: ${state.uri}')),
  ),
);
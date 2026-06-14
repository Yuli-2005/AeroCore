import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _flights = 0, _reservations = 0, _users = 0;
  double _revenue = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    Future<List> fetch(String path) async {
      try {
        final r = await dio.get(path);
        return r.data['data'] as List? ?? [];
      } catch (_) { return []; }
    }
    final flights      = await fetch('/flights');
    final reservations = await fetch('/reservations');
    final users        = await fetch('/users');
    final payments     = await fetch('/payments');
    setState(() {
      _flights      = flights.length;
      _reservations = reservations.where((r) => r['status'] != 'CANCELLED').length;
      _users        = users.length;
      _revenue      = payments.fold(0.0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
      _loading      = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel de administración',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Resumen del sistema · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 28),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _metricsGrid(),
            const SizedBox(height: 32),
            const Text('Acceso rápido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _catalogGrid(),
          ],
        ],
      ),
    );
  }

  Widget _metricsGrid() {
    final metrics = [
      ('Total vuelos',          '$_flights',            Icons.flight,      AppColors.primaryDark),
      ('Reservas activas',      '$_reservations',       Icons.book_online, AppColors.emerald),
      ('Ingresos estimados',    '\$${_revenue.toStringAsFixed(0)}', Icons.attach_money, AppColors.amber),
      ('Usuarios registrados',  '$_users',              Icons.people,      AppColors.purple),
    ];
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 700 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5,
        children: metrics.map((m) => _metricCard(m.$1, m.$2, m.$3, m.$4)).toList(),
      );
    });
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ],
    ),
  );

  Widget _catalogGrid() {
    final items = [
      ('Países',     Icons.public,          '/admin/countries'),
      ('Ciudades',   Icons.location_city,   '/admin/cities'),
      ('Aeropuertos',Icons.flight_takeoff,  '/admin/airports'),
      ('Aerolíneas', Icons.airline_seat_recline_normal, '/admin/airlines'),
      ('Aviones',    Icons.airplanemode_active, '/admin/aircraft'),
      ('Vuelos',     Icons.flight,          '/admin/flights'),
      ('Reservas',   Icons.book_online,     '/admin/reservations'),
      ('Pagos',      Icons.payment,         '/admin/payments'),
      ('Usuarios',   Icons.people,          '/admin/users'),
      ('Auditoría',  Icons.history,         '/admin/audit'),
      ('Promociones',Icons.local_offer,     '/admin/promotions'),
      ('Facturas',   Icons.receipt_long,    '/admin/invoices'),
    ];
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 700 ? 6 : 3;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
        children: items.map((i) => _catalogCard(i.$1, i.$2, i.$3)).toList(),
      );
    });
  }

  Widget _catalogCard(String label, IconData icon, String route) => AppCard(
    padding: const EdgeInsets.all(12),
    child: InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.gradientButton,
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B))),
        ],
      ),
    ),
  );
}
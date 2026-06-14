import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_navbar.dart';
import '../../../shared/widgets/app_theme.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});
  @override State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  List<Reservation> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await dio.get('/reservations/my');
      final list = res.data['data'] as List<dynamic>? ?? [];
      setState(() => _reservations = list.map((r) => Reservation.fromJson(r)).toList());
    } catch (_) {
      setState(() => _error = 'Error al cargar tus viajes');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppNavbar(title: 'Mis viajes'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _reservations.isEmpty
                  ? _emptyState()
                  : _list(),
    );
  }

  Widget _list() {
    return Column(
      children: [
        // Header oscuro
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)]),
          ),
          child: Row(children: [
            const Text('Mis reservas',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${_reservations.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _reservations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ReservationCard(
                reservation: _reservations[i],
                onTap: () => context.push('/my-trips/${_reservations[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.flight_outlined, size: 80, color: Color(0xFFCBD5E1)),
      const SizedBox(height: 16),
      const Text('Aún no tienes viajes reservados',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      const SizedBox(height: 8),
      const Text('Busca y reserva tu primer vuelo',
        style: TextStyle(color: Color(0xFF94A3B8))),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => context.go('/flights'),
        icon: const Icon(Icons.search),
        label: const Text('Buscar vuelos'),
      ),
    ]),
  );

  Widget _errorState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 60, color: AppColors.red),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppColors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _load, child: const Text('Reintentar')),
    ]),
  );
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;
  const _ReservationCard({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = reservation.flight;
    return AppCard(
      padding: const EdgeInsets.all(0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: código + estado
              Row(children: [
                Text(reservation.reservationCode,
                  style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const Spacer(),
                StatusBadge.fromStatus(reservation.status),
              ]),
              const SizedBox(height: 14),
              // Ruta
              if (f != null) Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.origin.iataCode, style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    Text(f.origin.cityName ?? '', style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.purple],
                      ).createShader(b),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.destination.iataCode, style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    Text(f.destination.cityName ?? '', style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  const Spacer(),
                  Text('\$${reservation.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1))),
                ],
              ),
              const SizedBox(height: 12),
              // Footer
              Row(children: [
                const Icon(Icons.people_outline, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('${reservation.passengers.length} pasajero${reservation.passengers.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const Spacer(),
                const Text('Ver detalle →',
                  style: TextStyle(fontSize: 13, color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/boarding_pass_pdf.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_theme.dart';

class ReservationDetailScreen extends StatefulWidget {
  final String id;
  const ReservationDetailScreen({super.key, required this.id});
  @override State<ReservationDetailScreen> createState() => _State();
}

class _State extends State<ReservationDetailScreen> {
  Reservation? _reservation;
  Map?     _payment;
  Invoice? _invoice;
  bool _loading        = true;
  bool _downloadingPdf = false;
  String? _error;
  final Set<String> _expandedSeats = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _reservation = Reservation.fromJson(
        (await dio.get('/reservations/${widget.id}')).data['data']);
      try {
        final pr = await dio.get('/payments/by-reservation/${widget.id}');
        final list = pr.data['data'];
        if (list is List && list.isNotEmpty) {
          _payment = list[0];
          try {
            final ir = await dio.get('/invoices/by-payment/${_payment!['id']}');
            _invoice = Invoice.fromJson(ir.data['data']);
          } catch (_) {}
        }
      } catch (_) {}
      setState(() {});
    } catch (_) {
      setState(() => _error = 'No se pudo cargar la reserva');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_reservation == null) return;
    setState(() => _downloadingPdf = true);
    try {
      await printBoardingPasses(_reservation!, invoice: _invoice);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar el PDF'),
              backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('¿Seguro que deseas cancelar esta reserva? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await dio.delete('/reservations/${widget.id}');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar'), backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _changeSeat(Passenger pax, String newSeat) async {
    try {
      await dio.patch(
        '/reservations/${widget.id}/passengers/${pax.id}/seat',
        data: {'seatNumber': newSeat},
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asiento no disponible'), backgroundColor: AppColors.red));
      }
    }
  }

  // ── helpers ──────────────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null || iso.length < 10) return '';
    final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  String _formatDateTime(String dt) {
    if (dt.length < 16) return dt;
    final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    try {
      final d = DateTime.parse(dt);
      return '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return dt.substring(0, 16); }
  }

  String _cabinLabel(String? c) {
    if (c == 'FIRST')    return 'Primera Clase';
    if (c == 'BUSINESS') return 'Business';
    return 'Económica';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _body(),
    );
  }

  Widget _errorView() => Scaffold(
    appBar: AppBar(title: const Text('Detalle de reserva')),
    body: Center(child: Text(_error!, style: const TextStyle(color: AppColors.red))),
  );

  Widget _body() {
    final r = _reservation!;
    final f = r.flight;
    return CustomScrollView(
      slivers: [
        _header(r, f),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (f != null) ...[
                _flightInfoCard(f),
                const SizedBox(height: 16),
              ],
              _boardingPassSection(r, f),
              const SizedBox(height: 16),
              _passengersSection(r),
              const SizedBox(height: 16),
              if (_payment != null) _paymentCard(),
              const SizedBox(height: 16),
              if (r.status == 'CONFIRMED')
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.red),
                  label: const Text('Cancelar reserva',
                    style: TextStyle(color: AppColors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Header oscuro con ruta, código y fecha ───────────────────
  SliverAppBar _header(Reservation r, Flight? f) {
    final dateStr = _formatDate(r.createdAt);
    final originCity = f?.origin.cityName ?? f?.origin.name ?? '';
    final destCity   = f?.destination.cityName ?? f?.destination.name ?? '';
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.canPop() ? context.pop() : context.go('/my-trips'),
      ),
      title: TextButton(
        onPressed: () => context.go('/my-trips'),
        child: const Text('Mis viajes',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      ),
      titleSpacing: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)])),
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (f != null)
                  Text('${f.origin.iataCode} → ${f.destination.iataCode}',
                    style: const TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Text(r.reservationCode,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13, fontFamily: 'monospace')),
                const Spacer(),
                StatusBadge.fromStatus(r.status),
              ]),
              if (dateStr.isNotEmpty || originCity.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [if (dateStr.isNotEmpty) dateStr,
                   if (originCity.isNotEmpty && destCity.isNotEmpty)
                     '$originCity → $destCity']
                  .join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Card "Información del vuelo" ─────────────────────────────
  Widget _flightInfoCard(Flight f) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bolt, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        const Text('Información del vuelo',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 16),
      // Horarios + ruta
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        // Origen
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.depTime.isEmpty ? '--:--' : f.depTime,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B))),
          Text(f.origin.iataCode,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
          Text(f.origin.cityName ?? f.origin.name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
        // Línea central
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 1.5,
                decoration: const BoxDecoration(gradient: AppColors.gradient))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.flight, color: AppColors.primary, size: 18)),
              Expanded(child: Container(height: 1.5,
                decoration: const BoxDecoration(gradient: AppColors.gradient))),
            ]),
            const SizedBox(height: 4),
            const Text('Vuelo directo',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            if (f.airlineName.isNotEmpty)
              Text(f.airlineName,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600)),
          ]),
        ),
        // Destino
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(f.arrTime.isEmpty ? '--:--' : f.arrTime,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B))),
          Text(f.destination.iataCode,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
          Text(f.destination.cityName ?? f.destination.name,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      ]),
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 12),
      // Fechas completas
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Salida', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(_formatDateTime(f.departureTime),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B))),
        ])),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Llegada', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(_formatDateTime(f.arrivalTime),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B))),
        ])),
      ]),
    ]),
  );

  // ── Sección "Pase de Abordar" ────────────────────────────────
  Widget _boardingPassSection(Reservation r, Flight? f) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Icon(Icons.confirmation_num_outlined, size: 16, color: Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        const Text('Pase de Abordar',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B))),
        const Spacer(),
        _downloadingPdf
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : FilledButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('Imprimir / Guardar PDF',
                style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
      ]),
      const SizedBox(height: 12),
      ...r.passengers.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _boardingPassCard(r, p, f),
      )),
    ],
  );

  Widget _boardingPassCard(Reservation r, Passenger p, Flight? f) {
    final qrData = '${r.reservationCode}|${p.fullName}|${p.seatNumber ?? 'TBD'}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [BoxShadow(
          color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            // Logo + label
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                gradient: AppColors.gradientButton,
                borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.flight, color: Colors.white, size: 12)),
            const SizedBox(width: 6),
            const Text('AeroCore',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B))),
            const SizedBox(width: 4),
            const Text('TARJETA DE ABORDAJE',
              style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8),
                letterSpacing: 0.8)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('CÓDIGO DE RESERVA',
                style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8),
                  letterSpacing: 0.6)),
              Text(r.reservationCode,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B), fontFamily: 'monospace')),
            ]),
          ]),
        ),
        const Divider(height: 1),
        // Cuerpo principal
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Lado izquierdo — info del vuelo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Ruta IATA grande
                  if (f != null) Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.origin.iataCode,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B))),
                        Text(f.origin.cityName ?? f.origin.name,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ]),
                      Column(children: [
                        const Text('- - ✈ - -',
                          style: TextStyle(fontSize: 12, color: AppColors.primary,
                            letterSpacing: 2)),
                        if (f.airlineName.isNotEmpty)
                          Text(f.airlineName,
                            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(f.destination.iataCode,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B))),
                        Text(f.destination.cityName ?? f.destination.name,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Grid de datos del pasajero
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(children: [
                        _gridLabel('PASAJERO'),
                        _gridLabel('FECHA Y HORA'),
                        _gridLabel('CLASE'),
                        _gridLabel('ASIENTO'),
                      ]),
                      TableRow(children: [
                        const SizedBox(height: 4),
                        const SizedBox(height: 4),
                        const SizedBox(height: 4),
                        const SizedBox(height: 4),
                      ]),
                      TableRow(children: [
                        _gridValue(p.fullName),
                        _gridValue(f != null
                          ? _formatDateTime(f.departureTime) : '—'),
                        _gridValue(_cabinLabel(p.cabinClass)),
                        _gridValue(p.seatNumber ?? 'N/A'),
                      ]),
                    ],
                  ),
                ]),
              ),
            ),
            // Separador dentado
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(10, (_) => Container(
                width: 1, height: 7,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: const Color(0xFFCBD5E1))),
            ),
            // Lado derecho — QR + asiento
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(16))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('TALÓN DE EMBARQUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 7, color: Color(0xFF94A3B8),
                      letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(p.fullName.split(' ').first,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 80,
                    backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  const Text('ASIENTO',
                    style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8),
                      letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(p.seatNumber ?? 'N/A',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark)),
                ],
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _gridLabel(String t) => Text(t,
    style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8), letterSpacing: 0.6));

  Widget _gridValue(String t) => Text(t,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: Color(0xFF1E293B)));

  // ── Sección pasajeros y asientos ────────────────────────────
  Widget _passengersSection(Reservation r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Icon(Icons.people_outline, size: 16, color: Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        const Text('Pasajeros y asientos',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12)),
          child: Text('${r.passengers.length} pasajero${r.passengers.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
      ]),
      const SizedBox(height: 10),
      ...r.passengers.map((p) => _passengerRow(r, p)),
    ],
  );

  Widget _passengerRow(Reservation r, Passenger p) {
    final expanded = _expandedSeats.contains(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_outline,
                color: AppColors.primary, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(p.documentNumber,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
            ),
            if (p.cabinClass != null) ...[
              _badge(_cabinLabel(p.cabinClass),
                const Color(0xFFEFF6FF), AppColors.primary),
              const SizedBox(width: 6),
            ],
            if (p.seatNumber != null) ...[
              _badge(p.seatNumber!, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
              const SizedBox(width: 6),
            ],
            if (r.status == 'CONFIRMED')
              GestureDetector(
                onTap: () => setState(() {
                  if (expanded) { _expandedSeats.remove(p.id); }
                  else          { _expandedSeats.add(p.id); }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    const Text('Cambiar',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                ),
              ),
          ]),
        ),
        if (expanded) _SeatPickerMap(
          reservationId: r.id,
          passenger: p,
          onSeatSelected: (seat) {
            _changeSeat(p, seat);
            setState(() => _expandedSeats.remove(p.id));
          },
        ),
      ]),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, color: fg)));

  // ── Card de pago + factura ────────────────────────────────────
  Widget _paymentCard() {
    final p = _payment!;
    final inv = _invoice;
    final provider = p['provider'] as String? ?? '';
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_circle_outline,
              color: AppColors.emerald, size: 20)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pago realizado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Pagado con $provider',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          Text(
            '\$${(double.tryParse((p['amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
              color: AppColors.primary)),
        ]),
        if (inv != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.receipt_long_outlined,
                  size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('Factura #${inv.invoiceNumber}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(inv.createdAt.length >= 10 ? inv.createdAt.substring(0, 10) : '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _invRow('Subtotal', '\$${inv.subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              _invRow('IVA 15%', '\$${inv.taxAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _invRow('Total', '\$${inv.total.toStringAsFixed(2)}',
                bold: true, color: AppColors.primary),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
            const SizedBox(width: 8),
            Text('Factura en proceso de generación...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ]),
        ],
      ]),
    );
  }

  Widget _invRow(String label, String value,
      {bool bold = false, Color? color}) =>
    Row(children: [
      Text(label, style: TextStyle(
        fontSize: 12,
        color: bold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      const Spacer(),
      Text(value, style: TextStyle(
        fontSize: bold ? 14 : 12,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? const Color(0xFF1E293B))),
    ]);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [BoxShadow(
        color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
    ),
    child: child,
  );
}

// ── Mapa visual de asientos ───────────────────────────────────
class _SeatPickerMap extends StatefulWidget {
  final String reservationId;
  final Passenger passenger;
  final ValueChanged<String> onSeatSelected;
  const _SeatPickerMap({
    required this.reservationId,
    required this.passenger,
    required this.onSeatSelected,
  });
  @override State<_SeatPickerMap> createState() => _SeatPickerMapState();
}

class _SeatPickerMapState extends State<_SeatPickerMap> {
  Set<String> _occupied = {};
  bool _loadingSeats = true;

  @override
  void initState() { super.initState(); _loadOccupied(); }

  Future<void> _loadOccupied() async {
    final fcId = widget.passenger.flightClassId;
    if (fcId == null) { setState(() => _loadingSeats = false); return; }
    try {
      final res = await dio.get(
        '/reservations/flight-classes/$fcId/occupied-seats');
      final list = res.data['data'];
      if (list is List && mounted) {
        setState(() => _occupied = list.whereType<String>().toSet());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSeats = false);
  }

  @override
  Widget build(BuildContext context) {
    final cabin  = widget.passenger.cabinClass ?? 'ECONOMY';
    final mySlot = widget.passenger.seatNumber;

    if (_loadingSeats) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final cols  = cabin == 'ECONOMY'  ? ['A','B','C','D','E','F']
                : cabin == 'BUSINESS' ? ['A','B','C','D']
                :                       ['A','B'];
    final rows  = cabin == 'ECONOMY'  ? 21
                : cabin == 'BUSINESS' ? 8 : 6;
    final aisle = cabin == 'ECONOMY'  ? 3 : 2;
    final avail = (rows * cols.length) - _occupied.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        // Leyenda
        Row(children: [
          Text('ASIENTO PARA ${widget.passenger.firstName.toUpperCase()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B), letterSpacing: 0.5)),
          const Spacer(),
          _legend(AppColors.primary, 'Tu asiento'),
          const SizedBox(width: 8),
          _legend(const Color(0xFFFCA5A5), 'Ocupado'),
          const SizedBox(width: 8),
          _legend(const Color(0xFFE2E8F0), 'Libre'),
        ]),
        const SizedBox(height: 4),
        // Stats
        Row(children: [
          _statBadge(avail, const Color(0xFF059669), 'libres'),
          const SizedBox(width: 8),
          _statBadge(_occupied.length, const Color(0xFFEF4444), 'ocupados'),
        ]),
        const SizedBox(height: 10),
        // Nariz
        Center(child: Container(
          width: 60, height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: const Color(0xFFBFDBFE))),
          child: const Center(child: Icon(Icons.flight,
            color: AppColors.primary, size: 14)))),
        const SizedBox(height: 6),
        // Letras columnas
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 28),
          ...cols.asMap().entries.expand((e) sync* {
            yield SizedBox(width: 32,
              child: Center(child: Text(e.value,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B)))));
            if (e.key == aisle - 1) yield const SizedBox(width: 16);
          }),
        ]),
        const SizedBox(height: 4),
        // Filas
        ...List.generate(rows, (ri) {
          final rowNum = ri + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 28,
                child: Text('$rowNum',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600))),
              ...cols.asMap().entries.expand((e) sync* {
                final seatId    = '$rowNum${e.value}';
                final isOccupied = _occupied.contains(seatId);
                final isMine     = mySlot == seatId;

                final bg = isMine     ? AppColors.primary
                         : isOccupied ? const Color(0xFFFEE2E2)
                         :              Colors.white;
                final border = isMine     ? AppColors.primaryDark
                             : isOccupied ? const Color(0xFFFCA5A5)
                             :              const Color(0xFFCBD5E1);

                yield GestureDetector(
                  onTap: isOccupied ? null : () => widget.onSeatSelected(seatId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 30, height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: border,
                        width: isMine ? 2 : 1)),
                    child: Center(child: isMine
                      ? const Icon(Icons.person, color: Colors.white, size: 12)
                      : isOccupied
                          ? const Icon(Icons.close,
                              color: Color(0xFFEF4444), size: 10)
                          : null),
                  ),
                );
                if (e.key == aisle - 1) yield const SizedBox(width: 16);
              }),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5)))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
  ]);

  Widget _statBadge(int n, Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8)),
    child: Text('$n $label',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
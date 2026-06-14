import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/boarding_pass_pdf.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_navbar.dart';
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
  bool _loading       = true;
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
          // Cargar factura vinculada al pago
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppNavbar(title: 'Detalle de reserva', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _body(),
    );
  }

  Widget _body() {
    final r = _reservation!;
    final f = r.flight;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header con gradiente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (f != null)
                Text('${f.origin.iataCode} → ${f.destination.iataCode}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                Text(r.reservationCode,
                  style: TextStyle(fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(width: 12),
                StatusBadge.fromStatus(r.status),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vuelo
                if (f != null) _flightCard(f),
                const SizedBox(height: 16),
                // Boarding passes
                Row(children: [
                  const Text('Tarjetas de abordaje',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _downloadingPdf
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('Descargar PDF'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                ]),
                const SizedBox(height: 12),
                ...r.passengers.map((p) => _boardingPass(r, p, f)),
                const SizedBox(height: 16),
                // Pasajeros + asientos
                const Text('Pasajeros',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...r.passengers.map((p) => _passengerCard(r, p)),
                const SizedBox(height: 16),
                // Pago
                if (_payment != null) _paymentCard(),
                const SizedBox(height: 16),
                // Cancelar
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flightCard(Flight f) => AppCard(
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Column(children: [
          Text(f.depTime, style: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
          Text(f.origin.iataCode, style: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          Text(f.origin.cityName ?? '', style: const TextStyle(
            fontSize: 12, color: Color(0xFF64748B))),
        ]),
        Column(children: [
          const Icon(Icons.flight, color: AppColors.primary),
          Container(height: 2, width: 60,
            decoration: const BoxDecoration(gradient: AppColors.gradient)),
          Text(f.airlineName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
        Column(children: [
          Text(f.arrTime, style: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
          Text(f.destination.iataCode, style: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          Text(f.destination.cityName ?? '', style: const TextStyle(
            fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ]),
    ]),
  );

  Widget _boardingPass(Reservation r, Passenger p, Flight? f) {
    final qrData = '${r.reservationCode}|${p.fullName}|${p.seatNumber ?? 'TBD'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 12)],
      ),
      child: Row(children: [
        // Izquierda
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientButton,
                    borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.flight, color: Colors.white, size: 14)),
                const SizedBox(width: 8),
                const Text('Tarjeta de Abordaje',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
              ]),
              const SizedBox(height: 12),
              if (f != null) Row(children: [
                Text(f.origin.iataCode, style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: AppColors.primary, size: 18)),
                Text(f.destination.iataCode, style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
              ]),
              const SizedBox(height: 12),
              _infoRow('Pasajero', p.fullName),
              _infoRow('Documento', p.documentNumber),
              if (p.cabinClass != null) _infoRow('Clase', p.cabinClass!),
              if (p.seatNumber != null) _infoRow('Asiento', p.seatNumber!),
            ]),
          ),
        ),
        // Separador dentado
        Column(children: List.generate(8, (_) => Container(
          width: 1, height: 6, margin: const EdgeInsets.symmetric(vertical: 2),
          color: const Color(0xFFCBD5E1)))),
        // Derecha — QR
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            QrImageView(data: qrData, version: QrVersions.auto, size: 90,
              backgroundColor: Colors.white),
            const SizedBox(height: 8),
            if (p.seatNumber != null)
              Text(p.seatNumber!, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w900,
                color: AppColors.primaryDark)),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _passengerCard(Reservation r, Passenger p) {
    final expanded = _expandedSeats.contains(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        ListTile(
          title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Doc: ${p.documentNumber}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (p.seatNumber != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(p.seatNumber!, style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w700,
                  color: AppColors.primary))),
            const SizedBox(width: 8),
            if (r.status == 'CONFIRMED')
              TextButton(
                onPressed: () => setState(() {
                  if (expanded) { _expandedSeats.remove(p.id); }
                  else          { _expandedSeats.add(p.id); }
                }),
                child: Text(expanded ? 'Cerrar' : 'Cambiar asiento',
                  style: const TextStyle(fontSize: 12)),
              ),
          ]),
        ),
        if (expanded) _SeatPicker(
          reservationId: r.id,
          passenger: p,
          flightClassId: r.passengers.first.id,
          onSeatSelected: (seat) {
            _changeSeat(p, seat);
            setState(() => _expandedSeats.remove(p.id));
          },
        ),
      ]),
    );
  }

  Widget _paymentCard() {
    final p = _payment!;
    final inv = _invoice;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Título + proveedor
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_circle, color: AppColors.emerald, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pago realizado',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text('Pagado con ${p['provider'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          Text('\$${(p['amount'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
        ]),
        // Factura (si existe)
        if (inv != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('Factura #${inv.invoiceNumber}',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const Spacer(),
                Text(inv.createdAt.length >= 10 ? inv.createdAt.substring(0, 10) : '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _invRow('Subtotal',   '\$${inv.subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              _invRow('IVA 15%',    '\$${inv.taxAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _invRow('Total', '\$${inv.total.toStringAsFixed(2)}',
                bold: true, color: const Color(0xFF6366F1)),
            ]),
          ),
        ] else if (p['invoiceNumber'] != null) ...[
          const SizedBox(height: 8),
          Text('Factura #${p['invoiceNumber']}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ] else ...[
          const SizedBox(height: 8),
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

  Widget _invRow(String label, String value, {bool bold = false, Color? color}) =>
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
}

class _SeatPicker extends StatefulWidget {
  final String reservationId, flightClassId;
  final Passenger passenger;
  final ValueChanged<String> onSeatSelected;
  const _SeatPicker({required this.reservationId, required this.passenger,
    required this.flightClassId, required this.onSeatSelected});
  @override State<_SeatPicker> createState() => _SeatPickerState();
}

class _SeatPickerState extends State<_SeatPicker> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(children: [
        const Divider(),
        const Text('Escribe el número de asiento',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Ej: 14C',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              final s = _ctrl.text.trim().toUpperCase();
              if (s.isNotEmpty) widget.onSeatSelected(s);
            },
            child: const Text('Asignar'),
          ),
        ]),
      ]),
    );
  }
}
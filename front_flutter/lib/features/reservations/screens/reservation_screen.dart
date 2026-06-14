import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/boarding_pass_pdf.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_theme.dart';

class ReservationScreen extends StatefulWidget {
  final String flightClassId;
  final double price;
  const ReservationScreen({super.key, required this.flightClassId, required this.price});
  @override State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  int _step = 0;

  // Step 1 — pasajeros
  final List<Map<String, TextEditingController>> _paxControllers = [];
  final _promoCtrl = TextEditingController();
  double? _discount;
  String? _promoError;
  bool _validatingPromo = false;

  // Step 2 — pago
  final _cardNameCtrl   = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl     = TextEditingController();
  final _cvvCtrl        = TextEditingController();
  String _provider = 'VISA';
  bool _paying = false;
  String? _payError;

  // Step 3 — asientos
  int _currentPax = 0;
  final List<String?> _seats = [];

  // Step 4 — resultado
  Reservation? _reservation;
  bool _downloadingPdf = false;

  String? _globalError;

  @override
  void initState() {
    super.initState();
    _addPassenger();
  }

  void _addPassenger() {
    _paxControllers.add({
      'firstName':      TextEditingController(),
      'lastName':       TextEditingController(),
      'documentNumber': TextEditingController(),
    });
    _seats.add(null);
    setState(() {});
  }

  void _removePassenger(int i) {
    if (_paxControllers.length <= 1) return;
    for (final c in _paxControllers[i].values) { c.dispose(); }
    _paxControllers.removeAt(i);
    _seats.removeAt(i);
    setState(() {});
  }

  double get _subtotal => widget.price * _paxControllers.length;
  double get _tax      => (_subtotal - (_discount ?? 0)) * 0.15;
  double get _total    => _subtotal - (_discount ?? 0) + _tax;

  Future<void> _validatePromo() async {
    setState(() { _validatingPromo = true; _promoError = null; _discount = null; });
    try {
      final res = await dio.post('/promotions/validate', data: {
        'code': _promoCtrl.text.trim(),
        'baseAmount': _subtotal,
      });
      setState(() => _discount = (res.data['data']?['discountAmount'] ?? 0).toDouble());
    } catch (_) {
      setState(() => _promoError = 'Código inválido o expirado');
    } finally {
      setState(() => _validatingPromo = false);
    }
  }

  Future<void> _submitStep1() async {
    for (final p in _paxControllers) {
      if (p['firstName']!.text.isEmpty || p['lastName']!.text.isEmpty ||
          p['documentNumber']!.text.isEmpty) {
        setState(() => _globalError = 'Completa todos los datos de los pasajeros');
        return;
      }
    }
    setState(() { _globalError = null; _step = 1; });
  }

  Future<void> _submitPayment() async {
    if (_cardNameCtrl.text.isEmpty || _cardNumberCtrl.text.isEmpty ||
        _expiryCtrl.text.isEmpty || _cvvCtrl.text.isEmpty) {
      setState(() => _payError = 'Completa todos los datos de pago');
      return;
    }
    setState(() { _paying = true; _payError = null; });
    try {
      // 1. Crear reserva
      final resRes = await dio.post('/reservations', data: {
        'flightClassId': widget.flightClassId,
        'passengers': _paxControllers.map((p) => {
          'firstName':      p['firstName']!.text.trim(),
          'lastName':       p['lastName']!.text.trim(),
          'documentNumber': p['documentNumber']!.text.trim(),
        }).toList(),
        if (_promoCtrl.text.isNotEmpty) 'promotionCode': _promoCtrl.text.trim(),
      });
      _reservation = Reservation.fromJson(resRes.data['data']);

      // 2. Crear pago
      await dio.post('/payments', data: {
        'reservationId': _reservation!.id,
        'amount':        _total,
        'provider':      _provider,
        'transactionId': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      });
      setState(() { _step = 2; _currentPax = 0; });
    } catch (e) {
      setState(() => _payError = 'Error al procesar el pago. Intenta de nuevo.');
    } finally {
      setState(() => _paying = false);
    }
  }

  Future<void> _assignSeat(String seat) async {
    if (_reservation == null) return;
    final pax = _reservation!.passengers[_currentPax];
    try {
      await dio.patch(
        '/reservations/${_reservation!.id}/passengers/${pax.id}/seat',
        data: {'seatNumber': seat},
      );
      setState(() {
        _seats[_currentPax] = seat;
        if (_currentPax < _reservation!.passengers.length - 1) {
          _currentPax++;
        } else {
          // Todos asignados → actualizar reserva y paso 3 → 4
          _refreshReservation();
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asiento ocupado, elige otro'),
              backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _skipSeats() => _refreshReservation();

  Future<void> _downloadPdf() async {
    if (_reservation == null) return;
    setState(() => _downloadingPdf = true);
    try {
      await printBoardingPasses(_reservation!);
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

  Future<void> _refreshReservation() async {
    final res = await dio.get('/reservations/${_reservation!.id}');
    setState(() {
      _reservation = Reservation.fromJson(res.data['data']);
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navDark,
        foregroundColor: Colors.white,
        title: const Text('Nueva reserva'),
        leading: _step > 0 && _step < 3
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => setState(() => _step--))
            : null,
      ),
      body: Column(
        children: [
          if (_step < 3) _stepBar(),
          Expanded(child: [
            _step1Passengers(),
            _step2Payment(),
            _step3Seats(),
            _step4Success(),
          ][_step]),
        ],
      ),
    );
  }

  // ── Barra de pasos ────────────────────────────────────────
  Widget _stepBar() {
    final labels = ['Pasajeros', 'Pago', 'Asientos'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(height: 2,
              color: i ~/ 2 < _step ? AppColors.primary : const Color(0xFFE2E8F0)));
          }
          final idx = i ~/ 2;
          final done = idx < _step;
          final active = idx == _step;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? AppColors.primary : const Color(0xFFE2E8F0),
              ),
              child: Center(child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${idx + 1}', style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: active ? Colors.white : const Color(0xFF94A3B8)))),
            ),
            const SizedBox(height: 4),
            Text(labels[idx], style: TextStyle(
              fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              color: active ? AppColors.primary : const Color(0xFF94A3B8))),
          ]);
        }),
      ),
    );
  }

  // ── PASO 1: Pasajeros ─────────────────────────────────────
  Widget _step1Passengers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('Datos de pasajeros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addPassenger,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
            ),
          ]),
          const SizedBox(height: 16),
          ..._paxControllers.asMap().entries.map((e) => _passengerForm(e.key, e.value)),
          const SizedBox(height: 16),
          // Código promo
          const Text('Código de descuento (opcional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _promoCtrl,
              decoration: InputDecoration(
                hintText: 'DESCUENTO10',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: _promoError,
              ),
              textCapitalization: TextCapitalization.characters,
            )),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _validatingPromo ? null : _validatePromo,
              child: _validatingPromo
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Aplicar'),
            ),
          ]),
          if (_discount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                const SizedBox(width: 8),
                Text('Descuento aplicado: -\$${_discount!.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          _priceSummary(),
          const SizedBox(height: 16),
          if (_globalError != null) _errorBox(_globalError!),
          const SizedBox(height: 8),
          GradientButton(text: 'Continuar al pago', icon: Icons.arrow_forward,
            onPressed: _submitStep1),
        ],
      ),
    );
  }

  Widget _passengerForm(int i, Map<String, TextEditingController> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Pasajero ${i + 1}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (_paxControllers.length > 1)
            IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.red),
              onPressed: () => _removePassenger(i)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('Nombre', c['firstName']!)),
          const SizedBox(width: 10),
          Expanded(child: _field('Apellido', c['lastName']!)),
        ]),
        const SizedBox(height: 10),
        _field('Número de documento', c['documentNumber']!),
      ]),
    );
  }

  // ── PASO 2: Pago ──────────────────────────────────────────
  bool _showCardBack = false;

  Widget _step2Payment() {
    final providers = ['VISA', 'MASTERCARD', 'AMEX', 'PAYPAL'];
    final providerColors = {
      'VISA':       const Color(0xFF1A1F71),
      'MASTERCARD': const Color(0xFFEB001B),
      'AMEX':       const Color(0xFF007BC1),
      'PAYPAL':     const Color(0xFF003087),
    };
    final cardColor = providerColors[_provider]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta 3D con flip animado
          GestureDetector(
            onTap: () => setState(() => _showCardBack = !_showCardBack),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) {
                final rotate = Tween(begin: 0.0, end: 1.0).animate(anim);
                return AnimatedBuilder(
                  animation: rotate,
                  child: child,
                  builder: (_, c) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(3.14 * rotate.value),
                    child: c,
                  ),
                );
              },
              child: _showCardBack
                  ? _cardBack(cardColor)
                  : _cardFront(cardColor),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Toca la tarjeta para ver el reverso',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
          const SizedBox(height: 20),
          // Proveedor
          const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true, crossAxisCount: 4, childAspectRatio: 2.2,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: providers.map((p) => GestureDetector(
              onTap: () => setState(() => _provider = p),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _provider == p ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: _provider == p ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  color: _provider == p ? const Color(0xFFEFF6FF) : Colors.white,
                ),
                child: Center(child: Text(p, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _provider == p ? AppColors.primary : const Color(0xFF475569)))),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // Campos de tarjeta
          _fieldListen('Nombre del titular', _cardNameCtrl, (v) => setState(() {})),
          const SizedBox(height: 12),
          _fieldListen('Número de tarjeta', _cardNumberCtrl, (v) {
            setState(() {});
          }, inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ], keyboardType: TextInputType.number, maxLength: 19),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _fieldListen('MM/AA', _expiryCtrl, (v) => setState(() {}),
              inputFormatters: [_ExpiryFormatter()], maxLength: 5,
              keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field('CVV', _cvvCtrl,
              obscureText: true, maxLength: 4,
              keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          _priceSummary(),
          const SizedBox(height: 8),
          if (_payError != null) _errorBox(_payError!),
          const SizedBox(height: 8),
          GradientButton(text: 'Confirmar y pagar', icon: Icons.lock_outline,
            onPressed: _submitPayment, loading: _paying),
        ],
      ),
    );
  }

  // ── PASO 3: Asientos ──────────────────────────────────────
  final Set<String> _occupiedSeats = {};

  Widget _step3Seats() {
    if (_reservation == null) return const SizedBox();
    final passengers = _reservation!.passengers;
    final cabin = passengers.first.cabinClass ?? 'ECONOMY';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Selección de asientos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Opcional — puedes omitir y asignar después',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          // Selector de pasajero
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: passengers.asMap().entries.map((e) {
              final idx = e.key; final pax = e.value;
              final selected = idx == _currentPax;
              return GestureDetector(
                onTap: () => setState(() => _currentPax = idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
                      width: selected ? 2 : 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_seats[idx] != null)
                      const Icon(Icons.check_circle, color: AppColors.emerald, size: 14)
                    else Text('${idx + 1}', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : const Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    Text(pax.firstName, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : const Color(0xFF1E293B))),
                  ]),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 20),
          // Mapa de asientos
          _SeatMapWidget(
            cabin: cabin,
            occupiedSeats: _occupiedSeats,
            mySeats: _seats.whereType<String>().toSet(),
            currentSeat: _seats[_currentPax],
            onSeatTap: _assignSeat,
          ),
          const SizedBox(height: 16),
          // Leyenda
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(const Color(0xFF3B82F6), 'Tu asiento'),
            const SizedBox(width: 16),
            _legend(const Color(0xFFE2E8F0), 'Ocupado'),
            const SizedBox(width: 16),
            _legend(Colors.white, 'Disponible', border: true),
          ]),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _skipSeats,
            child: const Text('Omitir — asignar después'),
          ),
        ],
      ),
    );
  }

  // ── PASO 4: Éxito ─────────────────────────────────────────
  Widget _step4Success() {
    if (_reservation == null) return const SizedBox();
    final r = _reservation!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de éxito
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0))),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.emerald, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 32)),
              const SizedBox(height: 16),
              const Text('¡Reserva confirmada!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46))),
              const SizedBox(height: 4),
              Text('Código: ${r.reservationCode}',
                style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 15, color: Color(0xFF059669))),
            ]),
          ),
          const SizedBox(height: 24),
          // Boarding passes
          const Text('Tarjetas de abordaje',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...r.passengers.map((p) => _boardingPassCard(r, p)),
          const SizedBox(height: 20),
          // Botón PDF
          OutlinedButton.icon(
            onPressed: _downloadingPdf ? null : _downloadPdf,
            icon: _downloadingPdf
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_downloadingPdf ? 'Generando PDF...' : 'Descargar tarjetas de abordaje (PDF)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GradientButton(
                text: 'Mis viajes', icon: Icons.card_travel,
                onPressed: () => context.go('/my-trips')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/flights'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Inicio'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _boardingPassCard(Reservation r, Passenger p) {
    final f = r.flight;
    final qrData = '${r.reservationCode}|${p.fullName}|${p.seatNumber ?? "TBD"}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 12)]),
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 26, height: 26,
                decoration: BoxDecoration(gradient: AppColors.gradientButton,
                  borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.flight, color: Colors.white, size: 13)),
              const SizedBox(width: 8),
              const Text('Tarjeta de Abordaje',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            ]),
            const SizedBox(height: 10),
            if (f != null) Row(children: [
              Text(f.origin.iataCode, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, color: AppColors.primary, size: 16)),
              Text(f.destination.iataCode, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
            ]),
            const SizedBox(height: 8),
            _mini('Pasajero', p.fullName),
            _mini('Documento', p.documentNumber),
            if (p.seatNumber != null) _mini('Asiento', p.seatNumber!),
            if (p.cabinClass != null) _mini('Clase', p.cabinClass!),
          ]),
        )),
        Column(children: List.generate(8, (_) => Container(
          width: 1, height: 6, margin: const EdgeInsets.symmetric(vertical: 2),
          color: const Color(0xFFCBD5E1)))),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            QrImageView(data: qrData, version: QrVersions.auto, size: 80,
              backgroundColor: Colors.white),
            if (p.seatNumber != null) ...[
              const SizedBox(height: 6),
              Text(p.seatNumber!, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w900,
                color: AppColors.primaryDark)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _priceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        _priceRow('Base (${_paxControllers.length} pax)',
            '\$${_subtotal.toStringAsFixed(2)}'),
        if (_discount != null && _discount! > 0)
          _priceRow('Descuento', '-\$${_discount!.toStringAsFixed(2)}',
            color: AppColors.emerald),
        _priceRow('IVA 15%', '\$${_tax.toStringAsFixed(2)}'),
        const Divider(height: 20),
        _priceRow('TOTAL', '\$${_total.toStringAsFixed(2)}', bold: true, large: true),
      ]),
    );
  }

  Widget _priceRow(String label, String value, {Color? color, bool bold = false, bool large = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(
          color: const Color(0xFF64748B), fontSize: large ? 15 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: large ? 18 : 13,
          color: color ?? (bold ? const Color(0xFF6366F1) : const Color(0xFF1E293B)))),
      ]),
    );

  Widget _mini(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Text('$l: ', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      Flexible(child: Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
    ]));

  // ── Tarjeta frente ────────────────────────────────────────
  Widget _cardFront(Color color) => Container(
    key: const ValueKey('front'),
    height: 190,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color, color.withValues(alpha: 0.75)]),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4),
        blurRadius: 24, offset: const Offset(0, 10))],
    ),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          // Chip dorado
          Container(width: 36, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.grid_view, color: Colors.white, size: 14)),
          const Spacer(),
          Text(_provider, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
            letterSpacing: 1)),
        ]),
        Text(_cardNumberCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberCtrl.text,
          style: const TextStyle(color: Colors.white, fontSize: 19,
            fontFamily: 'monospace', letterSpacing: 3)),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TITULAR', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(_cardNameCtrl.text.isEmpty ? 'TU NOMBRE' : _cardNameCtrl.text.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('VENCE', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(_expiryCtrl.text.isEmpty ? 'MM/AA' : _expiryCtrl.text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ]),
      ],
    ),
  );

  // ── Tarjeta reverso (CVV) ──────────────────────────────────
  Widget _cardBack(Color color) => Container(
    key: const ValueKey('back'),
    height: 190,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: [color.withValues(alpha: 0.75), color]),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4),
        blurRadius: 24, offset: const Offset(0, 10))],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 44, color: Colors.black.withValues(alpha: 0.4)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Expanded(child: Container(
              height: 36, color: Colors.white.withValues(alpha: 0.3),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('•' * (_cvvCtrl.text.length),
                style: const TextStyle(color: Colors.white,
                  letterSpacing: 4, fontSize: 16)))),
            const SizedBox(width: 12),
            Container(
              height: 36, width: 60,
              color: Colors.white,
              alignment: Alignment.center,
              child: Text(_cvvCtrl.text.isEmpty ? 'CVV' : _cvvCtrl.text,
                style: const TextStyle(fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B), fontSize: 14))),
          ]),
        ),
      ],
    ),
  );

  Widget _legend(Color color, String label, {bool border = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 16,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3),
          border: border ? Border.all(color: const Color(0xFFCBD5E1)) : null)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
    ],
  );

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFECACA))),
    child: Text(msg, style: const TextStyle(color: AppColors.red, fontSize: 13)));

  Widget _field(String label, TextEditingController ctrl,
      {bool obscureText = false, int? maxLength, TextInputType? keyboardType}) =>
    TextField(
      controller: ctrl, obscureText: obscureText,
      maxLength: maxLength, keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );

  Widget _fieldListen(String label, TextEditingController ctrl, ValueChanged<String> onChanged,
      {List<TextInputFormatter>? inputFormatters, TextInputType? keyboardType, int? maxLength}) =>
    TextField(
      controller: ctrl, onChanged: onChanged,
      inputFormatters: inputFormatters, keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
}

// ── Mapa visual de asientos ───────────────────────────────
class _SeatMapWidget extends StatelessWidget {
  final String cabin;
  final Set<String> occupiedSeats;
  final Set<String> mySeats;
  final String? currentSeat;
  final ValueChanged<String> onSeatTap;

  const _SeatMapWidget({
    required this.cabin,
    required this.occupiedSeats,
    required this.mySeats,
    required this.currentSeat,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    // Configuración según cabina (igual que Vue)
    final cols  = cabin == 'ECONOMY' ? ['A','B','C','D','E','F']
                : cabin == 'BUSINESS' ? ['A','B','C','D']
                : ['A','B','C','D'];
    final rows  = cabin == 'ECONOMY' ? 21
                : cabin == 'BUSINESS' ? 8
                : 6;
    final aisle = cabin == 'ECONOMY' ? 3 : 2; // índice donde va el pasillo

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Ícono avión
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.flight, color: AppColors.primaryDark, size: 28),
          ]),
          const SizedBox(height: 12),
          // Letras de columnas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 28), // espacio número de fila
              ...cols.asMap().entries.expand((e) {
                final widgets = <Widget>[
                  SizedBox(
                    width: 28,
                    child: Center(child: Text(e.value,
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
                  ),
                ];
                if (e.key == aisle - 1) widgets.add(const SizedBox(width: 16));
                return widgets;
              }),
            ],
          ),
          const SizedBox(height: 6),
          // Filas de asientos
          ...List.generate(rows, (rowIdx) {
            final rowNum = rowIdx + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Número de fila
                  SizedBox(width: 28,
                    child: Center(child: Text('$rowNum',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))))),
                  // Asientos
                  ...cols.asMap().entries.expand((e) {
                    final seatId = '$rowNum${e.value}';
                    final isOccupied = occupiedSeats.contains(seatId);
                    final isMine     = mySeats.contains(seatId);
                    final isCurrent  = currentSeat == seatId;

                    Color bg, border;
                    if (isCurrent || isMine) {
                      bg = AppColors.primary; border = AppColors.primaryDark;
                    } else if (isOccupied) {
                      bg = const Color(0xFFE2E8F0); border = const Color(0xFFCBD5E1);
                    } else {
                      bg = Colors.white; border = const Color(0xFFCBD5E1);
                    }

                    final widgets = <Widget>[
                      GestureDetector(
                        onTap: isOccupied ? null : () => onSeatTap(seatId),
                        child: Container(
                          width: 26, height: 22,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: border),
                          ),
                          child: isCurrent || isMine
                              ? const Icon(Icons.person, color: Colors.white, size: 12)
                              : null,
                        ),
                      ),
                    ];
                    if (e.key == aisle - 1) widgets.add(const SizedBox(width: 16));
                    return widgets;
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue n) {
    final digits = n.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return n.copyWith(text: str,
      selection: TextSelection.collapsed(offset: str.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue n) {
    final digits = n.text.replaceAll('/', '');
    if (digits.length <= 2) return n.copyWith(text: digits);
    final str = '${digits.substring(0, 2)}/${digits.substring(2)}';
    return n.copyWith(text: str, selection: TextSelection.collapsed(offset: str.length));
  }
}

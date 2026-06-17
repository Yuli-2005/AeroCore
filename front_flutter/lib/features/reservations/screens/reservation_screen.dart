import 'package:dio/dio.dart';
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
      // 1. Crear reserva (solo si aún no existe)
      if (_reservation == null) {
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
      }

      // 2. Registrar pago
      final amount = double.parse(_total.toStringAsFixed(2));
      await dio.post('/payments', data: {
        'reservationId': _reservation!.id,
        'amount':        amount,
        'provider':      _provider,
        'transactionId': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        'status':        'COMPLETED',
      });
      setState(() { _step = 2; _currentPax = 0; });
      _loadOccupiedSeats();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message']
               ?? e.response?.data?['message']
               ?? 'Error al procesar el pago (${e.response?.statusCode})';
      setState(() => _payError = msg.toString());
    } catch (e) {
      setState(() => _payError = e.toString());
    } finally {
      setState(() => _paying = false);
    }
  }

  Future<void> _loadOccupiedSeats() async {
    try {
      final res = await dio.get(
        '/reservations/flight-classes/${widget.flightClassId}/occupied-seats',
      );
      final list = res.data['data'];
      if (list is List && mounted) {
        setState(() => _occupiedSeats = list
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet());
      }
    } catch (_) {}
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
      // Marcar visualmente como ocupado para que no vuelvan a intentarlo
      setState(() => _occupiedSeats = {..._occupiedSeats, seat});
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

  Widget _step2Payment() => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth > 700 ? _paymentWide() : _paymentNarrow(),
  );

  Widget _paymentWide() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Panel izquierdo — tarjeta + resumen
      Expanded(
        flex: 5,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF312E81), Color(0xFF4C1D95), Color(0xFF1E1B4B)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _payCard(),
              const SizedBox(height: 6),
              Center(child: Text('Toca para ver el CVV',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11))),
              const SizedBox(height: 28),
              _reservationSummaryDark(),
            ]),
          ),
        ),
      ),
      // Panel derecho — formulario
      Expanded(
        flex: 6,
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _paymentFormContent(),
          ),
        ),
      ),
    ],
  );

  Widget _paymentNarrow() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _payCard(),
      const SizedBox(height: 8),
      Center(child: Text('Toca para ver el CVV',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
      const SizedBox(height: 20),
      _paymentFormContent(),
    ]),
  );

  Widget _payCard() => GestureDetector(
    onTap: () => setState(() => _showCardBack = !_showCardBack),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => AnimatedBuilder(
        animation: anim,
        child: child,
        builder: (_, c) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(3.14 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: _showCardBack
          ? _cardBackPurple(key: const ValueKey('back'))
          : _cardFrontPurple(key: const ValueKey('front')),
    ),
  );

  static const _cardGradients = {
    'VISA':       [Color(0xFF0D2B8A), Color(0xFF1A3FA8), Color(0xFF2855C8)],
    'MASTERCARD': [Color(0xFF7B1F1F), Color(0xFFB52020), Color(0xFFE03010)],
    'AMEX':       [Color(0xFF005F8E), Color(0xFF0078B0), Color(0xFF009FD4)],
    'PAYPAL':     [Color(0xFF001A5E), Color(0xFF003087), Color(0xFF0070BA)],
  };

  List<Color> get _cardColors =>
      _cardGradients[_provider] ?? _cardGradients['VISA']!;

  Widget _cardFrontPurple({Key? key}) => Container(
    key: key,
    height: 190,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: _cardColors,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
        color: _cardColors[0].withValues(alpha: 0.55),
        blurRadius: 28, offset: const Offset(0, 12))],
    ),
    padding: const EdgeInsets.all(22),
    child: Stack(children: [
      Positioned(top: -20, right: -20, child: Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06)))),
      Positioned(bottom: -30, left: 50, child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04)))),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 36, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFFFD700)]),
                borderRadius: BorderRadius.circular(5)),
              child: const Icon(Icons.grid_view, color: Colors.white, size: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text(_provider, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900,
                fontSize: 12, letterSpacing: 1.5))),
          ]),
          Text(_cardNumberCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberCtrl.text,
            style: const TextStyle(color: Colors.white, fontSize: 18,
              fontFamily: 'monospace', letterSpacing: 3, fontWeight: FontWeight.w500)),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TITULAR', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(_cardNameCtrl.text.isEmpty ? 'TU NOMBRE' : _cardNameCtrl.text.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('VENCE', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(_expiryCtrl.text.isEmpty ? 'MM/AA' : _expiryCtrl.text,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ]),
        ],
      ),
    ]),
  );

  Widget _cardBackPurple({Key? key}) => Container(
    key: key,
    height: 190,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: _cardColors.reversed.toList(),
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
        color: _cardColors[0].withValues(alpha: 0.55),
        blurRadius: 28, offset: const Offset(0, 12))],
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(height: 44, color: Colors.black.withValues(alpha: 0.4)),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Expanded(child: Container(
            height: 36,
            color: Colors.white.withValues(alpha: 0.25),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('•' * _cvvCtrl.text.length,
              style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 16)))),
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
    ]),
  );

  Widget _reservationSummaryDark() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        const Text('Resumen de reserva', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
      const SizedBox(height: 14),
      _darkRow('Pasajeros', '${_paxControllers.length}'),
      _darkRow('Tarifa base', '\$${_subtotal.toStringAsFixed(2)}'),
      if (_discount != null && _discount! > 0)
        _darkRow('Descuento', '-\$${_discount!.toStringAsFixed(2)}'),
      _darkRow('IVA (15%)', '\$${_tax.toStringAsFixed(2)}'),
      Divider(color: Colors.white.withValues(alpha: 0.2), height: 20),
      _darkRow('TOTAL', '\$${_total.toStringAsFixed(2)}', bold: true),
    ]),
  );

  Widget _darkRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: bold ? 1.0 : 0.7),
        fontSize: bold ? 14 : 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      const Spacer(),
      Text(value, style: TextStyle(
        color: Colors.white, fontSize: bold ? 17 : 13,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
    ]),
  );

  Widget _paymentFormContent() {
    final providers = [
      ('VISA',       'VISA',   const Color(0xFF1A1F71), Icons.credit_card),
      ('MASTERCARD', 'MC',     const Color(0xFFEB001B), Icons.credit_card),
      ('AMEX',       'AMEX',   const Color(0xFF007BC1), Icons.credit_card),
      ('PAYPAL',     'PAYPAL', const Color(0xFF003087), Icons.account_balance_wallet),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + badge seguridad
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Expanded(
            child: Text('Información de Pago',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock, size: 12, color: AppColors.emerald),
              SizedBox(width: 4),
              Text('Conexión Segura', style: TextStyle(
                fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.w600)),
            ])),
        ]),
        const SizedBox(height: 4),
        const Text('Tus datos están protegidos con encriptación SSL',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),

        // Selector de método de pago
        const Text('Método de pago',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 10),
        Row(children: providers.asMap().entries.map((e) {
          final i = e.key; final p = e.value;
          final isSel = _provider == p.$1;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _provider = p.$1),
            child: Container(
              margin: EdgeInsets.only(right: i < providers.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFF),
                border: Border.all(
                  color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: isSel ? 2 : 1),
                borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(p.$4, size: 20, color: isSel ? p.$3 : const Color(0xFF94A3B8)),
                const SizedBox(height: 4),
                Text(p.$2, style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5,
                  color: isSel ? p.$3 : const Color(0xFFCBD5E1))),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 22),

        // Nombre titular
        _payField('Nombre del titular', 'Ej. JUAN GARCIA', _cardNameCtrl,
          onChange: (v) => setState(() {})),
        const SizedBox(height: 14),

        // Número de tarjeta
        _payField('Número de tarjeta', '•••• •••• •••• ••••', _cardNumberCtrl,
          onChange: (v) => setState(() {}),
          formatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
          type: TextInputType.number, maxLen: 19,
          suffix: Icon(Icons.credit_card_outlined, color: Colors.grey.shade400, size: 20)),
        const SizedBox(height: 14),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _payField('Fecha de vencimiento', 'MM/AA', _expiryCtrl,
            onChange: (v) => setState(() {}),
            formatters: [_ExpiryFormatter()],
            type: TextInputType.number, maxLen: 5)),
          const SizedBox(width: 12),
          Expanded(child: _payField('CVV', '•••', _cvvCtrl,
            obscure: true, type: TextInputType.number, maxLen: 4)),
        ]),
        const SizedBox(height: 20),

        if (_payError != null) ...[
          _errorBox(_payError!),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _paying ? null : _submitPayment,
            icon: _paying
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.lock_outline, size: 18),
            label: Text(_paying ? 'Procesando...' : 'Confirmar y pagar',
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  Widget _payField(String label, String hint, TextEditingController ctrl, {
    ValueChanged<String>? onChange,
    bool obscure = false,
    List<TextInputFormatter>? formatters,
    TextInputType? type,
    int? maxLen,
    Widget? suffix,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl, obscureText: obscure,
      onChanged: onChange, inputFormatters: formatters,
      keyboardType: type, maxLength: maxLen,
      decoration: InputDecoration(
        hintText: hint, counterText: '',
        filled: true, fillColor: const Color(0xFFF8FAFC),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
    ),
  ]);

  // ── PASO 3: Asientos ──────────────────────────────────────
  Set<String> _occupiedSeats = {};

  Widget _step3Seats() {
    if (_reservation == null) return const SizedBox();
    final passengers = _reservation!.passengers;
    final cabin = passengers.first.cabinClass ?? 'ECONOMY';
    final assigned = _seats.whereType<String>().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Selección de Asientos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text('$assigned de ${passengers.length} asignados',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE))),
              child: Text(cabin,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary, letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 16),

          // Tabs pasajeros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: passengers.asMap().entries.map((e) {
              final idx = e.key; final pax = e.value;
              final selected = idx == _currentPax;
              final hasSeat = _seats[idx] != null;
              return GestureDetector(
                onTap: () => setState(() => _currentPax = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.gradientButton : null,
                    color: selected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Colors.transparent
                           : hasSeat ? AppColors.emerald
                           : const Color(0xFFE2E8F0),
                      width: 1.5),
                    boxShadow: selected ? [BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(hasSeat ? Icons.event_seat : Icons.person_outline,
                      size: 14,
                      color: selected ? Colors.white
                           : hasSeat ? AppColors.emerald
                           : const Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(pax.firstName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white
                             : hasSeat ? AppColors.emerald
                             : const Color(0xFF374151))),
                    if (hasSeat) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(_seats[idx]!,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : AppColors.emerald)),
                      ),
                    ],
                  ]),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 16),

          // Mapa de asientos
          _SeatMapWidget(
            cabin: cabin,
            occupiedSeats: _occupiedSeats,
            mySeats: _seats.whereType<String>().toSet(),
            currentSeat: _seats[_currentPax],
            onSeatTap: _assignSeat,
          ),
          const SizedBox(height: 14),

          // Leyenda
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _legendItem(AppColors.primaryDark, Icons.event_seat, 'Mi asiento'),
              _legendItem(const Color(0xFFEF4444), Icons.block, 'Ocupado'),
              _legendItem(Colors.white, Icons.chair_outlined, 'Disponible',
                border: const Color(0xFFCBD5E1)),
            ]),
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _skipSeats,
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text('Omitir — asignar asientos después'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label, {Color? border}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(4),
          border: border != null ? Border.all(color: border) : null),
        child: Icon(icon, size: 12,
          color: color == Colors.white ? const Color(0xFF94A3B8) : Colors.white)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569),
        fontWeight: FontWeight.w500)),
    ]);

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
    final cols  = cabin == 'ECONOMY'  ? ['A','B','C','D','E','F']
                : cabin == 'BUSINESS' ? ['A','B','C','D']
                :                       ['A','B'];
    final rows  = cabin == 'ECONOMY'  ? 21
                : cabin == 'BUSINESS' ? 8
                :                       6;
    final aisle = cabin == 'ECONOMY'  ? 3 : 2;
    final total = rows * cols.length;
    final avail = total - occupiedSeats.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            const Icon(Icons.flight, color: AppColors.primaryDark, size: 18),
            const SizedBox(width: 8),
            Text(cabin, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const Spacer(),
            _StatBadge(avail, const Color(0xFF059669), Icons.event_seat, 'libres'),
            const SizedBox(width: 8),
            _StatBadge(occupiedSeats.length, const Color(0xFFEF4444),
              Icons.block, 'ocupados'),
          ]),
        ),

        // Mapa de asientos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(children: [
            // Nariz del avión
            Container(
              width: 72, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                border: Border.all(color: const Color(0xFFBFDBFE))),
              child: const Center(
                child: Icon(Icons.flight, color: AppColors.primary, size: 16))),
            const SizedBox(height: 10),

            // Letras columnas
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 32),
              ...cols.asMap().entries.expand((e) sync* {
                yield SizedBox(
                  width: 36,
                  child: Center(child: Text(e.value,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B)))));
                if (e.key == aisle - 1) yield const SizedBox(width: 24);
              }),
            ]),
            const SizedBox(height: 8),

            // Filas
            ...List.generate(rows, (rowIdx) {
              final rowNum = rowIdx + 1;
              // Zona de cabina
              final isFirst    = cabin == 'FIRST';
              final isBusiness = cabin == 'BUSINESS';
              Color rowAccent  = isFirst    ? const Color(0xFFFEF3C7)
                               : isBusiness ? const Color(0xFFEDE9FE)
                               :              Colors.transparent;

              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                decoration: rowAccent != Colors.transparent
                    ? BoxDecoration(color: rowAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6))
                    : null,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 32,
                    child: Text('$rowNum',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8)))),
                  ...cols.asMap().entries.expand((e) sync* {
                    final seatId     = '$rowNum${e.value}';
                    final isOccupied = occupiedSeats.contains(seatId);
                    final isMine     = mySeats.contains(seatId);
                    final isCurrent  = currentSeat == seatId;

                    Color bg, borderCol;
                    Widget? icon;

                    if (isCurrent) {
                      bg = AppColors.primary;
                      borderCol = AppColors.primaryDark;
                      icon = const Icon(Icons.person, color: Colors.white, size: 13);
                    } else if (isMine) {
                      bg = AppColors.primaryDark;
                      borderCol = AppColors.primaryDark;
                      icon = const Icon(Icons.check, color: Colors.white, size: 11);
                    } else if (isOccupied) {
                      bg = const Color(0xFFFEE2E2);
                      borderCol = const Color(0xFFFCA5A5);
                      icon = const Icon(Icons.close, color: Color(0xFFEF4444), size: 10);
                    } else {
                      bg = Colors.white;
                      borderCol = const Color(0xFFCBD5E1);
                      icon = null;
                    }

                    yield GestureDetector(
                      onTap: isOccupied ? null : () => onSeatTap(seatId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 32, height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderCol,
                            width: isCurrent ? 2 : 1),
                          boxShadow: (isMine || isCurrent) ? [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4, offset: const Offset(0, 2))] : null,
                        ),
                        child: icon != null ? Center(child: icon) : null,
                      ),
                    );
                    if (e.key == aisle - 1) yield const SizedBox(width: 24);
                  }),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;
  final String label;
  const _StatBadge(this.count, this.color, this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text('$count $label',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
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

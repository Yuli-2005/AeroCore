import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/widgets/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> _airports = [];
  List<dynamic> _filtered = [];

  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  String? _originCode;
  String? _destCode;
  DateTime? _date;
  int _passengers = 1;
  String _cabin = 'ECONOMY';
  bool _searching = false;

  bool _showOriginDrop = false;
  bool _showDestDrop   = false;

  final _cabins = {
    'ECONOMY':        'Económica',
    'PREMIUM_ECONOMY': 'Premium Economy',
    'BUSINESS':       'Business',
    'FIRST':          'Primera clase',
  };

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    try {
      final res = await dio.get('/airports');
      setState(() => _airports = res.data['data'] ?? []);
    } catch (_) {}
  }

  List<dynamic> _filter(String q) {
    if (q.isEmpty) return _airports.take(8).toList();
    final s = q.toLowerCase();
    return _airports.where((a) =>
      (a['name']    as String? ?? '').toLowerCase().contains(s) ||
      (a['iataCode'] as String? ?? '').toLowerCase().contains(s) ||
      (a['city']?['name'] as String? ?? '').toLowerCase().contains(s)
    ).take(8).toList();
  }

  Future<void> _search() async {
    if (_originCode == null || _destCode == null || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos'), backgroundColor: AppColors.red));
      return;
    }
    setState(() => _searching = true);
    try {
      final dateStr = '${_date!.year}-${_date!.month.toString().padLeft(2,'0')}-${_date!.day.toString().padLeft(2,'0')}';
      final res = await dio.get('/flights/search', queryParameters: {
        'origin':      _originCode,
        'destination': _destCode,
        'date':        dateStr,
        'passengers':  _passengers,
        'class': _cabin,
      });
      final flights = res.data['data'] ?? [];
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _ResultsScreen(
            flights:    flights,
            origin:     _originCtrl.text,
            dest:       _destCtrl.text,
            date:       _date!,
            passengers: _passengers,
          ),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar vuelos'), backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) { setState(() => _searching = false); }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.delete();
    if (mounted) context.go('/login');
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _navbar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _hero(),
                  _featuresSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navbar (glass effect) ──────────────────────────────────
  Widget _navbar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Logo
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.gradientButton,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.flight, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.purple],
              ).createShader(b),
              child: const Text('Aero', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Text('Core', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const Spacer(),
            // Nav links
            _navLink('Buscar vuelos', Icons.search, () {}),
            const SizedBox(width: 8),
            _navLink('Mis viajes', Icons.card_travel, () => context.go('/my-trips')),
            const SizedBox(width: 16),
            // Logout
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Salir', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
        ]),
      ),
    );
  }

  // ── Hero section ──────────────────────────────────────────
  Widget _hero() {
    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: Stack(
        children: [
          Positioned(top: 60,  left: 80,  child: _glow(220, Colors.white, 0.07)),
          Positioned(bottom: 80, right: 60, child: _glow(160, Colors.white, 0.05)),
          Positioned(top: 200, right: 200, child: _glow(80, Colors.white, 0.1)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                children: [
                  const Text('Encuentra tu vuelo\nperfecto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, fontSize: 40,
                      fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 12),
                  Text('Miles de destinos. Las mejores tarifas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
                  const SizedBox(height: 36),
                  _searchCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de búsqueda (glass) ────────────────────────────
  Widget _searchCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 860),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Fila 1: Origen / Destino
          LayoutBuilder(builder: (_, c) {
            final wide = c.maxWidth > 600;
            final fields = [
              _airportField('Origen', _originCtrl, _showOriginDrop, true),
              _airportField('Destino', _destCtrl, _showDestDrop, false),
            ];
            return wide
                ? Row(children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ])
                : Column(children: [fields[0], const SizedBox(height: 12), fields[1]]);
          }),
          const SizedBox(height: 12),
          // Fila 2: Fecha / Pasajeros / Cabina
          LayoutBuilder(builder: (_, c) {
            final wide = c.maxWidth > 600;
            final controls = [
              _dateField(),
              _passengerField(),
              _cabinField(),
            ];
            return wide
                ? Row(children: controls
                    .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
                    .toList()..removeLast())
                : Column(children: controls
                    .expand((w) => [w, const SizedBox(height: 12)])
                    .toList()..removeLast());
          }),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: 'Buscar vuelos',
              icon: Icons.search,
              onPressed: _search,
              loading: _searching,
            ),
          ),
        ],
      ),
    );
  }

  Widget _airportField(String label, TextEditingController ctrl,
      bool showDrop, bool isOrigin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            prefixIcon: Icon(
              isOrigin ? Icons.flight_takeoff : Icons.flight_land,
              color: Colors.white.withValues(alpha: 0.8), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white, width: 2)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.15),
          ),
          onChanged: (v) {
            setState(() {
              _filtered = _filter(v);
              if (isOrigin) { _showOriginDrop = v.isNotEmpty; _originCode = null; }
              else          { _showDestDrop   = v.isNotEmpty; _destCode   = null; }
            });
          },
        ),
        if ((isOrigin ? _showOriginDrop : _showDestDrop) && _filtered.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 12)],
            ),
            child: Column(
              children: _filtered.map((a) {
                final code = a['iataCode'] ?? '';
                final name = a['name'] ?? '';
                final city = a['city']?['name'] ?? '';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.flight, size: 16, color: AppColors.primary),
                  title: Text('$code — $name', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(city, style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    setState(() {
                      ctrl.text = '$code — $name';
                      if (isOrigin) { _originCode = a['id']; _showOriginDrop = false; }
                      else          { _destCode   = a['id']; _showDestDrop   = false; }
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _dateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, color: Colors.white.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 8),
          Text(
            _date == null ? 'Fecha de salida'
                : '${_date!.day}/${_date!.month}/${_date!.year}',
            style: TextStyle(
              color: _date == null
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white,
              fontSize: 14),
          ),
        ]),
      ),
    );
  }

  Widget _passengerField() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.person, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 8),
        Text('$_passengers pasajero${_passengers > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white, fontSize: 14)),
        const Spacer(),
        _counterBtn(Icons.remove, () { if (_passengers > 1) setState(() => _passengers--); }),
        const SizedBox(width: 8),
        _counterBtn(Icons.add, () { if (_passengers < 9) setState(() => _passengers++); }),
      ]),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
  );

  Widget _cabinField() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _cabin,
          dropdownColor: const Color(0xFF1D4ED8),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          items: _cabins.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _cabin = v); },
        ),
      ),
    );
  }

  // ── Features section ──────────────────────────────────────
  Widget _featuresSection() {
    final features = [
      (Icons.bolt, 'Reservas instantáneas', 'Confirma tu vuelo en segundos.', AppColors.primaryDark),
      (Icons.lock, 'Pagos seguros',         'Transacciones cifradas y seguras.', AppColors.purple),
      (Icons.headset_mic, 'Soporte 24/7',   'Asistencia cuando la necesites.',  AppColors.cyan),
    ];
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('¿Por qué elegir AeroCore?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (_, c) {
            final wide = c.maxWidth > 700;
            final cards = features.map((f) => _featureCard(f.$1, f.$2, f.$3, f.$4)).toList();
            return wide
                ? Row(
                    children: cards.expand((w) => [Expanded(child: w), const SizedBox(width: 16)])
                        .toList()..removeLast())
                : Column(children: cards
                    .expand((w) => [w, const SizedBox(height: 16)])
                    .toList()..removeLast());
          }),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String desc, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
    ),
  );
}

// ── Pantalla de resultados ─────────────────────────────────
class _ResultsScreen extends StatelessWidget {
  final List<dynamic> flights;
  final String origin, dest;
  final DateTime date;
  final int passengers;
  const _ResultsScreen({required this.flights, required this.origin,
      required this.dest, required this.date, required this.passengers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Header oscuro con ruta
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)])),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18)),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$origin → $dest',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('${date.day}/${date.month}/${date.year}  ·  $passengers pax',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('${flights.length} vuelos',
                      style: const TextStyle(color: Colors.white, fontSize: 12))),
                ]),
              ),
            ),
          ),
          Expanded(
            child: flights.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.flight_outlined, size: 64, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text('No hay vuelos disponibles',
                      style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Nueva búsqueda')),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: flights.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _FlightCard(
                      flight: flights[i], passengers: passengers),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final dynamic flight;
  final int passengers;
  const _FlightCard({required this.flight, required this.passengers});

  String _time(String dt) => dt.length > 15 ? dt.substring(11, 16) : dt;

  @override
  Widget build(BuildContext context) {
    final dep     = flight['departureTime'] as String? ?? '';
    final arr     = flight['arrivalTime']   as String? ?? '';
    final origin  = flight['originAirport']?['iataCode'] ?? '';
    final dest    = flight['destinationAirport']?['iataCode'] ?? '';
    final origCity = flight['originAirport']?['city']?['name'] ?? '';
    final destCity = flight['destinationAirport']?['city']?['name'] ?? '';
    final airline  = flight['airline']?['name'] ?? '';
    final status   = flight['status'] as String? ?? '';
    final classes  = (flight['flightClasses'] as List<dynamic>?) ?? [];

    final statusColor = status == 'SCHEDULED' ? AppColors.emerald : AppColors.amber;
    final statusLabel = status == 'SCHEDULED' ? 'A tiempo' : status;

    return AppCard(
      padding: const EdgeInsets.all(0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera aerolínea + estado
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.flight, color: AppColors.primaryDark, size: 16)),
            const SizedBox(width: 10),
            Text(airline, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: TextStyle(
                color: statusColor, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        ),
        // Horario
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [
              Text(_time(dep), style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              Text(origin, style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              Text(origCity, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
            Column(children: [
              const Icon(Icons.flight, color: AppColors.primary, size: 20),
              Container(height: 2, width: 80,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(gradient: AppColors.gradient)),
              const Text('Directo', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
            Column(children: [
              Text(_time(arr), style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              Text(dest, style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              Text(destCity, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ),
        // Clases disponibles
        if (classes.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: classes.map<Widget>((c) {
                final price = (c['price'] ?? 0).toDouble();
                final seats = c['availableSeats'] ?? 0;
                final cabin = c['cabinClass'] as String? ?? '';
                final noSeats = seats == 0;
                final cabinEmoji = cabin == 'FIRST' ? '👑'
                    : cabin == 'BUSINESS' ? '💼' : '✈️';
                final cabinBg = cabin == 'FIRST'
                    ? const Color(0xFFF5F3FF)
                    : cabin == 'BUSINESS'
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF0F9FF);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: noSeats ? const Color(0xFFF8FAFC) : cabinBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    Text(cabinEmoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cabin, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: noSeats ? const Color(0xFF94A3B8) : const Color(0xFF1E293B))),
                      Text('$seats asientos', style: TextStyle(
                        fontSize: 11,
                        color: noSeats ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ]),
                    const Spacer(),
                    Text('\$${(price * passengers).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: noSeats ? const Color(0xFF94A3B8) : const Color(0xFF6366F1))),
                    const SizedBox(width: 12),
                    if (!noSeats)
                      GradientButton(
                        text: 'Reservar',
                        onPressed: () => context.push(
                          '/reserve?flightClassId=${c['id']}&price=$price'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Text('Sin lugares',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}
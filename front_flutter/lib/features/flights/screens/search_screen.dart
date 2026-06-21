import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/sse_client.dart';
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

  // Rutas destacadas cargadas desde Supabase
  List<Map<String, dynamic>> _featuredRoutes = [];

  static const _routePairs = [
    ('GYE', 'Guayaquil', 'UIO', 'Quito'),
    ('UIO', 'Quito',     'GYE', 'Guayaquil'),
    ('UIO', 'Quito',     'BOG', 'Bogotá'),
    ('BOG', 'Bogotá',    'UIO', 'Quito'),
    ('GYE', 'Guayaquil', 'BOG', 'Bogotá'),
    ('UIO', 'Quito',     'LIM', 'Lima'),
  ];

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
    _loadFeaturedRoutes();
  }

  Future<void> _loadAirports() async {
    try {
      final res = await dio.get('/airports');
      setState(() => _airports = res.data['data'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadFeaturedRoutes() async {
    try {
      final res = await dio.get('/flights');
      final flights = res.data['data'] as List? ?? [];
      final Map<String, Map<String, dynamic>> best = {};
      for (final f in flights) {
        final status = f['status'] as String? ?? '';
        if (status != 'SCHEDULED' && status != 'DELAYED') continue;
        final oCode = f['originAirportIata'] as String? ?? '';
        final dCode = f['destinationAirportIata'] as String? ?? '';
        if (oCode.isEmpty || dCode.isEmpty) continue;
        final classes = f['flightClasses'] as List? ?? [];
        double minPrice = 0;
        for (final c in classes) {
          final seats = (c['availableSeats'] as num? ?? 0).toInt();
          if (seats <= 0) continue;
          final p = ((c['basePrice'] ?? c['price'] ?? 0) as num).toDouble();
          if (p > 0 && (minPrice == 0 || p < minPrice)) minPrice = p;
        }
        if (minPrice == 0) continue;
        final key = '$oCode-$dCode';
        final current = best[key];
        if (current == null || minPrice < (current['price'] as double)) {
          best[key] = {
            'oCode': oCode, 'oCity': oCode,
            'dCode': dCode, 'dCity': dCode,
            'date': (f['departureDate'] as String? ?? '').split('T').first,
            'price': minPrice,
          };
        }
      }
      final sorted = best.values.toList()
        ..sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
      if (mounted) setState(() => _featuredRoutes = sorted.take(6).toList());
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
                  _offersSection(),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Color(0xFF475569), size: 26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8,
              offset: const Offset(0, 48),
              onSelected: (val) async {
                if (val == 'logout') {
                  await _logout();
                } else {
                  context.go(val);
                }
              },
              itemBuilder: (_) => [
                _menuItem('Buscar vuelos', Icons.search, '/flights'),
                _menuItem('Mis viajes', Icons.card_travel, '/my-trips'),
                const PopupMenuDivider(),
                _menuItem('Salir', Icons.logout, 'logout',
                  color: const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String label, IconData icon, String value,
      {Color color = const Color(0xFF475569)}) =>
    PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14,
          fontWeight: FontWeight.w500)),
      ]),
    );

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
                  const SizedBox(height: 20),
                  _popularChips(),
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
                      if (isOrigin) { _originCode = code; _showOriginDrop = false; }
                      else          { _destCode   = code; _showDestDrop   = false; }
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

  // ── Selección rápida de ruta ──────────────────────────────
  void _quickSelect(String oCode, String oCity, String dCode, String dCity, {String? date}) {
    final oAp = _airports.where((a) => a['iataCode'] == oCode).firstOrNull;
    final dAp = _airports.where((a) => a['iataCode'] == dCode).firstOrNull;
    setState(() {
      _originCtrl.text = '$oCode — ${oAp?['name'] ?? oCity}';
      _originCode = oCode;
      _destCtrl.text   = '$dCode — ${dAp?['name'] ?? dCity}';
      _destCode = dCode;
      _showOriginDrop = false;
      _showDestDrop   = false;
      if (date != null) {
        final p = date.split('-');
        _date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
    });
    if (date != null) _search();
  }

  // ── Chips de rutas (usa datos de Supabase si ya cargaron) ─
  Widget _popularChips() {
    final routes = _featuredRoutes.isNotEmpty
        ? _featuredRoutes
        : _routePairs.map((r) => {'oCode': r.$1, 'oCity': r.$2, 'dCode': r.$3, 'dCity': r.$4, 'price': 0.0, 'date': null}).toList();
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: routes.map((r) {
        final price = (r['price'] as double?) ?? 0;
        return ActionChip(
          backgroundColor: Colors.white,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(r['oCode'] as String, style: const TextStyle(
              color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w700)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF94A3B8))),
            Text(r['dCode'] as String, style: const TextStyle(
              color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w700)),
            if (price > 0) ...[
              const SizedBox(width: 6),
              Text('desde \$${price.toInt()}', style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 12)),
            ],
          ]),
          onPressed: () => _quickSelect(
            r['oCode'] as String, r['oCity'] as String,
            r['dCode'] as String, r['dCity'] as String,
            date: r['date'] as String?,
          ),
        );
      }).toList(),
    );
  }

  // ── Ofertas recomendadas (datos reales de Supabase) ───────
  Widget _offersSection() {
    final gradients = [
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      [const Color(0xFF6366F1), const Color(0xFF7C3AED)],
      [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
      [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
      [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
    ];

    final routes = _featuredRoutes.isNotEmpty
        ? _featuredRoutes
        : _routePairs.map((r) => {'oCode': r.$1, 'oCity': r.$2, 'dCode': r.$3, 'dCity': r.$4, 'price': 0.0, 'date': null}).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ofertas recomendadas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          const Text('Rutas reales disponibles en la base de datos',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          if (_featuredRoutes.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth > 800 ? 3 : c.maxWidth > 500 ? 2 : 1;
              final rows = <Widget>[];
              for (var i = 0; i < routes.length; i += cols) {
                final rowItems = <Widget>[];
                for (var j = i; j < i + cols && j < routes.length; j++) {
                  final r = routes[j];
                  final price = (r['price'] as double?) ?? 0;
                  final g = gradients[j % gradients.length];
                  rowItems.add(Expanded(child: GestureDetector(
                    onTap: () => _quickSelect(
                      r['oCode'] as String, r['oCity'] as String,
                      r['dCode'] as String, r['dCity'] as String,
                      date: r['date'] as String?,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: g),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(r['oCode'] as String, style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, color: Colors.white, size: 18)),
                          Text(r['dCode'] as String, style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 4),
                        Text(r['oCity'] as String, style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                        const SizedBox(height: 16),
                        Text('desde', style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                        Text(price > 0 ? '\$${price.toInt()}' : '---',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('por persona · ida', style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      ]),
                    ),
                  )));
                }
                rows.add(Row(children: rowItems));
              }
              return Column(children: rows);
            }),
        ],
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

class _FlightCard extends StatefulWidget {
  final dynamic flight;
  final int passengers;
  const _FlightCard({required this.flight, required this.passengers});
  @override State<_FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<_FlightCard> {
  // flightClassId → asientos actualizados en tiempo real
  final Map<String, int> _liveSeats = {};
  StreamSubscription<Map<String, dynamic>>? _sseSub;

  @override
  void initState() {
    super.initState();
    final flightId = widget.flight['id'] as String?;
    if (flightId != null && flightId.isNotEmpty) {
      _sseSub = sseAvailability(flightId).listen((event) {
        final fcId  = event['flightClassId'] as String?;
        final seats = event['availableSeats'] as int?;
        if (fcId != null && seats != null && mounted) {
          setState(() => _liveSeats[fcId] = seats);
        }
      });
    }
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  String _time(String dt) => dt.length > 15 ? dt.substring(11, 16) : dt;

  @override
  Widget build(BuildContext context) {
    final flight   = widget.flight;
    final passengers = widget.passengers;
    final dep = flight['departureDateTime'] as String? ?? flight['departureTime'] as String? ?? '';
    final arr = flight['arrivalDateTime']   as String? ?? flight['arrivalTime']   as String? ?? '';
    final origin   = flight['originAirport']?['iataCode'] ?? '';
    final dest     = flight['destinationAirport']?['iataCode'] ?? '';
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
                final price   = double.tryParse((c['basePrice'] ?? c['price'] ?? 0).toString()) ?? 0.0;
                final fcId    = c['id'] as String? ?? '';
                // Usa asientos en tiempo real si llegó un update SSE, si no el valor original
                final seats   = _liveSeats[fcId] ?? (c['availableSeats'] ?? 0);
                final cabin   = c['cabinClass'] as String? ?? '';
                final noSeats = seats == 0;
                final isLive  = _liveSeats.containsKey(fcId);
                final cabinEmoji = cabin == 'FIRST' ? '👑'
                    : cabin == 'BUSINESS' ? '💼' : '✈️';
                final cabinBg = cabin == 'FIRST'
                    ? const Color(0xFFF5F3FF)
                    : cabin == 'BUSINESS'
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF0F9FF);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: noSeats ? const Color(0xFFF8FAFC) : cabinBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLive && !noSeats
                          ? AppColors.emerald.withValues(alpha: 0.5)
                          : const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    Text(cabinEmoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cabin, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: noSeats ? const Color(0xFF94A3B8) : const Color(0xFF1E293B))),
                      Row(children: [
                        Text('$seats asientos', style: TextStyle(
                          fontSize: 11,
                          color: noSeats ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        if (isLive) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle)),
                        ],
                      ]),
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
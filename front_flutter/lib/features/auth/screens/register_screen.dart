import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/widgets/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName      = TextEditingController();
  final _firstLastName  = TextEditingController();
  final _secondName     = TextEditingController();
  final _secondLastName = TextEditingController();
  final _email          = TextEditingController();
  final _address        = TextEditingController();
  final _phone          = TextEditingController();
  final _password       = TextEditingController();
  final _confirm        = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await dio.post('/auth/register', data: {
        'firstName':      _firstName.text.trim(),
        'firstLastName':  _firstLastName.text.trim(),
        'secondName':     _secondName.text.trim(),
        'secondLastName': _secondLastName.text.trim(),
        'email':          _email.text.trim(),
        'address':        _address.text.trim(),
        'phone':          _phone.text.trim(),
        'password':       _password.text,
      });
      final token = res.data['data']['token'] as String;
      await TokenStorage.save(token);
      if (mounted) context.go('/flights');
    } catch (_) {
      setState(() => _error = 'Error al registrarse. El correo ya puede estar en uso.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: isWide ? _wideLayout() : _mobileLayout(),
    );
  }

  Widget _wideLayout() => Row(children: [
    // Panel izquierdo
    Expanded(flex: 4, child: Container(
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: Stack(children: [
        Positioned(top: 60,    left: 60,  child: _glow(180, Colors.white, 0.07)),
        Positioned(bottom: 80, right: 40, child: _glow(130, Colors.white, 0.05)),
        Center(child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.flight_takeoff, color: Colors.white, size: 48),
            const SizedBox(height: 20),
            const Text('Únete a\nAeroCore',
              style: TextStyle(color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 16),
            Text('Crea tu cuenta y reserva\nvuelos en segundos.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16, height: 1.5)),
            const SizedBox(height: 32),
            ...[('✈️','Vuelos en tiempo real'), ('🔒','Pagos 100% seguros'),
                ('📱','Boarding pass digital')].map((e) =>
              Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Text(e.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(e.$2, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), fontSize: 14,
                    fontWeight: FontWeight.w500)),
                ]))),
          ]),
        )),
      ]),
    )),
    // Panel derecho — formulario
    Expanded(flex: 6, child: Center(child: _form())),
  ]);

  Widget _mobileLayout() => SingleChildScrollView(child: Column(children: [
    Container(height: 180, decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flight_takeoff, color: Colors.white, size: 40),
        SizedBox(height: 10),
        Text('Crear cuenta', style: TextStyle(
          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      ]))),
    _form(),
  ]));

  Widget _form() => Container(
    constraints: const BoxConstraints(maxWidth: 560),
    padding: const EdgeInsets.all(36),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Logo
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(gradient: AppColors.gradientButton,
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.flight, color: Colors.white, size: 20)),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.purple]).createShader(b),
          child: const Text('Aero', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
        const Text('Core', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 28),
      const Text('Crear cuenta', style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 4),
      const Text('Completa tus datos para registrarte',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      const SizedBox(height: 24),
      // Nombres
      Row(children: [
        Expanded(child: _field('Primer nombre *', _firstName)),
        const SizedBox(width: 12),
        Expanded(child: _field('Primer apellido *', _firstLastName)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _field('Segundo nombre', _secondName)),
        const SizedBox(width: 12),
        Expanded(child: _field('Segundo apellido', _secondLastName)),
      ]),
      const SizedBox(height: 12),
      _field('Correo electrónico *', _email,
        icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _field('Dirección', _address, icon: Icons.home_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _field('Teléfono', _phone,
          icon: Icons.phone_outlined, keyboard: TextInputType.phone)),
      ]),
      const SizedBox(height: 16),
      // Separador seguridad
      Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Seguridad', style: TextStyle(
            color: Colors.grey.shade500, fontSize: 12))),
        const Expanded(child: Divider()),
      ]),
      const SizedBox(height: 16),
      _field('Contraseña *', _password, icon: Icons.lock_outline, obscure: true),
      const SizedBox(height: 12),
      _field('Confirmar contraseña *', _confirm, icon: Icons.lock_outline, obscure: true),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA))),
          child: Text(_error!, style: const TextStyle(
            color: Color(0xFFDC2626), fontSize: 13))),
      ],
      const SizedBox(height: 24),
      GradientButton(text: 'Registrarse', icon: Icons.person_add,
        onPressed: _register, loading: _loading),
      const SizedBox(height: 14),
      TextButton(onPressed: () => context.go('/login'),
        child: const Text('¿Ya tienes cuenta? Inicia sesión',
          style: TextStyle(color: AppColors.primary))),
    ]),
  );

  Widget _field(String label, TextEditingController ctrl,
      {IconData? icon, bool obscure = false, TextInputType? keyboard}) =>
    TextField(controller: ctrl, obscureText: obscure, keyboardType: keyboard,
      decoration: InputDecoration(labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        filled: true, fillColor: Colors.white,
      ));

  Widget _glow(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: color.withValues(alpha: opacity)));
}
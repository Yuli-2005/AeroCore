import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/widgets/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await dio.post('/auth/login', data: {
        'email':    _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      final token = res.data['data']['token'] as String;
      await TokenStorage.save(token);
      if (mounted) context.go('/flights');
    } catch (_) {
      setState(() { _error = 'Correo o contraseña incorrectos'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
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

  Widget _wideLayout() {
    return Row(
      children: [
        // Panel izquierdo — imagen con gradiente (como Vue)
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.gradient),
            child: Stack(
              children: [
                // Círculos decorativos flotantes
                Positioned(top: 80,  left: 60,  child: _glowCircle(200, Colors.white, 0.08)),
                Positioned(bottom: 120, right: 40, child: _glowCircle(150, Colors.white, 0.06)),
                Positioned(top: 300, right: 100,  child: _glowCircle(80,  Colors.white, 0.1)),
                // Contenido central
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flight_takeoff, color: Colors.white, size: 56),
                        const SizedBox(height: 24),
                        const Text('Bienvenido a\nAeroCore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          )),
                        const SizedBox(height: 16),
                        Text('La plataforma de reservas\nde vuelos más confiable.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 18,
                            height: 1.5,
                          )),
                        const SizedBox(height: 40),
                        ...[
                          ('✈️', 'Vuelos en tiempo real'),
                          ('🔒', 'Pagos 100% seguros'),
                          ('⚡', 'Reservas instantáneas'),
                        ].map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Text(e.$1, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text(e.$2, style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            )),
                          ]),
                        )),
                      ],
                    ),
                  ),
                ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Panel derecho — formulario
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Center(child: _formContent()),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(gradient: AppColors.gradient),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flight_takeoff, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text('AeroCore', style: TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          _formContent(),
        ],
      ),
    );
  }

  Widget _formContent() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.gradientButton,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.flight, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.purple],
              ).createShader(bounds),
              child: const Text('Aero', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Text('Core', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 32),
          const Text('Iniciar sesión',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Ingresa tus credenciales para continuar',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          const SizedBox(height: 28),
          // Email
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Correo electrónico', Icons.email_outlined),
          ),
          const SizedBox(height: 16),
          // Password
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: _inputDecoration('Contraseña', Icons.lock_outline),
            onSubmitted: (_) => _login(),
          ),
          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 24),
          GradientButton(text: 'Iniciar sesión', onPressed: _login, loading: _loading,
            icon: Icons.login),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('¿No tienes cuenta? Regístrate',
              style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _glowCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
    ),
  );
}
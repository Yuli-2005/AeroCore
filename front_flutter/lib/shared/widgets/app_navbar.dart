import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/token_storage.dart';
import 'app_theme.dart';

class AppNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBack;
  const AppNavbar({super.key, this.title, this.showBack = false});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 1100;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF475569)),
                padding: EdgeInsets.zero,
              ),
            // Logo
            GestureDetector(
              onTap: () => context.go('/flights'),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientButton,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.flight, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.purple],
                  ).createShader(b),
                  child: const Text('Aero', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const Text('Core', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              ]),
            ),
            if (title != null && isWide) ...[
              const SizedBox(width: 16),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Text(title!, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ],
            const Spacer(),
            // Desktop: botones en fila
            if (isWide) ...[
              _navBtn(context, 'Buscar', Icons.search, '/flights'),
              const SizedBox(width: 4),
              _navBtn(context, 'Mis viajes', Icons.card_travel, '/my-trips'),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await TokenStorage.delete();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, size: 15, color: Color(0xFFEF4444)),
                label: const Text('Salir', style: TextStyle(
                  color: Color(0xFFEF4444), fontSize: 13)),
              ),
            ]
            // Mobile: menú hamburguesa
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Color(0xFF475569)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) async {
                  if (val == 'logout') {
                    await TokenStorage.delete();
                    if (context.mounted) context.go('/login');
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

  Widget _navBtn(BuildContext ctx, String label, IconData icon, String route) =>
    InkWell(
      onTap: () => ctx.go(route),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Icon(icon, size: 15, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
        ]),
      ),
    );

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
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_theme.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.navDark),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.flight, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text('AeroCore', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('Admin Panel', style: TextStyle(
                  color: Colors.white, fontSize: 11))),
              const Spacer(),
              ...[
                ('Dashboard',    Icons.dashboard,     '/admin'),
                ('Vuelos',       Icons.flight,        '/admin/flights'),
                ('Reservas',     Icons.book_online,   '/admin/reservations'),
                ('Usuarios',     Icons.people,        '/admin/users'),
              ].map((e) => TextButton(
                onPressed: () => context.go(e.$3),
                child: Text(e.$1, style: const TextStyle(color: Colors.white, fontSize: 13)),
              )),
            ]),
          ),
        ),
      ),
      body: child,
    );
  }
}
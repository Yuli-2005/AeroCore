import 'package:flutter/material.dart';

class AppColors {
  static const primary     = Color(0xFF3B82F6); // blue-500
  static const primaryDark = Color(0xFF1D4ED8); // blue-700
  static const purple      = Color(0xFF7C3AED); // violet-600
  static const cyan        = Color(0xFF0EA5E9); // sky-500
  static const surface     = Color(0xFFF8FAFC); // slate-50
  static const card        = Colors.white;
  static const navDark     = Color(0xFF231548);
  static const emerald     = Color(0xFF10B981);
  static const amber       = Color(0xFFF59E0B);
  static const red         = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, purple, cyan],
  );

  static const gradientButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryDark, purple],
  );
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppColors.gradientButton,
        color: onPressed == null ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed == null ? [] : [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: loading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(text, style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;

  const AppCard({super.key, required this.child, this.padding, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const StatusBadge({super.key, required this.label, required this.color, required this.bg});

  factory StatusBadge.confirmed() => const StatusBadge(
    label: 'Confirmada', color: Color(0xFF10B981), bg: Color(0xFFECFDF5));
  factory StatusBadge.pending() => const StatusBadge(
    label: 'Pendiente', color: Color(0xFFF59E0B), bg: Color(0xFFFFFBEB));
  factory StatusBadge.cancelled() => const StatusBadge(
    label: 'Cancelada', color: Color(0xFFEF4444), bg: Color(0xFFFEF2F2));

  static StatusBadge fromStatus(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED': return StatusBadge.confirmed();
      case 'PENDING':   return StatusBadge.pending();
      default:          return StatusBadge.cancelled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
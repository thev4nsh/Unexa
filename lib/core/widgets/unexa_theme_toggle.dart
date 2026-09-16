import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/theme/providers/theme_mode_provider.dart';

/// Animated sun/moon theme toggle button (matches the UNEXA prototype header).
///
/// Dark mode  -> shows an animated golden sun with rotating rays (tap = go light).
/// Light mode -> shows a crescent moon with sliding stars (tap = go dark).
class ThemeToggleSun extends ConsumerWidget {
  final double size;

  const ThemeToggleSun({super.key, this.size = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final isDark = mode != ThemeMode.light;

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: () => ref.read(themeModeControllerProvider.notifier).toggle(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.warning.withValues(alpha: 0.16)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: isDark
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _SunMoon(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

class _SunMoon extends StatelessWidget {
  final bool isDark;

  const _SunMoon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isDark ? 1 : 0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Moon: rises into view in dark mode, slides away in light mode.
            Transform.translate(
              offset: Offset(0, (1 - t) * 26 - 2),
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: const _MoonIcon(),
              ),
            ),
            // Sun: rotates its rays and fades out in light mode.
            Transform.rotate(
              angle: t * 2 * 3.14159,
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: const _SunIcon(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SunIcon extends StatelessWidget {
  const _SunIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SunPainter(),
      size: const Size.square(28),
    );
  }
}

class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.shortestSide * 0.22;
    final rayRadius = size.shortestSide * 0.46;

    final corePaint = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.fill;

    final rayPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.07
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, coreRadius, corePaint);

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final start = Offset(
        center.dx + math.cos(angle) * (coreRadius + 2),
        center.dy + math.sin(angle) * (coreRadius + 2),
      );
      final end = Offset(
        center.dx + math.cos(angle) * rayRadius,
        center.dy + math.sin(angle) * rayRadius,
      );
      canvas.drawLine(start, end, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MoonIcon extends StatelessWidget {
  const _MoonIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MoonPainter(),
      size: const Size.square(28),
    );
  }
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.45, size.height / 2);
    final radius = size.shortestSide * 0.34;

    final moonPaint = Paint()
      ..color = AppColors.darkTextPrimary.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addOval(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(
            center.dx + radius * 0.55,
            center.dy - radius * 0.35,
          ),
          radius: radius * 0.85,
        ),
      );
    canvas.drawPath(path, moonPaint);

    // Tiny star accents
    final starPaint = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.30),
      size.shortestSide * 0.045,
      starPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.70, size.height * 0.68),
      size.shortestSide * 0.035,
      starPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

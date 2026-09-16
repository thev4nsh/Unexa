import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Skeleton shimmer loader for smooth loading states without blank screen jumps.
class UnexaLoadingShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double? borderRadius;

  const UnexaLoadingShimmer({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  /// Shimmer card for timetable/announcement loading
  static Widget cardList({int count = 3}) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) => const UnexaLoadingShimmer(height: 84, borderRadius: AppRadius.lg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.md),
        ),
      ),
    );
  }
}

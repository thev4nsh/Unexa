import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Provider that supplies a dynamic light ThemeData styled by the current college's branding colors.
final dynamicLightThemeDataProvider = Provider<ThemeData>((ref) {
  final college = ref.watch(currentCollegeModelProvider).value;
  Color? primary;
  Color? secondary;

  if (college != null) {
    primary = AppColors.parseHex(college.primaryColorHex);
    secondary = AppColors.parseHex(college.secondaryColorHex);
  }

  return AppTheme.light(primary: primary, secondary: secondary);
});

/// Provider that supplies a dynamic dark ThemeData styled by the current college's branding colors.
final dynamicDarkThemeDataProvider = Provider<ThemeData>((ref) {
  final college = ref.watch(currentCollegeModelProvider).value;
  Color? primary;
  Color? secondary;

  if (college != null) {
    primary = AppColors.parseHex(college.primaryColorHex);
    secondary = AppColors.parseHex(college.secondaryColorHex);
  }

  return AppTheme.dark(primary: primary, secondary: secondary);
});

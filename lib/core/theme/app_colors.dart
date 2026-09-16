import 'package:flutter/material.dart';

/// Default premium color palette for UNEXA fallback and base elements.
class AppColors {
  // Brand defaults
  static const Color defaultPrimary = Color(0xFF174C4F);
  static const Color defaultSecondary = Color(0xFF3F5EFB);
  static const Color accent = Color(0xFFE05A47);

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Rose / Red
  static const Color info = Color(0xFF0EA5E9); // Sky

  // Class vs Lab Differentiation
  static const Color classBadge = Color(0xFF2563EB);
  static const Color labBadge = Color(0xFF8B5CF6);

  // Light Mode Neutrals
  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE1E5EC);
  static const Color lightTextPrimary = Color(0xFF151922);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightDivider = Color(0xFFE6E9EF);

  // Dark Mode Neutrals
  static const Color darkBackground = Color(0xFF101114);
  static const Color darkSurface = Color(0xFF1A1D23);
  static const Color darkCardBorder = Color(0xFF2A3039);
  static const Color darkTextPrimary = Color(0xFFF7F8FA);
  static const Color darkTextSecondary = Color(0xFFA8B0BD);
  static const Color darkDivider = Color(0xFF2A3039);

  /// Helper to parse a hex color string like "#1E3A8A" or "0xFF1E3A8A" safely.
  static Color parseHex(String? hexString, {Color fallback = defaultPrimary}) {
    if (hexString == null || hexString.trim().isEmpty) return fallback;
    try {
      String clean = hexString.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Helper to convert a Color to a hex string format `#RRGGBB`.
  static String toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

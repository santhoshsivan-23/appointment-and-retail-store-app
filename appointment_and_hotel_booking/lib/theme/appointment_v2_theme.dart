import 'package:flutter/material.dart';

/// Design tokens and colors for Appointment V2 matching React appointment_v2.css
class AppointmentV2Theme {
  // Background
  static const Color canvasBg = Color(0xFFF8FAF9);
  static const Color cardBg = Colors.white;

  // Forest Palette
  static const Color forest50 = Color(0xFFF0FDF4);
  static const Color forest100 = Color(0xFFDCFCE7);
  static const Color forest200 = Color(0xFFBBF7D0);
  static const Color forest500 = Color(0xFF10B981);
  static const Color forest600 = Color(0xFF059669);
  static const Color forest700 = Color(0xFF047857);
  static const Color forest800 = Color(0xFF065F46);
  static const Color forest900 = Color(0xFF064E3B);

  // Sage Palette
  static const Color sage50 = Color(0xFFF4F7F5);
  static const Color sage100 = Color(0xFFE5ECE7);
  static const Color sage200 = Color(0xFFCBD8CF);
  static const Color sage300 = Color(0xFF9FB5A6);
  static const Color sage400 = Color(0xFF75937F);
  static const Color sage500 = Color(0xFF567561);
  static const Color sage600 = Color(0xFF435C4C);
  static const Color sage700 = Color(0xFF34473B);
  static const Color sage800 = Color(0xFF27352D);
  static const Color sage900 = Color(0xFF1C2620);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSage = Color(0xCCD8CFE0); // sage-200 with opacity

  // Text Colors
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF94A3B8);

  // Staff Avatar Palette (cycling colors matching React)
  static const List<Color> staffBgColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Purple
    Color(0xFFDB2777), // Pink
    Color(0xFFEA580C), // Orange
    Color(0xFF059669), // Green
    Color(0xFF0891B2), // Cyan
    Color(0xFF4F46E5), // Indigo
    Color(0xFFD97706), // Amber
  ];

  /// Get staff background color by index or hex string
  static Color getStaffColor(int index, [String? hex]) {
    if (hex != null && hex.trim().isNotEmpty) {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        final val = int.tryParse('FF$clean', radix: 16);
        if (val != null) return Color(val);
      }
    }
    return staffBgColors[index % staffBgColors.length];
  }

  // Live Current Time Indicator
  static const Color timelineNowIndicator = Color(0xFFEF4444);

  // Card Shadows
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x0D064E3B),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get hoverShadow => [
        const BoxShadow(
          color: Color(0x1F2563EB),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];
}

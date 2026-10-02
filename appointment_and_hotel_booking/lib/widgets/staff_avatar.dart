import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/staff_model.dart';
import '../theme/app_theme.dart';

class StaffAvatar extends StatelessWidget {
  final StaffModel staff;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;

  static final Map<String, Uint8List> _b64Cache = {};

  const StaffAvatar({
    super.key,
    required this.staff,
    required this.radius,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primary;
    final fg = textColor ?? Colors.white;
    final String initial = staff.name.trim().isNotEmpty
        ? staff.name.trim()[0].toUpperCase()
        : '?';

    final textStyle = GoogleFonts.inter(
      fontSize: fontSize ?? (radius * 0.82),
      fontWeight: fontWeight ?? FontWeight.w700,
      color: fg,
    );

    final imgStr = staff.image?.trim();
    if (imgStr != null && imgStr.isNotEmpty) {
      ImageProvider? provider;
      if (imgStr.startsWith('http://') || imgStr.startsWith('https://')) {
        provider = NetworkImage(imgStr);
      } else if (_b64Cache.containsKey(imgStr)) {
        provider = MemoryImage(_b64Cache[imgStr]!);
      } else {
        try {
          final commaIdx = imgStr.indexOf(',');
          final rawB64 = (commaIdx != -1 ? imgStr.substring(commaIdx + 1) : imgStr).replaceAll(RegExp(r'[\s\r\n]+'), '');
          final bytes = base64Decode(rawB64);
          _b64Cache[imgStr] = bytes;
          provider = MemoryImage(bytes);
        } catch (_) {
          provider = null;
        }
      }

      if (provider != null) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image(
              image: provider,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: radius * 2,
                  height: radius * 2,
                  color: bg,
                  alignment: Alignment.center,
                  child: Text(initial, style: textStyle),
                );
              },
            ),
          ),
        );
      }
    }

    // Fallback: Show first letter with existing styling
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: textStyle,
      ),
    );
  }
}

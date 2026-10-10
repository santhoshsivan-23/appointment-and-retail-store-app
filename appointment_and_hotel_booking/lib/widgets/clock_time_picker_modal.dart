import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Analog clock face painter that draws the pivot, dial numbers, rotating hand, and selector bubble
class _ClockDialPainter extends CustomPainter {
  final int selectedValue; // 1-12 for hours, 0-59 for minutes
  final bool isHourMode;
  final double handAngle; // radians from 12 o'clock clockwise
  final double dialRadius;

  _ClockDialPainter({
    required this.selectedValue,
    required this.isHourMode,
    required this.handAngle,
    required this.dialRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = dialRadius;

    // Background dial circle
    final bgPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 28, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius + 28, borderPaint);

    // Calculate hand end position
    final handDx = center.dx + radius * math.sin(handAngle);
    final handDy = center.dy - radius * math.cos(handAngle);
    final handEnd = Offset(handDx, handDy);

    // Hand line
    final handLinePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, handEnd, handLinePaint);

    // Hand selector bubble
    final bubblePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handEnd, 16.0, bubblePaint);

    // Center pivot
    final pivotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, pivotPaint);

    // Draw dial numbers
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (isHourMode) {
      // 12 hours
      for (int h = 1; h <= 12; h++) {
        final angle = (h * 30.0) * math.pi / 180.0;
        final nx = center.dx + radius * math.sin(angle);
        final ny = center.dy - radius * math.cos(angle);
        final isSelected = h == (selectedValue == 0 ? 12 : selectedValue);

        final textSpan = TextSpan(
          text: '$h',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        );
        textPainter.text = textSpan;
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(nx - textPainter.width / 2, ny - textPainter.height / 2),
        );
      }
    } else {
      // Minutes (every 5 mins shows number, others show dots)
      for (int m = 0; m < 60; m += 5) {
        final angle = (m * 6.0) * math.pi / 180.0;
        final nx = center.dx + radius * math.sin(angle);
        final ny = center.dy - radius * math.cos(angle);
        final isSelected = (m == selectedValue) || (m == 0 && selectedValue == 60);

        final text = m.toString().padLeft(2, '0');
        final textSpan = TextSpan(
          text: text,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        );
        textPainter.text = textSpan;
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(nx - textPainter.width / 2, ny - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) {
    return oldDelegate.selectedValue != selectedValue ||
        oldDelegate.isHourMode != isHourMode ||
        oldDelegate.handAngle != handAngle ||
        oldDelegate.dialRadius != dialRadius;
  }
}

/// Clock Time Picker Modal matching React ClockTimePickerModal.tsx
class ClockTimePickerModal extends StatefulWidget {
  final String initialTime24; // e.g. "08:30"
  final String label;
  final ValueChanged<String> onSelectTime;
  final VoidCallback onClose;

  const ClockTimePickerModal({
    super.key,
    required this.initialTime24,
    this.label = 'Select Time',
    required this.onSelectTime,
    required this.onClose,
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialTime24,
    String label = 'Select Time',
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => ClockTimePickerModal(
        initialTime24: initialTime24,
        label: label,
        onClose: () => Navigator.pop(ctx),
        onSelectTime: (time24) => Navigator.pop(ctx, time24),
      ),
    );
  }

  @override
  State<ClockTimePickerModal> createState() => _ClockTimePickerModalState();
}

class _ClockTimePickerModalState extends State<ClockTimePickerModal> {
  bool _isHourMode = true;
  late int _hour12;
  late int _minute;
  late bool _isPM;
  double _handAngle = 0.0;
  static const double _dialRadius = 86.0;

  @override
  void initState() {
    super.initState();
    _parseInitialTime();
  }

  void _parseInitialTime() {
    final parts = (widget.initialTime24.isEmpty ? '08:00' : widget.initialTime24).split(':');
    final h24 = int.tryParse(parts[0]) ?? 8;
    final m = (parts.length > 1 ? int.tryParse(parts[1]) : 0) ?? 0;

    _isPM = h24 >= 12;
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;

    _hour12 = h12;
    _minute = m.clamp(0, 59);
    _isHourMode = true;
    _handAngle = (_hour12 * 30.0) * math.pi / 180.0;
  }

  String _getTime24() {
    var h24 = _hour12;
    if (_isPM) {
      if (_hour12 < 12) h24 = _hour12 + 12;
    } else {
      if (_hour12 == 12) h24 = 0;
    }
    final hStr = h24.toString().padLeft(2, '0');
    final mStr = _minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  void _handleAngleUpdate(Offset localPos, Size size, {bool isFinal = false}) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    // Angle in radians from 12 o'clock clockwise
    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * math.pi;

    final deg = angle * 180.0 / math.pi;

    if (_isHourMode) {
      var h = (deg / 30.0).round() % 12;
      if (h == 0) h = 12;
      setState(() {
        _hour12 = h;
        _handAngle = (h * 30.0) * math.pi / 180.0;
      });

      if (isFinal) {
        // Auto-advance to minutes mode smoothly after hour selection
        Future.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          setState(() {
            _isHourMode = false;
            _handAngle = (_minute * 6.0) * math.pi / 180.0;
          });
        });
      }
    } else {
      final m = (deg / 6.0).round() % 60;
      setState(() {
        _minute = m;
        _handAngle = (m * 6.0) * math.pi / 180.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          elevation: 16,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF1E40AF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.label,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                        splashRadius: 18,
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // 2. Digital Display & AM/PM Switcher Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Digital hour & minute pills
                        Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _isHourMode = true;
                                  _handAngle = (_hour12 * 30.0) * math.pi / 180.0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isHourMode ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isHourMode ? const Color(0xFF3B82F6) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _hour12.toString().padLeft(2, '0'),
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _isHourMode ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                ':',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _isHourMode = false;
                                  _handAngle = (_minute * 6.0) * math.pi / 180.0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: !_isHourMode ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !_isHourMode ? const Color(0xFF3B82F6) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _minute.toString().padLeft(2, '0'),
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: !_isHourMode ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // AM / PM Segmented Switcher
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                key: const Key('clock_modal_am_btn'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _isPM = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: !_isPM ? const Color(0xFF1D4ED8) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'AM',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: !_isPM ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                key: const Key('clock_modal_pm_btn'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _isPM = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _isPM ? const Color(0xFF1D4ED8) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    'PM',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _isPM ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. Radial Analog Clock Face
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dialSize = Size(constraints.maxWidth, constraints.maxHeight);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (d) => _handleAngleUpdate(d.localPosition, dialSize, isFinal: false),
                        onPanUpdate: (d) => _handleAngleUpdate(d.localPosition, dialSize, isFinal: false),
                        onPanEnd: (_) => _handleAngleUpdate(Offset.zero, dialSize, isFinal: true),
                        onTapUp: (d) => _handleAngleUpdate(d.localPosition, dialSize, isFinal: true),
                        child: CustomPaint(
                          size: dialSize,
                          painter: _ClockDialPainter(
                            selectedValue: _isHourMode ? _hour12 : _minute,
                            isHourMode: _isHourMode,
                            handAngle: _handAngle,
                            dialRadius: _dialRadius,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Mode hint pill
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isHourMode ? 'Select Hour on Dial' : 'Select Minute on Dial',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 4. Footer Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onClose,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => widget.onSelectTime(_getTime24()),
                      icon: const Icon(Icons.check, size: 15),
                      label: Text(
                        'Confirm Time',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/appointment_v2_utils.dart';

/// Interactive drum wheel column with smooth step, drag, and looping
class _WheelColumn extends StatefulWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool loop;
  final Color activeColor;
  static const double itemHeight = 34.0;

  const _WheelColumn({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.loop = true,
    required this.activeColor,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late FixedExtentScrollController _controller;
  static const int _loopMultiplier = 1000;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.loop
        ? (widget.items.length * (_loopMultiplier ~/ 2)) + widget.selectedIndex
        : widget.selectedIndex;
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(covariant _WheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && _controller.hasClients) {
      final currentReal = _controller.selectedItem % widget.items.length;
      if (currentReal != widget.selectedIndex) {
        final target = widget.loop
            ? _controller.selectedItem + (widget.selectedIndex - currentReal)
            : widget.selectedIndex;
        _controller.animateToItem(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stepBy(int delta) {
    if (!_controller.hasClients) return;
    _controller.animateToItem(
      _controller.selectedItem + delta,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Drum wheel scroll view
        SizedBox(
          height: 170,
          child: ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: _WheelColumn.itemHeight,
            physics: const FixedExtentScrollPhysics(),
            perspective: 0.003,
            diameterRatio: 1.8,
            squeeze: 1.15,
            onSelectedItemChanged: (index) {
              final realIndex = widget.loop ? (index % count + count) % count : index.clamp(0, count - 1);
              widget.onSelect(realIndex);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final realIndex = (index % count + count) % count;
                final isCenter = _controller.hasClients && _controller.selectedItem == index;
                final text = widget.items[realIndex];

                return Center(
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: isCenter ? FontWeight.w800 : FontWeight.w600,
                      color: isCenter ? widget.activeColor : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
              childCount: widget.loop ? count * _loopMultiplier : count,
            ),
          ),
        ),

        // Subtle up chevron button on top
        Positioned(
          top: 2,
          child: InkWell(
            onTap: () => _stepBy(-1),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Icon(Icons.keyboard_arrow_up, size: 16, color: Color(0xFF94A3B8)),
            ),
          ),
        ),

        // Subtle down chevron button on bottom
        Positioned(
          bottom: 2,
          child: InkWell(
            onTap: () => _stepBy(1),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drum Wheel Time Picker matching React WheelTimePicker.tsx
class WheelTimePicker extends StatelessWidget {
  final String value; // "HH:MM" 24h format
  final ValueChanged<String> onChange;
  final String? label;
  final String timeFormat; // '12' or '24'

  const WheelTimePicker({
    super.key,
    required this.value,
    required this.onChange,
    this.label,
    this.timeFormat = '12',
  });

  static const _hours12 = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  static final _hours24 = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  static final _minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  static const _periods = ['AM', 'PM'];

  @override
  Widget build(BuildContext context) {
    final parts = (value.isEmpty ? '08:00' : value).split(':');
    final hour24 = int.tryParse(parts[0]) ?? 8;
    final minute = (parts.length > 1 ? int.tryParse(parts[1]) : 0) ?? 0;

    final isPM = hour24 >= 12;
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hour12Idx = hour12 - 1;
    final hour24Idx = hour24.clamp(0, 23);
    final minuteIdx = minute.clamp(0, 59);
    final periodIdx = isPM ? 1 : 0;

    void updateTime({int? newH24, int? newM}) {
      final h = (newH24 ?? hour24).clamp(0, 23);
      final m = (newM ?? minute).clamp(0, 59);
      final hStr = h.toString().padLeft(2, '0');
      final mStr = m.toString().padLeft(2, '0');
      onChange('$hStr:$mStr');
    }

    void onSelectHour12(int idx) {
      final h12 = idx + 1;
      var h24 = h12;
      if (isPM) {
        if (h12 < 12) h24 = h12 + 12;
      } else {
        if (h12 == 12) h24 = 0;
      }
      updateTime(newH24: h24);
    }

    void onSelectHour24(int idx) {
      updateTime(newH24: idx);
    }

    void onSelectMinute(int idx) {
      updateTime(newM: idx);
    }

    void onSelectPeriod(int idx) {
      final selectingPM = idx == 1;
      var h24 = hour24;
      if (selectingPM && h24 < 12) {
        h24 += 12;
      } else if (!selectingPM && h24 >= 12) {
        h24 -= 12;
      }
      updateTime(newH24: h24);
    }

    final formattedPreview = timeFormat == '24'
        ? value
        : formatTime12(value);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with label and preview badge
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2, right: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      formattedPreview,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Drum Wheel Cylinder Container
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Center Selection Highlight Bar
                Positioned(
                  top: 68,
                  left: 0,
                  right: 0,
                  height: 34,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0x3DF1F5F9),
                      border: Border(
                        top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Top Gradient Fade Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 44,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xF2FFFFFF),
                            Color(0x8CFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Gradient Fade Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 44,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xF2FFFFFF),
                            Color(0x8CFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Wheel Columns Row
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hours Column (Royal Blue font)
                        Expanded(
                          child: _WheelColumn(
                            items: timeFormat == '24' ? _hours24 : _hours12,
                            selectedIndex: timeFormat == '24' ? hour24Idx : hour12Idx,
                            onSelect: timeFormat == '24' ? onSelectHour24 : onSelectHour12,
                            activeColor: const Color(0xFF1D4ED8),
                          ),
                        ),

                        // Colon Separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ':',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),

                        // Minutes Column (Deep Slate font)
                        Expanded(
                          child: _WheelColumn(
                            items: _minutes,
                            selectedIndex: minuteIdx,
                            onSelect: onSelectMinute,
                            activeColor: const Color(0xFF0F172A),
                          ),
                        ),

                        // AM/PM Column (if 12-hour mode)
                        if (timeFormat != '24') ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: _WheelColumn(
                              items: _periods,
                              selectedIndex: periodIdx,
                              onSelect: onSelectPeriod,
                              loop: false,
                              activeColor: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

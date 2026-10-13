import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DateRangeResult {
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD

  const DateRangeResult({
    required this.startDate,
    required this.endDate,
  });
}

const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

const List<String> _kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatDate(DateTime dt) {
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _formatPrettyShort(String dateStr) {
  try {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return '${_kMonthShort[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return dateStr;
  }
}

DateTime? _parseDate(String dateStr) {
  try {
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  } catch (_) {
    return null;
  }
}

class DateRangeFilterWidget extends StatelessWidget {
  final String startDate;
  final String endDate;
  final ValueChanged<DateRangeResult> onDateRangeChanged;

  const DateRangeFilterWidget({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

  String _formatDisplayLabel() {
    if (startDate.isEmpty) return 'Select Date';
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    // This week (Monday to today)
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final monday = now.subtract(Duration(days: dayOfWeek - 1));
    final thisWeekStart = _formatDate(monday);

    // This month
    final thisMonthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    // Last month
    final lastMonthLastDay = DateTime(now.year, now.month, 0);
    final lastMonthFirstDay = DateTime(lastMonthLastDay.year, lastMonthLastDay.month, 1);
    final lastMonthStart = _formatDate(lastMonthFirstDay);
    final lastMonthEnd = _formatDate(lastMonthLastDay);

    if (startDate == todayStr && endDate == todayStr) return 'Today';
    if (startDate == yesterdayStr && endDate == yesterdayStr) return 'Yesterday';
    if (startDate == thisWeekStart && endDate == todayStr) return 'This Week';
    if (startDate == thisMonthStart && endDate == todayStr) return 'This Month';
    if (startDate == lastMonthStart && endDate == lastMonthEnd) return 'Last Month';

    if (startDate == endDate) {
      return _formatPrettyShort(startDate);
    }
    return '${_formatPrettyShort(startDate)} – ${_formatPrettyShort(endDate)}';
  }

  void _handleQuickOption(BuildContext context, String value) {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    switch (value) {
      case 'today':
        onDateRangeChanged(DateRangeResult(startDate: todayStr, endDate: todayStr));
        break;
      case 'yesterday':
        final yStr = _formatDate(now.subtract(const Duration(days: 1)));
        onDateRangeChanged(DateRangeResult(startDate: yStr, endDate: yStr));
        break;
      case 'this_week':
        final dayOfWeek = now.weekday;
        final monday = now.subtract(Duration(days: dayOfWeek - 1));
        onDateRangeChanged(DateRangeResult(startDate: _formatDate(monday), endDate: todayStr));
        break;
      case 'this_month':
        final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        onDateRangeChanged(DateRangeResult(startDate: start, endDate: todayStr));
        break;
      case 'last_month':
        final lastDay = DateTime(now.year, now.month, 0);
        final firstDay = DateTime(lastDay.year, lastDay.month, 1);
        onDateRangeChanged(DateRangeResult(
          startDate: _formatDate(firstDay),
          endDate: _formatDate(lastDay),
        ));
        break;
      case 'custom':
        _openCalendarModal(context);
        break;
    }
  }

  Future<void> _openCalendarModal(BuildContext context) async {
    final result = await showDialog<DateRangeResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => DateRangePickerDialog(
        initialStartDate: startDate,
        initialEndDate: endDate,
      ),
    );
    if (result != null) {
      onDateRangeChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () async {
            final renderBox = btnContext.findRenderObject() as RenderBox?;
            final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
            final size = renderBox?.size ?? Size.zero;

            final selected = await showMenu<String>(
              context: btnContext,
              position: RelativeRect.fromLTRB(
                offset.dx,
                offset.dy + size.height + 6,
                offset.dx + 220,
                offset.dy + size.height + 340,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8,
              color: Colors.white,
              items: [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 28,
                  child: Text(
                    'QUICK DATE FILTER',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildQuickMenuItem('today', 'Today', Icons.today_rounded),
                _buildQuickMenuItem('yesterday', 'Yesterday', Icons.history_rounded),
                _buildQuickMenuItem('this_week', 'This Week', Icons.date_range_rounded),
                _buildQuickMenuItem('this_month', 'This Month', Icons.calendar_view_month_rounded),
                _buildQuickMenuItem('last_month', 'Last Month', Icons.calendar_month_outlined),
                const PopupMenuDivider(height: 10),
                PopupMenuItem<String>(
                  value: 'custom',
                  height: 38,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Text(
                        'Custom Date Range...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (selected != null && btnContext.mounted) {
              _handleQuickOption(btnContext, selected);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Color(0xFFE11D48),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDisplayLabel(),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildQuickMenuItem(String key, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: key,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CENTERED MODAL CALENDAR (MATCHING EXACT UPLOADED IMAGE)
// =============================================================================
class DateRangePickerDialog extends StatefulWidget {
  final String initialStartDate;
  final String initialEndDate;

  const DateRangePickerDialog({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  State<DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  late DateTime _selectedStart;
  late DateTime _selectedEnd;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedStart = _parseDate(widget.initialStartDate) ?? now;
    _selectedEnd = _parseDate(widget.initialEndDate) ?? _selectedStart;
    _displayedMonth = DateTime(_selectedEnd.year, _selectedEnd.month, 1);
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      if (_isSameDay(_selectedStart, _selectedEnd)) {
        if (day.isBefore(_selectedStart)) {
          _selectedStart = day;
        } else {
          _selectedEnd = day;
        }
      } else {
        // Start a fresh range
        _selectedStart = day;
        _selectedEnd = day;
      }
    });
  }

  void _applyChipRange(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    setState(() {
      _selectedStart = start;
      _selectedEnd = now;
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    setState(() {
      _selectedStart = start;
      _selectedEnd = now;
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  // 5-Item Scrollable Selector Dialog (displays 5 items at a time with inner scroll)
  Future<void> _openMonthPicker(BuildContext context) async {
    final selectedMonth = await _showScrollablePicker<int>(
      context: context,
      title: 'SELECT MONTH',
      items: List.generate(12, (i) => i + 1),
      selectedItem: _displayedMonth.month,
      itemLabel: (m) => _kMonthNames[m - 1],
    );
    if (selectedMonth != null && mounted) {
      setState(() {
        _displayedMonth = DateTime(_displayedMonth.year, selectedMonth, 1);
      });
    }
  }

  Future<void> _openYearPicker(BuildContext context) async {
    final currentYear = DateTime.now().year;
    final years = List.generate(16, (i) => currentYear - 8 + i);
    final selectedYear = await _showScrollablePicker<int>(
      context: context,
      title: 'SELECT YEAR',
      items: years,
      selectedItem: _displayedMonth.year,
      itemLabel: (y) => '$y',
    );
    if (selectedYear != null && mounted) {
      setState(() {
        _displayedMonth = DateTime(selectedYear, _displayedMonth.month, 1);
      });
    }
  }

  Future<T?> _showScrollablePicker<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required T selectedItem,
    required String Function(T) itemLabel,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Divider(height: 12, color: Color(0xFFF1F5F9)),
                // Display exactly 5 items visible at a time with inner scrolling (5 * 40 = 200px)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemExtent: 40,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = item == selectedItem;
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: isSelected ? const Color(0xFFFFF1F2) : Colors.transparent,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                itemLabel(item),
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFFE11D48)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (Calendar icon badge, Title, Close 'X' button)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Select Date Range',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Preset Chips Row (7 Days, 14 Days, 30 Days, This Month, 3 Months)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('7 Days', () => _applyChipRange(7)),
                        const SizedBox(width: 8),
                        _buildPresetChip('14 Days', () => _applyChipRange(14)),
                        const SizedBox(width: 8),
                        _buildPresetChip('30 Days', () => _applyChipRange(30)),
                        const SizedBox(width: 8),
                        _buildPresetChip('This Month', _applyThisMonth),
                        const SizedBox(width: 8),
                        _buildPresetChip('3 Months', () => _applyChipRange(90)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Month & Year Navigation Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month - 1,
                              1,
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),

                      // Month & Year Clickable Selectors
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _openMonthPicker(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _kMonthNames[_displayedMonth.month - 1],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _openYearPicker(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_displayedMonth.year}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      InkWell(
                        onTap: () {
                          setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month + 1,
                              1,
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Weekdays Header: S M T W T F S (Exact match to image)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((w) => SizedBox(
                              width: 38,
                              child: Center(
                                child: Text(
                                  w,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),

                  // 5. Days Grid
                  _buildCalendarDaysGrid(),
                  const SizedBox(height: 18),

                  // 6. Modal Footer (Exact Match to Image)
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: SELECTED RANGE caption & formatted value
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECTED RANGE',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatPrettyShort(_formatDate(_selectedStart))} - ${_formatPrettyShort(_formatDate(_selectedEnd))}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),

                        // Right: Cancel & Apply buttons
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(DateRangeResult(
                                  startDate: _formatDate(_selectedStart),
                                  endDate: _formatDate(_selectedEnd),
                                ));
                              },
                              child: Text(
                                'Apply',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarDaysGrid() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    // Sunday-first offset: Sunday=7 in Dart -> 0 offset; Mon=1 -> 1 offset
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final cells = <Widget>[];

    // Leading blanks
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox(width: 38, height: 38));
    }

    // Days in current month
    for (int d = 1; d <= daysInMonth; d++) {
      final cellDate = DateTime(year, month, d);
      final isStart = _isSameDay(cellDate, _selectedStart);
      final isEnd = _isSameDay(cellDate, _selectedEnd);
      final inRange = cellDate.isAfter(_selectedStart) && cellDate.isBefore(_selectedEnd);

      cells.add(
        InkWell(
          onTap: () => _onDaySelected(cellDate),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isStart || isEnd
                  ? const Color(0xFFE11D48)
                  : inRange
                      ? const Color(0xFFFFF1F2)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isStart || isEnd
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$d',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: isStart || isEnd
                    ? FontWeight.w700
                    : inRange
                        ? FontWeight.w700
                        : FontWeight.w500,
                color: isStart || isEnd
                    ? Colors.white
                    : inRange
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: cells,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

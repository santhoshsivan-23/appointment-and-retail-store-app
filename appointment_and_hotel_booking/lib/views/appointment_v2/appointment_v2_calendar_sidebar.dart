import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/appointment_model.dart';
import '../../models/staff_model.dart';
import '../../theme/appointment_v2_theme.dart';
import '../../utils/appointment_v2_utils.dart';

/// Right Sidebar for Appointment V2 (Calendar & Status Section)
/// Matches React AppointmentV2Calender.tsx
class AppointmentV2CalendarSidebar extends StatelessWidget {
  final StaffModel selectedStaff;
  final String selectedDate;
  final DateTime calendarViewDate;
  final List<AppointmentModel> appointments;
  final DayStats dayStats;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<DateTime> onChangeCalendarMonth;
  final VoidCallback onSwitchStaff;
  final double? width;

  const AppointmentV2CalendarSidebar({
    super.key,
    required this.selectedStaff,
    required this.selectedDate,
    required this.calendarViewDate,
    required this.appointments,
    required this.dayStats,
    required this.onSelectDate,
    required this.onChangeCalendarMonth,
    required this.onSwitchStaff,
    this.width,
  });

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'ST';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 380,
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 6, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Widget 1: Monthly Calendar Card
            _buildCalendarCard(),

            const SizedBox(height: 16),

            // Widget 2: Day Status Summary Card
            _buildSummaryCard(),

            const SizedBox(height: 16),

            // Widget 3: Active Staff Profile Card
            _buildStaffProfileCard(),
          ],
        ),
      ),
    );
  }

  // Widget 1: Monthly Calendar
  Widget _buildCalendarCard() {
    final year = calendarViewDate.year;
    final month = calendarViewDate.month;
    final monthTitle = '${_months[month - 1]} $year';
    final todayStr = getTodayDateStr();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCD8CFE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D064E3B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calendar Header: Month Title & Navigation Group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: () {
                      final prevMonth = DateTime(year, month - 1, 1);
                      onChangeCalendarMonth(prevMonth);
                    },
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      final today = DateTime.now();
                      onChangeCalendarMonth(today);
                      onSelectDate(todayStr);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Today',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildNavBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: () {
                      final nextMonth = DateTime(year, month + 1, 1);
                      onChangeCalendarMonth(nextMonth);
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Weekdays Row (Su, Mo, Tu, We, Th, Fr, Sa)
          Row(
            children: _weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      day,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 4),

          // Calendar Days Grid
          _buildCalendarDaysGrid(year, month, todayStr),
        ],
      ),
    );
  }

  Widget _buildNavBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: const Color(0xFF475569)),
      ),
    );
  }

  Widget _buildCalendarDaysGrid(int year, int month, String todayStr) {
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0 for Sunday
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final daysInPrevMonth = DateUtils.getDaysInMonth(year, month == 1 ? 12 : month - 1);

    final List<Widget> dayCells = [];

    // 1. Previous month trailing days
    for (int i = firstWeekday - 1; i >= 0; i--) {
      final prevDay = daysInPrevMonth - i;
      dayCells.add(
        Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              '$prevDay',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      );
    }

    // 2. Current month days
    for (int d = 1; d <= daysInMonth; d++) {
      final mStr = month.toString().padLeft(2, '0');
      final dStr = d.toString().padLeft(2, '0');
      final dateStr = '$year-$mStr-$dStr';

      final isCurrentDay = (dateStr == todayStr);
      final isSelected = (dateStr == selectedDate);
      final hasAppts = appointments.any((a) => a.appointmentDate == dateStr);

      dayCells.add(
        Center(
          child: InkWell(
            onTap: () => onSelectDate(dateStr),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : isCurrentDay
                        ? const Color(0xFFEFF6FF)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? null
                    : isCurrentDay
                        ? Border.all(color: const Color(0xFF93C5FD), width: 1.5)
                        : null,
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x402563EB),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$d',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected || isCurrentDay ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isCurrentDay
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF334155),
                    ),
                  ),
                  if (hasAppts)
                    Positioned(
                      bottom: 2.5,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3. Next month trailing days to complete full grid
    final totalSoFar = dayCells.length;
    final remaining = (7 - (totalSoFar % 7)) % 7;
    final totalSlotsNeeded = (totalSoFar + remaining < 35) ? (35 - totalSoFar) : remaining;

    for (int n = 1; n <= totalSlotsNeeded; n++) {
      dayCells.add(
        Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 4,
      crossAxisSpacing: 2,
      children: dayCells,
    );
  }

  // Widget 2: Day Status Summary Card
  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCD8CFE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D064E3B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Summary for ${formatDatePretty(selectedDate)}',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),

          // 2-Column Grid of 6 Status Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              // 1. Total Appts
              _buildStatCard(
                title: 'TOTAL APPTS',
                count: dayStats.total,
                icon: Icons.calendar_month_outlined,
                bg: const Color(0xFFEFF6FF),
                border: const Color(0xFFBFDBFE),
                textPrimary: const Color(0xFF1E3A8A),
                textLabel: const Color(0xFF1D4ED8),
                iconBg: const Color(0xFFDBEAFE),
              ),

              // 2. Booked
              _buildStatCard(
                title: 'BOOKED',
                count: dayStats.booked,
                icon: Icons.schedule_outlined,
                bg: const Color(0xFFFFF1F2),
                border: const Color(0xFFFECDD3),
                textPrimary: const Color(0xFFE11D48),
                textLabel: const Color(0xFFBE123C),
                iconBg: const Color(0xFFFFE4E6),
              ),

              // 3. In Service
              _buildStatCard(
                title: 'IN SERVICE',
                count: dayStats.inService,
                icon: Icons.play_circle_outline_rounded,
                bg: const Color(0xFFFFFBEB),
                border: const Color(0xFFFDE68A),
                textPrimary: const Color(0xFFB45309),
                textLabel: const Color(0xFF92400E),
                iconBg: const Color(0xFFFEF3C7),
              ),

              // 4. Completed
              _buildStatCard(
                title: 'COMPLETED',
                count: dayStats.completed,
                icon: Icons.check_circle_outline_rounded,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                textPrimary: const Color(0xFF059669),
                textLabel: const Color(0xFF065F46),
                iconBg: const Color(0xFFD1FAE5),
              ),

              // 5. No Show
              _buildStatCard(
                title: 'NO SHOW',
                count: dayStats.noShow,
                icon: Icons.person_off_outlined,
                bg: const Color(0xFFFEF2F2),
                border: const Color(0xFFFECACA),
                textPrimary: const Color(0xFFDC2626),
                textLabel: const Color(0xFFB91C1C),
                iconBg: const Color(0xFFFEE2E2),
              ),

              // 6. Cancelled
              _buildStatCard(
                title: 'CANCELLED',
                count: dayStats.cancelled,
                icon: Icons.cancel_outlined,
                bg: const Color(0xFFF8FAFC),
                border: const Color(0xFFE2E8F0),
                textPrimary: const Color(0xFF334155),
                textLabel: const Color(0xFF475569),
                iconBg: const Color(0xFFF1F5F9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color textPrimary,
    required Color textLabel,
    required Color iconBg,
  }) {
    return Container(
      key: ValueKey('stat_${title.toLowerCase().replaceAll(' ', '_')}'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textLabel,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 13, color: textPrimary),
              ),
            ],
          ),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Widget 3: Active Staff Profile Card
  Widget _buildStaffProfileCard() {
    final staffBg = AppointmentV2Theme.getStaffColor(0, selectedStaff.colorCode);
    final initials = _getInitials(selectedStaff.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCD8CFE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D064E3B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: staffBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedStaff.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedStaff.role.isNotEmpty ? selectedStaff.role : 'Specialist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onSwitchStaff,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Change',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

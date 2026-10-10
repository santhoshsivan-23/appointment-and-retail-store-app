import 'package:flutter/material.dart';
import '../models/appointment_model.dart';

/// Represents a discrete business time slot (e.g. 08:00 – 08:30)
class BusinessSlot {
  final String start24;
  final String end24;
  final int startM;
  final int endM;
  final String startLabel;
  final String endLabel;
  final String label;

  const BusinessSlot({
    required this.start24,
    required this.end24,
    required this.startM,
    required this.endM,
    required this.startLabel,
    required this.endLabel,
    required this.label,
  });
}

/// Represents a discrete time point for picker lists (e.g. 08:30)
class TimePoint {
  final String time24;
  final String label12;
  final int minutes;

  const TimePoint({
    required this.time24,
    required this.label12,
    required this.minutes,
  });
}

/// Status metadata with rich visual tokens matching React V2_STATUS_MAP
class V2StatusMeta {
  final String key;
  final String label;
  final String colorName;
  final Color color;
  final Color bg;
  final Color border;
  final Color badgeBg;
  final Color badgeText;

  const V2StatusMeta({
    required this.key,
    required this.label,
    required this.colorName,
    required this.color,
    required this.bg,
    required this.border,
    required this.badgeBg,
    required this.badgeText,
  });
}

/// Aggregated status counts for a selected day in Appointment V2
class DayStats {
  final int total;
  final int booked;
  final int inService;
  final int completed;
  final int noShow;
  final int cancelled;

  const DayStats({
    this.total = 0,
    this.booked = 0,
    this.inService = 0,
    this.completed = 0,
    this.noShow = 0,
    this.cancelled = 0,
  });

  factory DayStats.fromAppointments(List<AppointmentModel> appointments) {
    int total = appointments.length;
    int booked = 0;
    int inService = 0;
    int completed = 0;
    int noShow = 0;
    int cancelled = 0;

    for (final a in appointments) {
      if (a.isInService) {
        inService++;
      } else if (a.isCompleted) {
        completed++;
      } else if (a.isNoShow) {
        noShow++;
      } else if (a.isCancelled) {
        cancelled++;
      } else {
        booked++;
      }
    }

    return DayStats(
      total: total,
      booked: booked,
      inService: inService,
      completed: completed,
      noShow: noShow,
      cancelled: cancelled,
    );
  }
}


class V2StatusMap {
  static const booked = V2StatusMeta(
    key: 'booked',
    label: 'Booked',
    colorName: 'Blue',
    color: Color(0xFF2563EB),
    bg: Color(0xFFEFF6FF),
    border: Color(0xFF3B82F6),
    badgeBg: Color(0xFFDBEAFE),
    badgeText: Color(0xFF1E40AF),
  );

  static const inService = V2StatusMeta(
    key: 'in_service',
    label: 'In Service',
    colorName: 'Orange',
    color: Color(0xFFD97706),
    bg: Color(0xFFFFFBEB),
    border: Color(0xFFF59E0B),
    badgeBg: Color(0xFFFEF3C7),
    badgeText: Color(0xFFB45309),
  );

  static const completed = V2StatusMeta(
    key: 'completed',
    label: 'Completed',
    colorName: 'Green',
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
    border: Color(0xFF10B981),
    badgeBg: Color(0xFFD1FAE5),
    badgeText: Color(0xFF065F46),
  );

  static const noShow = V2StatusMeta(
    key: 'no_show',
    label: 'No Show',
    colorName: 'Red',
    color: Color(0xFFDC2626),
    bg: Color(0xFFFEF2F2),
    border: Color(0xFFEF4444),
    badgeBg: Color(0xFFFEE2E2),
    badgeText: Color(0xFFDC2626),
  );

  static const cancelled = V2StatusMeta(
    key: 'cancelled',
    label: 'Cancelled',
    colorName: 'Grey',
    color: Color(0xFF6B7280),
    bg: Color(0xFFF9FAFB),
    border: Color(0xFFD1D5DB),
    badgeBg: Color(0xFFF3F4F6),
    badgeText: Color(0xFF4B5563),
  );
}

/// Resolve status metadata with fallback to 'booked'
V2StatusMeta getStatusMeta(String? status) {
  final norm = (status ?? 'booked').toLowerCase().trim().replaceAll('-', '_');
  if (norm == 'inservice' || norm == 'in_service') return V2StatusMap.inService;
  if (norm == 'completed') return V2StatusMap.completed;
  if (norm == 'noshow' || norm == 'no_show') return V2StatusMap.noShow;
  if (norm == 'cancelled' || norm == 'canceled') return V2StatusMap.cancelled;
  return V2StatusMap.booked;
}

/// Converts "HH:MM" 24h string into total minutes from midnight
int timeToMinutes(String time24) {
  if (time24.trim().isEmpty) return 0;
  final parts = time24.trim().split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
  return 0;
}

/// Converts total minutes from midnight into "HH:MM" 24h string
String minutesToTime24(int totalMinutes) {
  final h = ((totalMinutes ~/ 60) % 24).toString().padLeft(2, '0');
  final m = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats "HH:MM" into standard 12-hour format e.g. "8:30 AM" or "12:00 PM"
String formatTime12(String time24) {
  if (time24.trim().isEmpty) return '--:--';
  final mins = timeToMinutes(time24);
  final h24 = (mins ~/ 60) % 24;
  final m = mins % 60;
  final period = h24 >= 12 ? 'PM' : 'AM';
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// Formats "HH:MM" into leading zero 12-hour format e.g. "08:30 AM"
String formatTime12Leading(String time24) {
  if (time24.trim().isEmpty) return '--:--';
  final mins = timeToMinutes(time24);
  final h24 = (mins ~/ 60) % 24;
  final m = mins % 60;
  final period = h24 >= 12 ? 'PM' : 'AM';
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
}

/// Formats slot range with leading zeros e.g. "08:00 AM - 08:30 AM"
String formatSlotRangeLeading(String start24, String end24) {
  return '${formatTime12Leading(start24)} - ${formatTime12Leading(end24)}';
}

/// Formats slot label based on preferred format ('12' or '24')
String formatTimeSlotLabel(String start24, String end24, [String format = '12']) {
  if (format == '24') {
    return '$start24 – $end24';
  }
  return '${formatTime12(start24)} – ${formatTime12(end24)}';
}

/// Get today's date formatted as "YYYY-MM-DD"
String getTodayDateStr() {
  final now = DateTime.now();
  final y = now.year.toString();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Formats "YYYY-MM-DD" into pretty format e.g. "Wed, Oct 9, 2026"
String formatDatePretty(String dateStr) {
  if (dateStr.trim().isEmpty) return '';
  final parts = dateStr.trim().split('-');
  if (parts.length != 3) return dateStr;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return dateStr;

  final dt = DateTime(y, m, d);
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final weekday = weekdays[dt.weekday - 1];
  final month = months[dt.month - 1];
  return '$weekday, $month $d, $y';
}

/// Generates all interval slots (default 30-min) between openTime and closeTime
List<BusinessSlot> generateBusinessSlots({
  String openTime = '08:00',
  String closeTime = '20:00',
  int intervalMinutes = 30,
}) {
  final startM = timeToMinutes(openTime);
  final endM = timeToMinutes(closeTime);
  final effectiveEnd = endM > startM ? endM : 20 * 60;
  final slots = <BusinessSlot>[];

  var cur = startM;
  while (cur + intervalMinutes <= effectiveEnd) {
    final next = cur + intervalMinutes;
    final start24 = minutesToTime24(cur);
    final end24 = minutesToTime24(next);
    slots.add(
      BusinessSlot(
        start24: start24,
        end24: end24,
        startM: cur,
        endM: next,
        startLabel: formatTime12(start24),
        endLabel: formatTime12(end24),
        label: '${formatTime12(start24)} – ${formatTime12(end24)}',
      ),
    );
    cur = next;
  }

  return slots;
}

/// Generates discrete time points for Start/End time selection
List<TimePoint> generateTimePoints({
  String openTime = '08:00',
  String closeTime = '20:00',
  int stepMinutes = 30,
}) {
  final startM = timeToMinutes(openTime);
  final endM = timeToMinutes(closeTime);
  final effectiveEnd = endM > startM ? endM : 20 * 60;
  final points = <TimePoint>[];

  var cur = startM;
  while (cur <= effectiveEnd) {
    final time24 = minutesToTime24(cur);
    points.add(
      TimePoint(
        time24: time24,
        label12: formatTime12(time24),
        minutes: cur,
      ),
    );
    cur += stepMinutes;
  }

  return points;
}

/// Client-side conflict check for immediate responsiveness before/alongside API call
class ClientOverlapResult {
  final bool hasConflict;
  final AppointmentModel? conflictingAppt;

  const ClientOverlapResult({required this.hasConflict, this.conflictingAppt});
}

ClientOverlapResult checkClientOverlap(
  List<AppointmentModel> existingAppts,
  String newStart24,
  String newEnd24, {
  int? excludeId,
}) {
  final newStart = timeToMinutes(newStart24);
  final newEnd = timeToMinutes(newEnd24);

  final blocking = existingAppts.where((a) {
    if (excludeId != null && a.id == excludeId) return false;
    final norm = a.status.toLowerCase();
    return norm == 'booked' || norm == 'in_service' || norm == 'completed';
  }).toList();

  for (final a in blocking) {
    final aStart = timeToMinutes(a.startTime);
    final aEnd = timeToMinutes(a.endTime);
    if (newStart < aEnd && aStart < newEnd) {
      return ClientOverlapResult(hasConflict: true, conflictingAppt: a);
    }
  }

  return const ClientOverlapResult(hasConflict: false);
}

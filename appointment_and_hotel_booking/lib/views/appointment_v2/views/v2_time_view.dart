import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_storage.dart';
import '../../../models/appointment_model.dart';
import '../../../models/staff_model.dart';
import '../../../utils/appointment_v2_utils.dart';
import '../components/v2_appointment_expanded_panel.dart';

/// Timeline / Time View layout matching React .v2-timeline-board
class V2TimeView extends StatefulWidget {
  final List<AppointmentModel> appointments;
  final StaffModel selectedStaff;
  final String selectedDate;
  final int? expandedApptId;
  final ValueChanged<int> onToggleExpand;
  final ValueChanged<AppointmentModel> onStartService;
  final ValueChanged<AppointmentModel> onContinueService;
  final ValueChanged<AppointmentModel> onOpenDetails;
  final ValueChanged<BusinessSlot?> onOpenAddModal;
  final String? openTime;
  final String? closeTime;
  final int? intervalMinutes;

  const V2TimeView({
    super.key,
    required this.appointments,
    required this.selectedStaff,
    required this.selectedDate,
    required this.expandedApptId,
    required this.onToggleExpand,
    required this.onStartService,
    required this.onContinueService,
    required this.onOpenDetails,
    required this.onOpenAddModal,
    this.openTime,
    this.closeTime,
    this.intervalMinutes,
  });

  @override
  State<V2TimeView> createState() => _V2TimeViewState();
}

class _V2TimeViewState extends State<V2TimeView> {
  Timer? _ticker;
  late int _nowMinutes;
  late List<BusinessSlot> _businessSlots;
  String _effectiveOpen = '08:00';
  String _effectiveClose = '20:00';
  int _effectiveInterval = 30;

  @override
  void initState() {
    super.initState();
    _updateNowMinutes();
    _effectiveOpen = widget.openTime ?? '08:00';
    _effectiveClose = widget.closeTime ?? '20:00';
    _effectiveInterval = widget.intervalMinutes ?? 30;
    _businessSlots = generateBusinessSlots(
      openTime: _effectiveOpen,
      closeTime: _effectiveClose,
      intervalMinutes: _effectiveInterval,
    );
    _loadConfigAndInitSlots();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _updateNowMinutes();
        });
      }
    });
  }

  Future<void> _loadConfigAndInitSlots() async {
    final storedOpen = widget.openTime ?? await AuthStorage.getOpenTime();
    final storedClose = widget.closeTime ?? await AuthStorage.getCloseTime();
    final storedInterval = widget.intervalMinutes ?? await AuthStorage.getSlotDuration();

    if (!mounted) return;
    if (storedOpen != _effectiveOpen ||
        storedClose != _effectiveClose ||
        storedInterval != _effectiveInterval) {
      setState(() {
        _effectiveOpen = storedOpen;
        _effectiveClose = storedClose;
        _effectiveInterval = storedInterval > 0 ? storedInterval : 30;
        _businessSlots = generateBusinessSlots(
          openTime: _effectiveOpen,
          closeTime: _effectiveClose,
          intervalMinutes: _effectiveInterval,
        );
      });
    }
  }

  @override
  void didUpdateWidget(V2TimeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openTime != oldWidget.openTime ||
        widget.closeTime != oldWidget.closeTime ||
        widget.intervalMinutes != oldWidget.intervalMinutes) {
      _effectiveOpen = widget.openTime ?? _effectiveOpen;
      _effectiveClose = widget.closeTime ?? _effectiveClose;
      _effectiveInterval = widget.intervalMinutes ?? _effectiveInterval;
      setState(() {
        _businessSlots = generateBusinessSlots(
          openTime: _effectiveOpen,
          closeTime: _effectiveClose,
          intervalMinutes: _effectiveInterval,
        );
      });
    }
  }

  void _updateNowMinutes() {
    final now = DateTime.now();
    _nowMinutes = now.hour * 60 + now.minute;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<_TimelineRowItem> _buildTimelineRows() {
    final rows = <_TimelineRowItem>[];
    final renderedApptIds = <int>{};
    int coveredUntilM = 0;

    for (final slot in _businessSlots) {
      // Find matching unrendered appointment for this slot
      final matchingAppts = widget.appointments.where((a) {
        if (renderedApptIds.contains(a.id)) return false;
        final aStart = timeToMinutes(a.startTime);
        final aEnd = timeToMinutes(a.endTime);
        return slot.startM < aEnd && slot.endM > aStart;
      }).toList();

      if (matchingAppts.isNotEmpty) {
        final appt = matchingAppts.first;
        renderedApptIds.add(appt.id);
        final aStartM = timeToMinutes(appt.startTime.isNotEmpty ? appt.startTime : slot.start24);
        final aEndM = timeToMinutes(appt.endTime.isNotEmpty ? appt.endTime : slot.end24);
        coveredUntilM = coveredUntilM > aEndM ? coveredUntilM : aEndM;

        rows.add(_TimelineRowItem(
          slot: slot,
          primaryAppt: appt,
          startM: aStartM,
          endM: aEndM,
        ));
      } else if (slot.startM < coveredUntilM) {
        // Intermediate slot covered by already-rendered multi-slot appointment (e.g. 8:30 or 9:00 for 8:00-9:30)
        continue;
      } else {
        // Free available slot
        rows.add(_TimelineRowItem(
          slot: slot,
          primaryAppt: null,
          startM: slot.startM,
          endM: slot.endM,
        ));
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildTimelineRows();
    final isToday = widget.selectedDate == getTodayDateStr();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 6, bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: rows.map((rowItem) {
            final slot = rowItem.slot;
            final primaryAppt = rowItem.primaryAppt;
            final isExpanded = primaryAppt != null && widget.expandedApptId == primaryAppt.id;

            final isCurrentSlot = isToday && _nowMinutes >= rowItem.startM && _nowMinutes < rowItem.endM;
            final slotFraction = isCurrentSlot && (rowItem.endM - rowItem.startM) > 0
                ? (_nowMinutes - rowItem.startM) / (rowItem.endM - rowItem.startM)
                : 0.0;

            final displayTime = primaryAppt != null && primaryAppt.startTime.isNotEmpty
                ? primaryAppt.startTime
                : slot.start24;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Row Container
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  constraints: const BoxConstraints(minHeight: 70),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Time Column (100px fixed)
                        Container(
                          width: 100,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            formatTime12Leading(displayTime),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),

                        // Right: Content Area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: primaryAppt != null
                                ? _buildBookedCard(primaryAppt, slot, isExpanded)
                                : _buildEmptySlot(slot),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Red Time Indicator Line & Circular Pin Dot
                if (isCurrentSlot)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final topPos = constraints.maxHeight * slotFraction;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Red Line across the entire row
                            Positioned(
                              left: 0,
                              right: 0,
                              top: topPos - 1,
                              child: Container(
                                height: 2,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            // Red Circular Dot at the 100px time-column boundary
                            Positioned(
                              left: 94, // 100 - 6px radius
                              top: topPos - 6,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x40000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBookedCard(AppointmentModel appt, BusinessSlot slot, bool isExpanded) {
    Color cardBg = const Color(0xFFEFF6FF);
    Color cardBorder = const Color(0xFFDBEAFE);
    Color barColor = const Color(0xFF2563EB);
    Color badgeBg = const Color(0xFF2563EB);
    String badgeText = 'BOOKED';

    if (appt.isInService) {
      cardBg = const Color(0xFFFFFBEB);
      cardBorder = const Color(0xFFFEF3C7);
      barColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFD97706);
      badgeText = 'IN SERVICE';
    } else if (appt.isCompleted) {
      cardBg = const Color(0xFFECFDF5);
      cardBorder = const Color(0xFFD1FAE5);
      barColor = const Color(0xFF059669);
      badgeBg = const Color(0xFF059669);
      badgeText = 'COMPLETED';
    } else if (appt.isNoShow) {
      cardBg = const Color(0xFFFEF2F2);
      cardBorder = const Color(0xFFFEE2E2);
      barColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFDC2626);
      badgeText = 'NO SHOW';
    } else if (appt.isCancelled) {
      cardBg = const Color(0xFFF9FAFB);
      cardBorder = const Color(0xFFF3F4F6);
      barColor = const Color(0xFF6B7280);
      badgeBg = const Color(0xFF6B7280);
      badgeText = 'CANCELLED';
    }

    return InkWell(
      onTap: () => widget.onToggleExpand(appt.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A2563EB),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: barColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF334155)),
                    const SizedBox(width: 5),
                    Text(
                      formatSlotRangeLeading(
                        appt.startTime.isNotEmpty ? appt.startTime : slot.start24,
                        appt.endTime.isNotEmpty ? appt.endTime : slot.end24,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Customer Name
            Text(
              appt.customerName.isNotEmpty ? appt.customerName : 'Walk-in Guest',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),

            // Accordion expansion panel
            if (isExpanded)
              V2AppointmentExpandedPanel(
                appointment: appt,
                selectedStaff: widget.selectedStaff,
                selectedDate: widget.selectedDate,
                onCollapse: () => widget.onToggleExpand(appt.id),
                onStartService: widget.onStartService,
                onContinueService: widget.onContinueService,
                onOpenDetails: widget.onOpenDetails,
              ),
          ],
        ),
      ),
    ],
  ),
),
);
}

  Widget _buildEmptySlot(BusinessSlot slot) {
    return InkWell(
      onTap: () => widget.onOpenAddModal(slot),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 52,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              'Book Slot',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRowItem {
  final BusinessSlot slot;
  final AppointmentModel? primaryAppt;
  final int startM;
  final int endM;

  _TimelineRowItem({
    required this.slot,
    this.primaryAppt,
    required this.startM,
    required this.endM,
  });
}

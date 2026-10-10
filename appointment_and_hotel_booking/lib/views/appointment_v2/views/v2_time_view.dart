import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  });

  @override
  State<V2TimeView> createState() => _V2TimeViewState();
}

class _V2TimeViewState extends State<V2TimeView> {
  Timer? _ticker;
  late int _nowMinutes;
  late List<BusinessSlot> _businessSlots;

  @override
  void initState() {
    super.initState();
    _updateNowMinutes();
    _businessSlots = generateBusinessSlots(
      openTime: '08:00',
      closeTime: '22:00',
      intervalMinutes: 30,
    );
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _updateNowMinutes();
        });
      }
    });
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

  Map<String, List<AppointmentModel>> _buildSlotAppointmentMap() {
    final map = <String, List<AppointmentModel>>{};
    for (final slot in _businessSlots) {
      final matches = widget.appointments.where((a) {
        final aStart = timeToMinutes(a.startTime);
        final aEnd = timeToMinutes(a.endTime);
        // Slot overlaps appointment if slot starts before appt ends and slot ends after appt starts
        return slot.startM < aEnd && slot.endM > aStart;
      }).toList();
      map[slot.start24] = matches;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final slotMap = _buildSlotAppointmentMap();
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
          children: _businessSlots.map((slot) {
            final appts = slotMap[slot.start24] ?? [];
            final isBooked = appts.isNotEmpty;
            final primaryAppt = isBooked ? appts.first : null;
            final isExpanded = primaryAppt != null && widget.expandedApptId == primaryAppt.id;

            final isCurrentSlot = isToday && _nowMinutes >= slot.startM && _nowMinutes < slot.endM;
            final slotFraction = isCurrentSlot
                ? (_nowMinutes - slot.startM) / (slot.endM - slot.startM)
                : 0.0;

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
                            formatTime12Leading(slot.start24),
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
                            child: isBooked && primaryAppt != null
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Color Bar (5px)
              Container(width: 5, color: barColor),

              // Main Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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

                      const SizedBox(height: 3),

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
              ),
            ],
          ),
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

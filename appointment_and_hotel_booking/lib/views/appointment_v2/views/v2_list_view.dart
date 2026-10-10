import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../models/staff_model.dart';
import '../../../utils/appointment_v2_utils.dart';
import '../components/v2_appointment_expanded_panel.dart';
import '../components/v2_empty_schedule_card.dart';

/// List View layout matching React .v2-list-slot-card & accordion mechanics
class V2ListView extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final StaffModel selectedStaff;
  final String selectedDate;
  final int? expandedApptId;
  final ValueChanged<int> onToggleExpand;
  final ValueChanged<AppointmentModel> onStartService;
  final ValueChanged<AppointmentModel> onContinueService;
  final ValueChanged<AppointmentModel> onOpenDetails;
  final VoidCallback onBookAppointment;
  final VoidCallback onGoToToday;

  const V2ListView({
    super.key,
    required this.appointments,
    required this.selectedStaff,
    required this.selectedDate,
    required this.expandedApptId,
    required this.onToggleExpand,
    required this.onStartService,
    required this.onContinueService,
    required this.onOpenDetails,
    required this.onBookAppointment,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return V2EmptyScheduleCard(
        selectedStaff: selectedStaff,
        selectedDate: selectedDate,
        onBookAppointment: onBookAppointment,
        onGoToToday: onGoToToday,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(right: 6, bottom: 24),
      itemCount: appointments.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final appt = appointments[index];
        final isExpanded = (expandedApptId == appt.id);
        final statusMeta = getStatusMeta(appt.status);

        Color cardBorder = const Color(0xFFE2E8F0);
        if (appt.isBooked) cardBorder = const Color(0xFFBFDBFE);
        if (appt.isInService) cardBorder = const Color(0xFFFDE68A);
        if (appt.isCompleted) cardBorder = const Color(0xFFBBF7D0);
        if (appt.isNoShow) cardBorder = const Color(0xFFFCA5A5);
        if (appt.isCancelled) cardBorder = const Color(0xFFD1D5DB);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0A0F172A),
                blurRadius: isExpanded ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Interactive Row
              InkWell(
                onTap: () => onToggleExpand(appt.id),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      // 1. Left: Time Pill & Status Badge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 13, color: statusMeta.color),
                                const SizedBox(width: 6),
                                Text(
                                  formatSlotRangeLeading(appt.startTime, appt.endTime),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusMeta.badgeBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusMeta.border.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusMeta.label,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: statusMeta.badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 14),

                      // 2. Center: Customer Name
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appt.customerName.isNotEmpty ? appt.customerName : 'Walk-in Guest',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 14),

                      // 3. Right: Total Amount & Chevron
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${appt.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isExpanded ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isExpanded ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: isExpanded ? 0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isExpanded ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable Panel
              if (isExpanded)
                V2AppointmentExpandedPanel(
                  appointment: appt,
                  selectedStaff: selectedStaff,
                  selectedDate: selectedDate,
                  onCollapse: () => onToggleExpand(appt.id),
                  onStartService: onStartService,
                  onContinueService: onContinueService,
                  onOpenDetails: onOpenDetails,
                ),
            ],
          ),
        );
      },
    );
  }
}

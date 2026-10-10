import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../models/staff_model.dart';
import '../../../utils/appointment_v2_utils.dart';
import '../components/v2_empty_schedule_card.dart';

/// Grid View layout matching React responsive 4-column cards (.v2-grid-card)
class V2GridView extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final StaffModel selectedStaff;
  final String selectedDate;
  final ValueChanged<AppointmentModel> onOpenDetails;
  final VoidCallback onBookAppointment;
  final VoidCallback onGoToToday;

  const V2GridView({
    super.key,
    required this.appointments,
    required this.selectedStaff,
    required this.selectedDate,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 270).floor().clamp(1, 4);

        return GridView.builder(
          padding: const EdgeInsets.only(right: 6, bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.35,
          ),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appt = appointments[index];
            final statusMeta = getStatusMeta(appt.status);
            final svcNames = appt.servicesSummary;
            final customerName = appt.customerName.isNotEmpty
                ? appt.customerName
                : 'Walk-in Guest';

            Color borderColor = const Color(0xFFE2E8F0);
            Color headerBg = const Color(0xFFFAFBFC);
            Color headerBorder = const Color(0xFFF1F5F9);

            if (appt.isBooked) {
              borderColor = const Color(0xFFDBEAFE);
              headerBg = const Color(0xFFEFF6FF);
              headerBorder = const Color(0xFFBFDBFE);
            } else if (appt.isInService) {
              borderColor = const Color(0xFFFDE68A);
              headerBg = const Color(0xFFFFFBEB);
              headerBorder = const Color(0xFFFEF3C7);
            } else if (appt.isCompleted) {
              borderColor = const Color(0xFFBBF7D0);
              headerBg = const Color(0xFFF0FDF4);
              headerBorder = const Color(0xFFDCFCE7);
            } else if (appt.isNoShow) {
              borderColor = const Color(0xFFFCA5A5);
              headerBg = const Color(0xFFFEF2F2);
              headerBorder = const Color(0xFFFEE2E2);
            } else if (appt.isCancelled) {
              borderColor = const Color(0xFFD1D5DB);
              headerBg = const Color(0xFFF9FAFB);
              headerBorder = const Color(0xFFF3F4F6);
            }

            return InkWell(
              onTap: () => onOpenDetails(appt),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header (Time & Status Badge)
                    Container(
                      decoration: BoxDecoration(
                        color: headerBg,
                        border: Border(bottom: BorderSide(color: headerBorder)),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 13, color: statusMeta.color),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    formatSlotRangeLeading(appt.startTime, appt.endTime),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusMeta.badgeBg,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: statusMeta.border.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusMeta.label,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusMeta.badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Body (Customer, Service, Phone)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.work_outline_rounded, size: 12, color: Color(0xFF059669)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    svcNames,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (appt.customerPhone.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      appt.customerPhone,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Footer (Amount & View Details)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFBFC),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${appt.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

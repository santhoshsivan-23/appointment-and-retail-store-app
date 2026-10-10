import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../models/staff_model.dart';
import '../../../utils/appointment_v2_utils.dart';

/// Accordion detail panel matching React .v2-details-panel
class V2AppointmentExpandedPanel extends StatelessWidget {
  final AppointmentModel appointment;
  final StaffModel selectedStaff;
  final String selectedDate;
  final VoidCallback? onCollapse;
  final ValueChanged<AppointmentModel> onStartService;
  final ValueChanged<AppointmentModel> onContinueService;
  final ValueChanged<AppointmentModel> onOpenDetails;

  const V2AppointmentExpandedPanel({
    super.key,
    required this.appointment,
    required this.selectedStaff,
    required this.selectedDate,
    this.onCollapse,
    required this.onStartService,
    required this.onContinueService,
    required this.onOpenDetails,
  });

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'G';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusMeta = getStatusMeta(appointment.status);
    final svcNames = appointment.servicesSummary;
    final customerName = appointment.customerName.isNotEmpty
        ? appointment.customerName
        : 'Walk-in Guest';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Meta Bar (Customer Group & Total Amount)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Customer Avatar & Name & Status
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getInitials(appointment.customerName),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  customerName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusMeta.badgeBg,
                                  borderRadius: BorderRadius.circular(999),
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
                          if (appointment.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  appointment.customerPhone,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Total Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL AMOUNT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${appointment.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // 2. Details Grid (Service, Date, Time Slot, Staff, Phone)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCell(
                    icon: Icons.work_outline_rounded,
                    iconColor: const Color(0xFF059669),
                    label: 'SERVICE',
                    value: svcNames,
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 8) / 2,
                  ),
                  _buildCell(
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF2563EB),
                    label: 'DATE',
                    value: formatDatePretty(
                      appointment.appointmentDate.isNotEmpty
                          ? appointment.appointmentDate
                          : selectedDate,
                    ),
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 8) / 2,
                  ),
                  _buildCell(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFFD97706),
                    label: 'TIME SLOT',
                    value: formatTimeSlotLabel(appointment.startTime, appointment.endTime),
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 3,
                  ),
                  _buildCell(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF9333EA),
                    label: 'STAFF',
                    value: appointment.staffName.isNotEmpty
                        ? appointment.staffName
                        : selectedStaff.name,
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 3,
                  ),
                  _buildCell(
                    icon: Icons.phone_outlined,
                    iconColor: const Color(0xFF0D9488),
                    label: 'PHONE',
                    value: appointment.customerPhone.isNotEmpty
                        ? appointment.customerPhone
                        : 'None',
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 3,
                  ),
                ],
              );
            },
          ),

          // 3. Notes Box (if available)
          if (appointment.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appointment.notes,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 4. Actions Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (appointment.isBooked)
                    ElevatedButton.icon(
                      onPressed: () => onStartService(appointment),
                      icon: const Icon(Icons.play_arrow_rounded, size: 14),
                      label: Text(
                        'Start Service',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  if (appointment.isInService)
                    ElevatedButton.icon(
                      onPressed: () => onContinueService(appointment),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text(
                        'Continue Service',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => onOpenDetails(appointment),
                    icon: const Icon(Icons.arrow_outward_rounded, size: 13, color: Color(0xFF475569)),
                    label: Text(
                      'Full Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              if (onCollapse != null)
                InkWell(
                  onTap: onCollapse,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard_arrow_up_rounded, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Text(
                          'Collapse',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

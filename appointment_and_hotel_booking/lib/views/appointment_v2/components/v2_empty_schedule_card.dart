import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/staff_model.dart';
import '../../../utils/appointment_v2_utils.dart';

/// Modern empty state card matching React .v2-empty-schedule-card
class V2EmptyScheduleCard extends StatelessWidget {
  final StaffModel selectedStaff;
  final String selectedDate;
  final VoidCallback onBookAppointment;
  final VoidCallback onGoToToday;

  const V2EmptyScheduleCard({
    super.key,
    required this.selectedStaff,
    required this.selectedDate,
    required this.onBookAppointment,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate == getTodayDateStr();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Availability Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4022C55E),
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '100% FREE SCHEDULE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF166534),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Modern Gradient Icon Box
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x292563EB),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 36,
                  color: Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Heading
              Text(
                'No Appointments Booked',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 8),

              // 4. Description
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'There are currently no appointments booked for '),
                    TextSpan(
                      text: selectedStaff.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const TextSpan(text: ' on '),
                    TextSpan(
                      text: formatDatePretty(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 5. Context Meta Box
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _buildMetaChip(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Specialist: ${selectedStaff.name}',
                    ),
                    Text('•', style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 14)),
                    _buildMetaChip(
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF2563EB),
                      label: formatDatePretty(selectedDate),
                    ),
                    Text('•', style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 14)),
                    _buildMetaChip(
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF16A34A),
                      label: 'All Slots Available',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // 6. Action Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onBookAppointment,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Book An Appointment',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (!isToday)
                    OutlinedButton.icon(
                      onPressed: onGoToToday,
                      icon: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                      label: Text(
                        'Go to Today',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // 7. Subtle Tip
              Text(
                '💡 Switch to Time Layout to view all available 30-minute time slots',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

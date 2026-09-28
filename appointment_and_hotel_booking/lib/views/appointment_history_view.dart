import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppointmentHistoryView extends StatelessWidget {
  const AppointmentHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final historyLogs = [
      {
        'id': '#APT-2025-089',
        'date': 'Yesterday, 04:00 PM',
        'customer': 'Claire Beauchamp',
        'staff': 'Dr. Shaun Ong',
        'is_staff_active': true,
        'service': 'Comprehensive Health Consult + Vaccines',
        'charge': '\$115.00',
        'status': 'Completed',
      },
      {
        'id': '#APT-2025-088',
        'date': 'Yesterday, 02:15 PM',
        'customer': 'Liam Walker (Walk-in)',
        'staff': 'Marcus Vance (Archived Staff)',
        'is_staff_active': false,
        'service': 'Retail Wellness Consultation',
        'charge': '\$45.00',
        'status': 'Completed',
      },
      {
        'id': '#APT-2025-087',
        'date': '2 days ago, 11:00 AM',
        'customer': 'David Kim',
        'staff': 'Elena Rostova',
        'is_staff_active': true,
        'service': 'Full Spa Grooming & Nail Clip',
        'charge': '\$85.00',
        'status': 'Completed',
      },
      {
        'id': '#APT-2025-086',
        'date': '3 days ago, 09:30 AM',
        'customer': 'Emma Stone',
        'staff': 'Marcus Vance (Archived Staff)',
        'is_staff_active': false,
        'service': 'Express Check-In & Medication',
        'charge': '\$50.00',
        'status': 'Completed',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appointment History & Logs', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Historical records are strictly preserved even if staff members have been deleted/archived.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: AppTheme.tertiary),
                      const SizedBox(width: 6),
                      Text('Audit-Safe Historical Retention', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.tertiary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.separated(
                itemCount: historyLogs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final log = historyLogs[idx];
                  final isStaffActive = log['is_staff_active'] as bool;
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            log['id'] as String,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log['customer'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text('${log['service']} • ${log['date']}', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        // Staff attribution tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isStaffActive ? AppTheme.primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isStaffActive ? Icons.person : Icons.person_off, size: 14, color: isStaffActive ? AppTheme.primary : Colors.grey[700]),
                              const SizedBox(width: 6),
                              Text(
                                log['staff'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isStaffActive ? AppTheme.primary : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          log['charge'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

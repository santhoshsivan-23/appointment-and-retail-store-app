import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppointmentConfigView extends StatefulWidget {
  const AppointmentConfigView({super.key});

  @override
  State<AppointmentConfigView> createState() => _AppointmentConfigViewState();
}

class _AppointmentConfigViewState extends State<AppointmentConfigView> {
  int _slotDuration = 30; // minutes
  int _bufferTime = 10; // minutes
  bool _allowWalkInQueue = true;
  bool _requireDoctorNotes = true;
  String _openTime = '08:30 AM';
  String _closeTime = '07:30 PM';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appointment Configuration & Rules', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Configure operational booking intervals, buffer times, and clinic schedule policies.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Booking Slot Interval', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Controls duration grid for clinician slots and salon schedules:', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [15, 30, 45, 60].map((mins) {
                        final isSel = _slotDuration == mins;
                        return ChoiceChip(
                          selected: isSel,
                          label: Text('$mins Minutes'),
                          selectedColor: AppTheme.primaryContainer.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: isSel ? AppTheme.primary : AppTheme.onSurface,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _slotDuration = mins),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32),

                    Text('2. Buffer Time Between Sessions', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Automatic sanitation and preparation window added after each appointment:', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [0, 5, 10, 15, 20].map((mins) {
                        final isSel = _bufferTime == mins;
                        return ChoiceChip(
                          selected: isSel,
                          label: Text('$mins Min Buffer'),
                          selectedColor: AppTheme.secondaryContainer.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: isSel ? AppTheme.secondary : AppTheme.onSurface,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _bufferTime = mins),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32),

                    Text('3. Operating Business Hours', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _openTime,
                            decoration: const InputDecoration(labelText: 'Opening Time', prefixIcon: Icon(Icons.wb_sunny_outlined)),
                            onChanged: (v) => _openTime = v,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _closeTime,
                            decoration: const InputDecoration(labelText: 'Closing Time', prefixIcon: Icon(Icons.nights_stay_outlined)),
                            onChanged: (v) => _closeTime = v,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    Text('4. Terminal Policies', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text('Allow Instant Walk-in Queue Insertion', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Allows front desk to slot walk-in patients immediately between scheduled appointments.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                      value: _allowWalkInQueue,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _allowWalkInQueue = v),
                    ),
                    SwitchListTile(
                      title: Text('Enforce Post-Consultation Notes', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Requires clinician to record observation notes before marking appointment completed.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                      value: _requireDoctorNotes,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _requireDoctorNotes = v),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save, size: 18),
                        label: Text('Save Configuration', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appointment configuration rules saved successfully.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';

class AppointmentConfigView extends StatefulWidget {
  const AppointmentConfigView({super.key});

  @override
  State<AppointmentConfigView> createState() => _AppointmentConfigViewState();
}

class _AppointmentConfigViewState extends State<AppointmentConfigView> {
  int _slotDuration = 30; // minutes
  int _bufferTime = 10; // minutes
  String _timeFormat = '12'; // '12' or '24'
  bool _allowWalkInQueue = true;
  bool _requireDoctorNotes = true;
  bool _allowDeleteService = false;
  bool _isSyncing = false;
  bool _isSaving = false;
  late TextEditingController _openTimeCtrl;
  late TextEditingController _closeTimeCtrl;

  @override
  void initState() {
    super.initState();
    _openTimeCtrl = TextEditingController(text: '08:00');
    _closeTimeCtrl = TextEditingController(text: '20:00');
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final format = await AuthStorage.getTimeFormat();
    final open = await AuthStorage.getOpenTime();
    final close = await AuthStorage.getCloseTime();
    final slot = await AuthStorage.getSlotDuration();
    final buffer = await AuthStorage.getBufferTime();
    final allowWalkIn = await AuthStorage.getAllowWalkInQueue();
    final requireNotes = await AuthStorage.getRequireDoctorNotes();
    final allowDelete = await AuthStorage.getAllowDeleteService();
    if (!mounted) return;
    setState(() {
      _timeFormat = format;
      _openTimeCtrl.text = open;
      _closeTimeCtrl.text = close;
      _slotDuration = slot;
      _bufferTime = buffer;
      _allowWalkInQueue = allowWalkIn;
      _requireDoctorNotes = requireNotes;
      _allowDeleteService = allowDelete;
    });
  }

  // 1. Sync Settings: Fetch latest settings from database and store in SharedPreferences
  Future<void> _syncSettings() async {
    setState(() => _isSyncing = true);
    try {
      final res = await ApiService.getSettings();
      if (!mounted) return;

      if (res.success && res.data != null) {
        final dataMap = Map<String, dynamic>.from(res.data);
        await AuthStorage.saveSettingsFromMap(dataMap);
        await _loadSavedConfig();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Settings synced successfully from cloud database!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.message.isNotEmpty ? res.message : 'Failed to sync settings from server.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Sync failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // 2. Save Configuration: Update local SharedPreferences and call Update Settings API
  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    final cleanOpen = _openTimeCtrl.text.trim().isEmpty ? '08:00' : _openTimeCtrl.text.trim();
    final cleanClose = _closeTimeCtrl.text.trim().isEmpty ? '20:00' : _closeTimeCtrl.text.trim();

    // Save locally
    await AuthStorage.setTimeFormat(_timeFormat);
    await AuthStorage.setClockDisplay(_timeFormat == '24' ? '24h' : '12h');
    await AuthStorage.setOpenTime(cleanOpen);
    await AuthStorage.setCloseTime(cleanClose);
    await AuthStorage.setSlotDuration(_slotDuration);
    await AuthStorage.setBufferTime(_bufferTime);
    await AuthStorage.setAllowWalkInQueue(_allowWalkInQueue);
    await AuthStorage.setRequireDoctorNotes(_requireDoctorNotes);
    await AuthStorage.setAllowDeleteService(_allowDeleteService);

    // Call Update Settings API to save changes to the database
    try {
      final res = await ApiService.updateSettings({
        'time_format': _timeFormat,
        'clock_display': _timeFormat == '24' ? '24h' : '12h',
        'booking_slot_interval': _slotDuration,
        'buffer_time_between_sessions': _bufferTime,
        'open_time': cleanOpen,
        'close_time': cleanClose,
        'allow_walk_in_queue': _allowWalkInQueue,
        'require_doctor_notes': _requireDoctorNotes,
        'allow_delete_service': _allowDeleteService,
      });

      if (!mounted) return;
      final formatDesc = _timeFormat == '12' ? '12-Hour AM/PM' : '24-Hour';

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appointment configuration saved and synced to database! (Format: $formatDesc)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF59E0B),
            content: Text('Saved locally, but server update failed: ${res.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFF59E0B),
          content: Text('Saved locally, but server update failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointment Configuration & Rules',
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure operational booking intervals, time format (12h/24h), buffer times, and clinic schedule policies.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      elevation: 0,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      _isSyncing ? 'Syncing...' : 'Sync Settings',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: _isSyncing ? null : _syncSettings,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
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
                    // 1. Time Format Configuration (Redesigned as clean card with no overflow)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '1. Time Format & Clock Display',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Controls whether appointment times use 12-hour (with AM/PM dropdown) or 24-hour notation:',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 500;
                              final option12 = _buildTimeFormatOptionCard(
                                value: '12',
                                icon: Icons.access_time_filled_rounded,
                                title: '12-Hour Format',
                                subtitle: 'AM / PM Dropdown Selector',
                                isSelected: _timeFormat == '12',
                                onSelect: () => setState(() => _timeFormat = '12'),
                              );
                              final option24 = _buildTimeFormatOptionCard(
                                value: '24',
                                icon: Icons.timer_rounded,
                                title: '24-Hour Format',
                                subtitle: '00:00 - 23:59 Standard Time',
                                isSelected: _timeFormat == '24',
                                onSelect: () => setState(() => _timeFormat = '24'),
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    option12,
                                    const SizedBox(height: 10),
                                    option24,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: option12),
                                  const SizedBox(width: 14),
                                  Expanded(child: option24),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),

                    // 2. Booking Slot Interval
                    Text('2. Booking Slot Interval', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
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

                    // 3. Buffer Time Between Sessions
                    Text('3. Buffer Time Between Sessions', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
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

                    // 4. Operating Business Hours
                    Text('4. Operating Business Hours', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Only appointment bookings within these operating hours will be validated and accepted:', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _openTimeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Opening Time (e.g. 08:00)',
                              prefixIcon: Icon(Icons.wb_sunny_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _closeTimeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Closing Time (e.g. 20:00)',
                              prefixIcon: Icon(Icons.nights_stay_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // 5. Terminal Policies
                    Text('5. Terminal Policies', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
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
                    const Divider(height: 32),

                    // 6. Delete Service Configuration
                    Text('6. Delete Service Configuration', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Controls whether appointments that are currently In Service can be deleted directly:', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text('Enable Delete Service for In-Service Appointments', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('When enabled, a Delete option is displayed with a confirmation dialog for appointments currently In Service.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                      value: _allowDeleteService,
                      activeThumbColor: AppTheme.error,
                      onChanged: (v) => setState(() => _allowDeleteService = v),
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
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(
                          _isSaving ? 'Saving & Syncing...' : 'Save Configuration',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSaving ? null : _saveConfig,
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

  Widget _buildTimeFormatOptionCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.20) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        color: isSelected ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

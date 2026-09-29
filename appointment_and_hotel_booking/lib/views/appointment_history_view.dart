import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/appointment_model.dart';
import '../models/staff_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AppointmentHistoryView extends StatefulWidget {
  const AppointmentHistoryView({super.key});

  @override
  State<AppointmentHistoryView> createState() => _AppointmentHistoryViewState();
}

class _AppointmentHistoryViewState extends State<AppointmentHistoryView> {
  List<AppointmentModel> _completedAppointments = [];
  List<StaffModel> _staffList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAppointments(),
        ApiService.getStaff(),
      ]);

      if (!mounted) return;

      final allAppointments = results[0] as List<AppointmentModel>;
      final staff = results[1] as List<StaffModel>;

      // STRICTLY DISPLAY ONLY PERFORMED / COMPLETED APPOINTMENTS
      final completed = allAppointments.where((a) {
        final s = a.status.toLowerCase().trim();
        return s == 'completed' || s == 'performed';
      }).toList();

      // Sort most recent first
      completed.sort((a, b) {
        final cmp = b.appointmentDate.compareTo(a.appointmentDate);
        if (cmp != 0) return cmp;
        return b.startTime.compareTo(a.startTime);
      });

      setState(() {
        _completedAppointments = completed;
        _staffList = staff;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading appointment history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<AppointmentModel> get _filteredHistory {
    if (_searchQuery.isEmpty) return _completedAppointments;
    final q = _searchQuery.toLowerCase().trim();
    return _completedAppointments.where((a) {
      final matchesCustomer = a.customerName.toLowerCase().contains(q);
      final matchesPhone = a.customerPhone.toLowerCase().contains(q);
      final matchesStaff = a.staffName.toLowerCase().contains(q);
      final matchesDate = a.appointmentDate.contains(q);
      final matchesId = '#apt-${a.id}'.contains(q);
      final matchesService = a.services.any((s) =>
          (s['name'] ?? '').toString().toLowerCase().contains(q));
      return matchesCustomer ||
          matchesPhone ||
          matchesStaff ||
          matchesDate ||
          matchesId ||
          matchesService;
    }).toList();
  }

  double get _totalCompletedRevenue =>
      _completedAppointments.fold(0.0, (acc, a) => acc + a.totalAmount);

  int get _todayCompletedCount {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _completedAppointments
        .where((a) => a.appointmentDate == todayStr)
        .length;
  }

  bool _isStaffActive(int staffId) {
    final s = _staffList.where((st) => st.id == staffId).toList();
    if (s.isEmpty) return false;
    return s.first.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredHistory;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Refresh Button
            _buildHeader(),
            const SizedBox(height: 20),

            // 2. Metrics summary
            _buildMetricsRow(),
            const SizedBox(height: 20),

            // 3. Search and audit banner
            _buildSearchBar(),
            const SizedBox(height: 16),

            // 4. Performed / Completed List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE11D48),
                      ),
                    )
                  : displayList.isEmpty
                      ? _buildEmptyState()
                      : _buildCompletedList(displayList),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Appointment History & Completed Logs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_completedAppointments.length} Performed',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Audit log exclusively displaying appointments that have been successfully performed & completed.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // Action: Refresh Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceContainerLowest,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            side: BorderSide(
                color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE11D48),
                  ),
                )
              : const Icon(Icons.refresh, size: 18, color: Color(0xFFE11D48)),
          label: Text(
            'Refresh',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _isLoading ? null : _loadHistory,
        ),
      ],
    );
  }

  // =========================================================================
  // METRICS ROW
  // =========================================================================
  Widget _buildMetricsRow() {
    return Row(
      children: [
        _buildMetricCard(
          title: 'Total Performed',
          value: '${_completedAppointments.length} Appointments',
          sub: '100% completed & fulfilled',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: 'Performed Today',
          value: '$_todayCompletedCount Completed',
          sub: 'Sessions served today',
          icon: Icons.today,
          color: const Color(0xFF0EA5E9),
          bgColor: const Color(0xFFF0F9FF),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: 'Service Revenue',
          value: '\$${_totalCompletedRevenue.toStringAsFixed(2)}',
          sub: 'Total earned from performed sessions',
          icon: Icons.monetization_on_outlined,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEARCH BAR
  // =========================================================================
  Widget _buildSearchBar() {
    return Row(
      children: [
        SizedBox(
          width: 320,
          height: 38,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search customer, phone, staff, service...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF166534)),
              const SizedBox(width: 6),
              Text(
                'Audit-Safe Performed Retention',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // COMPLETED APPOINTMENTS LIST
  // =========================================================================
  Widget _buildCompletedList(List<AppointmentModel> appointments) {
    return ListView.separated(
      itemCount: appointments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final a = appointments[idx];
        final isStaffActive = _isStaffActive(a.staffId);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Appointment ID Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#APT-${a.id.toString().padLeft(4, '0')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Customer & Service details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          a.customerName.isNotEmpty ? a.customerName : 'Walk-in Guest',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (a.customerPhone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            a.customerPhone,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Status Badge: COMPLETED
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 11, color: Color(0xFF166534)),
                              const SizedBox(width: 4),
                              Text(
                                'PERFORMED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Date & Time + Services
                    Text(
                      '${a.servicesSummary} • ${a.appointmentDate} (${a.startTime} - ${a.endTime})',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    if (a.notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Notes: ${a.notes}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Staff Attribution
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isStaffActive
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStaffActive ? Icons.person : Icons.person_off,
                      size: 14,
                      color: isStaffActive ? AppTheme.primary : Colors.grey[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      a.staffName.isNotEmpty ? a.staffName : 'Staff #${a.staffId}',
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

              // Total Charge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${a.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'Completed',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // EMPTY STATE
  // =========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_edu_outlined, size: 48, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No completed appointments match your search'
                : 'No performed appointments yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with a different name, date, or service.'
                : 'Appointments marked as "Completed" will automatically be recorded here.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reload History'),
            onPressed: _loadHistory,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/appointment_model.dart';
import '../models/business_model.dart';
import '../models/sale_model.dart';
import '../models/staff_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DashboardView extends StatefulWidget {
  final BusinessModel? business;
  final Function(int) onNavigate;

  const DashboardView({super.key, this.business, required this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _isLoading = true;
  bool _isRefreshing = false;

  List<AppointmentModel> _todayAppointments = [];
  List<StaffModel> _staffList = [];
  List<SaleModel> _normalSales = [];
  List<AppointmentModel> _completedAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String _getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDateLong(DateTime dt) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime12(String time24) {
    if (time24.isEmpty) return '--:--';
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int? h = int.tryParse(parts[0]);
    if (h == null) return time24;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  }

  Future<void> _loadDashboardData({bool manualRefresh = false}) async {
    if (manualRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final todayStr = _getTodayDateStr();

      final results = await Future.wait([
        ApiService.getAppointments(date: todayStr),
        ApiService.getStaff(includeDeleted: false),
        ApiService.getSales(),
        ApiService.getAppointments(status: 'completed'),
      ]);

      if (mounted) {
        final rawTodayAppts = results[0] as List<AppointmentModel>;
        // Sort today's appointments by start_time ascending
        rawTodayAppts.sort((a, b) => a.startTime.compareTo(b.startTime));

        final rawStaff = results[1] as List<StaffModel>;
        final rawSales = results[2] as List<SaleModel>;
        // Filter strictly to normal POS sales (no appointment_id)
        final posSales = rawSales
            .where((s) => s.appointmentId == null || s.appointmentId == 0)
            .toList();

        final rawCompletedAppts = results[3] as List<AppointmentModel>;

        setState(() {
          _todayAppointments = rawTodayAppts;
          _staffList = rawStaff;
          _normalSales = posSales;
          _completedAppointments = rawCompletedAppts;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // Dynamic calculated stats
  int get _inServiceCount => _todayAppointments
      .where((a) =>
          a.status.toLowerCase() == 'in_service' ||
          a.status.toLowerCase() == 'inservice')
      .length;

  int get _completedTodayCount => _todayAppointments
      .where((a) => a.status.toLowerCase() == 'completed')
      .length;

  int get _totalStaffCount =>
      _staffList.where((s) => s.isActive).length;

  double get _normalSalesTotal =>
      _normalSales.fold(0.0, (acc, s) => acc + s.totalAmount);

  double get _todayNormalSalesTotal {
    final now = DateTime.now();
    return _normalSales.where((s) {
      if (s.createdAt == null) return false;
      final dt = s.createdAt!.toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).fold(0.0, (acc, s) => acc + s.totalAmount);
  }

  double get _appointmentSalesTotal =>
      _completedAppointments.fold(0.0, (acc, a) => acc + a.totalAmount);

  double get _todayAppointmentSalesTotal {
    final todayStr = _getTodayDateStr();
    return _completedAppointments
        .where((a) => a.appointmentDate.split('T')[0] == todayStr)
        .fold(0.0, (acc, a) => acc + a.totalAmount);
  }

  String _getServicesSummary(AppointmentModel a) {
    if (a.services.isEmpty) return 'General Service';
    final names = a.services
        .map((s) => (s['name'] ?? s['product_name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'General Service';
    if (names.length == 1) return names[0];
    return '${names[0]} (+${names.length - 1} more)';
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.business?.businessName.isNotEmpty == true
        ? widget.business!.businessName
        : 'IQ Unified Terminal';
    final ownerName = widget.business?.ownerName.isNotEmpty == true
        ? widget.business!.ownerName
        : 'Store Administrator';
    final businessType = widget.business?.businessType.isNotEmpty == true
        ? widget.business!.businessType
        : 'Unified Retail & Appointments';

    final todayFormatted = _formatDateLong(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _loadDashboardData(manualRefresh: true),
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Welcome Banner with dynamic business info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Live Terminal Operations • Station #01',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            businessName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manager: $ownerName • Category: $businessType',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                      icon: const Icon(Icons.point_of_sale, size: 18),
                      label: Text(
                        'Open Register / Cart',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => widget.onNavigate(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Dynamic KPI Summary Counters (4 Cards)
              Row(
                children: [
                  _buildKpiCard(
                    title: "Today's Appointments",
                    value: _isLoading
                        ? '...'
                        : '${_todayAppointments.length} Scheduled',
                    sub: _todayAppointments.isEmpty
                        ? 'No sessions today'
                        : '$_inServiceCount in service • $_completedTodayCount done',
                    icon: Icons.calendar_today,
                    color: AppTheme.primary,
                    onTap: () => widget.onNavigate(1),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'Total Staff',
                    value: _isLoading ? '...' : '$_totalStaffCount On Duty',
                    sub: '${_staffList.length} clinicians on roster',
                    icon: Icons.people_outline,
                    color: AppTheme.tertiary,
                    onTap: () => widget.onNavigate(2),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'Normal Sales',
                    value: _isLoading
                        ? '...'
                        : '\$${_normalSalesTotal.toStringAsFixed(2)}',
                    sub:
                        '${_normalSales.length} orders • \$${_todayNormalSalesTotal.toStringAsFixed(2)} today',
                    icon: Icons.receipt_long,
                    color: AppTheme.secondary,
                    onTap: () => widget.onNavigate(5),
                  ),
                  const SizedBox(width: 16),
                  _buildKpiCard(
                    title: 'Appointment Sales',
                    value: _isLoading
                        ? '...'
                        : '\$${_appointmentSalesTotal.toStringAsFixed(2)}',
                    sub:
                        '${_completedAppointments.length} completed • \$${_todayAppointmentSalesTotal.toStringAsFixed(2)} today',
                    icon: Icons.event_available,
                    color: Colors.indigo,
                    onTap: () => widget.onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Today's Appointments List Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Today's Appointments",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _isLoading
                                    ? '...'
                                    : '${_todayAppointments.length} Scheduled',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: _isRefreshing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                              color: AppTheme.onSurfaceVariant,
                              tooltip: 'Refresh dashboard',
                              onPressed: () =>
                                  _loadDashboardData(manualRefresh: true),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(
                                    color:
                                        AppTheme.primary.withValues(alpha: 0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: Text(
                                'Open Timetable',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => widget.onNavigate(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '$todayFormatted • $_inServiceCount in service • $_completedTodayCount completed',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Appointments List / Empty State / Loading State
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                  color: AppTheme.primary),
                              const SizedBox(height: 12),
                              Text(
                                "Loading today's schedule...",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_todayAppointments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  color: AppTheme.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Appointments Scheduled For Today',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'There are no patient or client bookings for $todayFormatted.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  'Book An Appointment',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => widget.onNavigate(1),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                color: AppTheme.surfaceContainerLow,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'TIME SLOT',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'CUSTOMER',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'CLINICIAN / STAFF',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'SERVICES',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'STATUS',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'TOTAL',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 50),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),

                              // Table Rows
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _todayAppointments.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1, thickness: 1),
                                itemBuilder: (context, index) {
                                  final appt = _todayAppointments[index];
                                  return _buildAppointmentRow(appt);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 4. Quick Navigation Operations Shortcuts
              Text(
                'Terminal Operations',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.4,
                children: [
                  _buildActionTile(
                    Icons.calendar_month,
                    'Appointments',
                    'Manage daily schedule',
                    AppTheme.primary,
                    () => widget.onNavigate(1),
                  ),
                  _buildActionTile(
                    Icons.people,
                    'Staff Directory',
                    'Clinicians & groomers',
                    AppTheme.secondary,
                    () => widget.onNavigate(2),
                  ),
                  _buildActionTile(
                    Icons.history_edu,
                    'Appointment History',
                    'Completed logs & reports',
                    AppTheme.tertiary,
                    () => widget.onNavigate(3),
                  ),
                  _buildActionTile(
                    Icons.shopping_cart,
                    'POS Cart',
                    'Checkout & Tender',
                    Colors.indigo,
                    () => widget.onNavigate(4),
                  ),
                  _buildActionTile(
                    Icons.receipt_long,
                    'Sales History',
                    'Cart orders & receipts',
                    Colors.amber.shade800,
                    () => widget.onNavigate(5),
                  ),
                  _buildActionTile(
                    Icons.category,
                    'Categories',
                    'Custom domain manager',
                    Colors.deepPurple,
                    () => widget.onNavigate(6),
                  ),
                  _buildActionTile(
                    Icons.inventory_2,
                    'Products & Combos',
                    'Catalog & modifier items',
                    Colors.teal,
                    () => widget.onNavigate(7),
                  ),
                  _buildActionTile(
                    Icons.tune,
                    'Appointment Config',
                    'Hours & interval settings',
                    Colors.blueGrey,
                    () => widget.onNavigate(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentRow(AppointmentModel appt) {
    return InkWell(
      onTap: () => widget.onNavigate(1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Time Slot
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 13, color: AppTheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime12(appt.startTime)} - ${_formatTime12(appt.endTime)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Customer
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt.customerName.isNotEmpty
                        ? appt.customerName
                        : 'Walk-in Guest',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  if (appt.customerPhone.isNotEmpty)
                    Text(
                      appt.customerPhone,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            // Staff Member
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      appt.staffName.isNotEmpty
                          ? appt.staffName
                          : 'Unassigned',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Services
            Expanded(
              flex: 3,
              child: Text(
                _getServicesSummary(appt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(appt.status),
              ),
            ),

            // Total Amount
            Expanded(
              flex: 2,
              child: Text(
                '\$${appt.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
            ),

            // Action
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              color: AppTheme.primary,
              tooltip: 'View in timetable',
              onPressed: () => widget.onNavigate(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    Color border;
    String label;

    switch (status.toLowerCase()) {
      case 'in_service':
      case 'inservice':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        label = 'In Service';
        break;
      case 'completed':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        border = const Color(0xFFA7F3D0);
        label = 'Completed';
        break;
      case 'no_show':
      case 'noshow':
        bg = const Color(0xFFFFE4E6);
        text = const Color(0xFFBE123C);
        border = const Color(0xFFFECDD3);
        label = 'No Show';
        break;
      case 'cancelled':
      case 'canceled':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        border = const Color(0xFFCBD5E1);
        label = 'Cancelled';
        break;
      case 'booked':
      default:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        label = 'Booked';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

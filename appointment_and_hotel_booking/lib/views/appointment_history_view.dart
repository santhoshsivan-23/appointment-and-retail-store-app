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
  List<AppointmentModel> _allCompletedAppointments = [];
  List<StaffModel> _staffList = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';

  // Pagination: 20 records per page
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAppointments(status: 'completed'),
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
        _allCompletedAppointments = completed;
        _completedAppointments = completed;
        _staffList = staff;
        _currentPage = 1;
        _isLoading = false;
        _activeSearchQuery = '';
      });
      _searchController.clear();
    } catch (e) {
      debugPrint('Error loading appointment history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = true;
      _activeSearchQuery = query;
    });

    try {
      final results = await ApiService.getAppointments(
        search: query.isNotEmpty ? query : null,
        status: 'completed',
      );

      if (!mounted) return;

      final completed = results.where((a) {
        final s = a.status.toLowerCase().trim();
        return s == 'completed' || s == 'performed';
      }).toList();

      completed.sort((a, b) {
        final cmp = b.appointmentDate.compareTo(a.appointmentDate);
        if (cmp != 0) return cmp;
        return b.startTime.compareTo(a.startTime);
      });

      setState(() {
        _completedAppointments = completed;
        _currentPage = 1;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching appointments: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _resetSearch() {
    _searchController.clear();
    _performSearch();
  }

  List<AppointmentModel> get _filteredHistory => _completedAppointments;

  double get _totalCompletedRevenue =>
      _allCompletedAppointments.fold(0.0, (acc, a) => acc + a.totalAmount);

  int get _todayCompletedCount {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _completedAppointments
        .where((a) => a.appointmentDate == todayStr)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredHistory;
    final totalItems = displayList.length;
    final totalPages = totalItems == 0 ? 1 : ((totalItems - 1) ~/ _pageSize) + 1;
    final validPage = _currentPage.clamp(1, totalPages);
    final startIndex = (validPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final pageAppointments = totalItems == 0
        ? <AppointmentModel>[]
        : displayList.sublist(startIndex, endIndex);

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

            // 3. Search Bar
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
                      : _buildCompletedList(pageAppointments),
            ),

            // 5. Pagination Controls at Bottom
            if (!_isLoading && displayList.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildPaginationControls(totalItems, totalPages),
            ],
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
                  'Appointment History',
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
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
    final hasActiveSearch = _activeSearchQuery.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            height: 38,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search customer name, phone, or staff...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          if (hasActiveSearch) _performSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isSearching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search, size: 16),
              label: Text(
                'Apply',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isSearching ? null : _performSearch,
            ),
          ),
          if (hasActiveSearch) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close, size: 14),
                label: Text(
                  'Reset',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _resetSearch,
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 15, color: Color(0xFF166534)),
                const SizedBox(width: 6),
                Text(
                  'Audit-Safe Performed Retention',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // COMPLETED APPOINTMENTS LIST - ESSENTIAL INFO ONLY
  // Displays: Appointment Number, Customer Name, Customer Phone Number, Total Amount
  // =========================================================================
  Widget _buildCompletedList(List<AppointmentModel> appointments) {
    return ListView.separated(
      itemCount: appointments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final a = appointments[idx];

        return InkWell(
          onTap: () => _showAppointmentDetails(a),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Appointment Number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#APT-${a.id.toString().padLeft(4, '0')}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Customer Name & 3. Customer Phone Number
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        a.customerName.isNotEmpty ? a.customerName : 'Walk-in Customer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (a.customerPhone.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          a.customerPhone,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (a.staffName.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                a.staffName,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 4. Total Amount
                Text(
                  '\$${a.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // PAGINATION CONTROLS (20 RECORDS PER PAGE)
  // =========================================================================
  Widget _buildPaginationControls(int totalItems, int totalPages) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (_currentPage - 1) * _pageSize + 1;
    final endItem = (_currentPage * _pageSize > totalItems)
        ? totalItems
        : _currentPage * _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Showing $startItem - $endItem of $totalItems records (Page $_currentPage of $totalPages)',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          // Previous Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 16),
                SizedBox(width: 2),
                Text('Prev', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Page number buttons
          ..._buildPageNumberButtons(totalPages),
          const SizedBox(width: 8),
          // Next Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next', style: TextStyle(fontSize: 12)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumberButtons(int totalPages) {
    List<Widget> buttons = [];

    Widget pageBtn(int p) {
      final isSel = p == _currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () => setState(() => _currentPage = p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF10B981) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                '$p',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) {
        buttons.add(pageBtn(i));
      }
    } else {
      buttons.add(pageBtn(1));
      if (_currentPage > 3) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...'),
        ));
      }

      int start = (_currentPage - 1).clamp(2, totalPages - 1);
      int end = (_currentPage + 1).clamp(2, totalPages - 1);

      if (_currentPage <= 3) {
        start = 2;
        end = 4;
      } else if (_currentPage >= totalPages - 2) {
        start = totalPages - 3;
        end = totalPages - 1;
      }

      for (int i = start; i <= end; i++) {
        buttons.add(pageBtn(i));
      }

      if (_currentPage < totalPages - 2) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...'),
        ));
      }
      buttons.add(pageBtn(totalPages));
    }

    return buttons;
  }

  // =========================================================================
  // COMPLETE APPOINTMENT DETAILS POPUP
  // =========================================================================
  void _showAppointmentDetails(AppointmentModel a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '#APT-${a.id.toString().padLeft(4, '0')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF166534)),
                        const SizedBox(width: 4),
                        Text(
                          a.status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Customer & Staff Information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                      Text(
                        a.customerName.isNotEmpty ? a.customerName : 'Walk-in Guest',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      if (a.customerPhone.isNotEmpty)
                        Text(a.customerPhone, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Assigned Staff', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                      Text(
                        a.staffName.isNotEmpty ? a.staffName : 'Staff #${a.staffId}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _staffList.any((st) => st.id == a.staffId)
                            ? _staffList.firstWhere((st) => st.id == a.staffId).role
                            : 'Staff ID: #${a.staffId}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Schedule Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          a.appointmentDate,
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 18, color: Colors.grey.shade300),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          '${a.startTime} - ${a.endTime}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Services Breakdown
              Text(
                'Services Performed (${a.services.length})',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (a.services.isEmpty)
                Text('No specific service items recorded',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500))
              else
                Container(
                  height: a.services.length >= 4 ? 140 : null,
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Scrollbar(
                    thumbVisibility: a.services.length > 4,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      itemCount: a.services.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, idx) {
                        final s = a.services[idx];
                        final name = (s['name'] ?? s['product_name'] ?? 'Service').toString();
                        final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0.0;
                        return Container(
                          height: 32,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(name, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                              ),
                              Text('\$${price.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              if (a.notes.isNotEmpty) ...[
                const Divider(height: 20),
                Text('Notes / Observations', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(a.notes, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569))),
              ],

              const Divider(height: 20),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    '\$${a.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
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
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_edu_outlined, size: 48, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            _activeSearchQuery.isNotEmpty
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
            _activeSearchQuery.isNotEmpty
                ? 'Try searching with a different name, date, or appointment #.'
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

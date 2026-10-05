import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sale_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SalesHistoryView extends StatefulWidget {
  const SalesHistoryView({super.key});

  @override
  State<SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<SalesHistoryView> {
  List<SaleModel> _allSales = [];
  List<SaleModel> _baselineSales = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchQuery = '';
  // Payment method filter: 'all', 'cash', 'card', 'qr'
  String _activeFilter = 'all';

  // Pagination: 20 records per page
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final rawSales = await ApiService.getSales();
      if (!mounted) return;
      // Strictly POS/Cart transactions only
      final sales = rawSales.where((s) => s.appointmentId == null || s.appointmentId == 0).toList();
      setState(() {
        _baselineSales = sales;
        _allSales = sales;
        // Sort newest first
        _allSales.sort((a, b) {
          final dtA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });
        _currentPage = 1;
        _isLoading = false;
        _activeSearchQuery = '';
      });
      _searchController.clear();
    } catch (e) {
      debugPrint('Error loading sales history: $e');
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
      final rawSales = await ApiService.getSales(
        search: query.isNotEmpty ? query : null,
      );
      if (!mounted) return;
      final sales = rawSales.where((s) => s.appointmentId == null || s.appointmentId == 0).toList();
      setState(() {
        _allSales = sales;
        _allSales.sort((a, b) {
          final dtA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });
        _currentPage = 1;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching sales: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _resetSearch() {
    _searchController.clear();
    _performSearch();
  }

  List<SaleModel> get _filteredSales {
    var list = _allSales;

    // Apply payment method filter
    if (_activeFilter == 'cash') {
      list = list.where((s) => s.paymentMethod.toLowerCase() == 'cash').toList();
    } else if (_activeFilter == 'card') {
      list = list.where((s) => s.paymentMethod.toLowerCase() == 'card').toList();
    } else if (_activeFilter == 'qr') {
      list = list.where((s) => s.paymentMethod.toLowerCase() == 'qr').toList();
    }

    return list;
  }

  // Summary counts
  int get _cashOrdersCount =>
      _baselineSales.where((s) => s.paymentMethod.toLowerCase() == 'cash').length;
  int get _cardOrdersCount =>
      _baselineSales.where((s) => s.paymentMethod.toLowerCase() == 'card').length;

  double get _totalRevenue =>
      _baselineSales.fold(0.0, (acc, s) => acc + s.totalAmount);
  double get _avgOrderValue =>
      _baselineSales.isEmpty ? 0.0 : _totalRevenue / _baselineSales.length;

  @override
  Widget build(BuildContext context) {
    final displaySales = _filteredSales;
    final totalItems = displaySales.length;
    final totalPages = totalItems == 0 ? 1 : ((totalItems - 1) ~/ _pageSize) + 1;
    final validPage = _currentPage.clamp(1, totalPages);
    final startIndex = (validPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final pageSales = totalItems == 0
        ? <SaleModel>[]
        : displaySales.sublist(startIndex, endIndex);

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

            // 2. Summary KPI Metrics
            _buildMetricsRow(),
            const SizedBox(height: 20),

            // 3. Filter Bar & Search
            _buildFilterAndSearchBar(),
            const SizedBox(height: 16),

            // 4. Sales List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE11D48),
                      ),
                    )
                  : displaySales.isEmpty
                      ? _buildEmptyState()
                      : _buildSalesList(pageSales),
            ),

            // 5. Pagination Controls at Bottom
            if (!_isLoading && displaySales.isNotEmpty) ...[
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
                  'Sales History & POS Orders',
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
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_allSales.length} Total Orders',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4338CA),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Action Buttons: Refresh
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerLowest,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                side: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
              onPressed: _isLoading ? null : _loadSales,
            ),
          ],
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
          title: 'Total Completed Orders',
          value: '${_allSales.length} Orders',
          sub: 'Total completed sales transactions',
          icon: Icons.receipt_long,
          color: const Color(0xFF4F46E5), // Indigo
          bgColor: const Color(0xFFEEF2FF),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: 'Total Revenue',
          value: '\$${_totalRevenue.toStringAsFixed(2)}',
          sub: 'Combined sales across all payment modes',
          icon: Icons.payments_outlined,
          color: const Color(0xFF059669), // Emerald
          bgColor: const Color(0xFFECFDF5),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: 'Average Order Value',
          value: '\$${_avgOrderValue.toStringAsFixed(2)}',
          sub: 'Average checkout transaction ticket',
          icon: Icons.analytics_outlined,
          color: const Color(0xFFE11D48), // Rose
          bgColor: const Color(0xFFFFF1F2),
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
  // FILTER BAR & SEARCH
  // =========================================================================
  Widget _buildFilterAndSearchBar() {
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
          // Category Filters
          _buildFilterChip('all', 'All Sales (${_allSales.length})'),
          const SizedBox(width: 8),
          _buildFilterChip(
            'cash',
            'Cash ($_cashOrdersCount)',
            highlightColor: const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'card',
            'Card ($_cardOrdersCount)',
            highlightColor: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'qr',
            'QR Payment',
            highlightColor: const Color(0xFF9333EA),
          ),
          const Spacer(),

          // Search Input
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search customer, phone, staff...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          if (_activeSearchQuery.isNotEmpty) _performSearch();
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
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
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
                backgroundColor: const Color(0xFF4F46E5),
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
          if (_activeSearchQuery.isNotEmpty) ...[
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? highlightColor}) {
    final isSelected = _activeFilter == filterKey;
    final color = highlightColor ?? const Color(0xFFE11D48);

    return InkWell(
      onTap: () => setState(() {
        _activeFilter = filterKey;
        _currentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SALES LIST - SIMPLIFIED DISPLAY (NORMAL SALES INFO ONLY)
  // =========================================================================
  Widget _buildSalesList(List<SaleModel> sales) {
    return ListView.separated(
      itemCount: sales.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final sale = sales[idx];

        return InkWell(
          onTap: () => _showReceiptDetails(sale),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35),
              ),
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
                // Clean Receipt Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF475569),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),

                // Order details: Invoice Number, Status, Customer, Date/Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sale.receiptNumber,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 11, color: Color(0xFF166534)),
                                const SizedBox(width: 4),
                                Text(
                                  'Completed',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Customer Information & Date/Time
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            sale.customerName.isNotEmpty
                                ? sale.customerName
                                : 'Walk-in Customer',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          if (sale.customerPhone.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${sale.customerPhone})',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                          if (sale.staffName.isNotEmpty) ...[
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    sale.staffName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(sale.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sales Amount & Payment Information
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${sale.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _paymentBadgeColor(sale.paymentMethod),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sale.paymentMethodLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _paymentTextColor(sale.paymentMethod),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
              color: isSel ? const Color(0xFFE11D48) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel ? const Color(0xFFE11D48) : Colors.grey.shade300,
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
  // RECEIPT DETAIL MODAL (SHOWS COMPLETE INFO INCLUDING APPOINTMENT IF APPLICABLE)
  // =========================================================================
  void _showReceiptDetails(SaleModel sale) {
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
                        'Tax Receipt & Order Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        sale.receiptNumber,
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
                          'Completed',
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

              // Appointment Link Information (if applicable)
              if (sale.appointmentId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Text(
                        'Linked Appointment: #${sale.appointmentId}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF059669),
                        ),
                      ),
                      if (sale.staffName.isNotEmpty) ...[
                        const Spacer(),
                        Text(
                          'Attendant: ${sale.staffName}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Customer & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                      Text(
                        sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in Guest',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      if (sale.customerPhone.isNotEmpty)
                        Text(sale.customerPhone, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Date & Time', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                      Text(_formatDateTime(sale.createdAt), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (sale.staffName.isNotEmpty && sale.appointmentId == null)
                        Text('Attendant: ${sale.staffName}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Item Breakdown
              Text(
                'Purchased Items (${sale.items.length})',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sale.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 8),
                  itemBuilder: (context, idx) {
                    final it = sale.items[idx];
                    final name = (it['product_name'] ?? it['name'] ?? 'Item').toString();
                    final qty = it['quantity'] ?? 1;
                    final price = double.tryParse(it['unit_price']?.toString() ?? '0') ?? 0.0;
                    final lineTotal = double.tryParse(it['line_total']?.toString() ?? '0') ?? (price * qty);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name ×$qty',
                            style: GoogleFonts.inter(fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${lineTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 20),

              // Financial Summary
              _modalRow('Subtotal', '\$${sale.subtotal.toStringAsFixed(2)}'),
              if (sale.itemDiscountTotal > 0)
                _modalRow('Item Discounts', '-\$${sale.itemDiscountTotal.toStringAsFixed(2)}', color: const Color(0xFFE11D48)),
              if (sale.overallDiscount > 0)
                _modalRow('Overall Discount', '-\$${sale.overallDiscount.toStringAsFixed(2)}', color: const Color(0xFFE11D48)),
              _modalRow('Tax', '\$${sale.taxAmount.toStringAsFixed(2)}'),
              const Divider(height: 12),
              _modalRow(
                'Total Paid',
                '\$${sale.totalAmount.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 16,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Method', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                  Text('${sale.paymentMethodLabel} (Tendered: \$${sale.amountTendered.toStringAsFixed(2)})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              if (sale.changeAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Change Returned', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                    Text('\$${sale.changeAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                  ],
                ),
              ],
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

  Widget _modalRow(String label, String value, {bool isBold = false, double fontSize = 12.5, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: fontSize, color: Colors.grey.shade600)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
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
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            _activeSearchQuery.isNotEmpty
                ? 'No orders match your search'
                : 'No sales records found',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            _activeSearchQuery.isNotEmpty
                ? 'Try searching with a different keyword or reset filters.'
                : 'Orders completed in the Cart POS will immediately appear here.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reload Sales'),
            onPressed: _loadSales,
          ),
        ],
      ),
    );
  }

  // Helper formatting
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min $ampm';
  }

  Color _paymentBadgeColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFFECFDF5);
      case 'card':
        return const Color(0xFFEFF6FF);
      case 'qr':
        return const Color(0xFFFAF5FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _paymentTextColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFF059669);
      case 'card':
        return const Color(0xFF2563EB);
      case 'qr':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF475569);
    }
  }
}

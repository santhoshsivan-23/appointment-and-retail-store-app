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
  bool _isLoading = true;
  String _searchQuery = '';
  // Filter: 'all', 'cart_only' (normal orders from cart), 'appointment_only'
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final sales = await ApiService.getSales();
      if (!mounted) return;
      setState(() {
        _allSales = sales;
        // Sort newest first
        _allSales.sort((a, b) {
          final dtA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sales history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<SaleModel> get _filteredSales {
    var list = _allSales;

    // Apply category filter
    if (_activeFilter == 'cart_only') {
      // Normal orders placed directly from cart have appointmentId == null
      list = list.where((s) => s.appointmentId == null).toList();
    } else if (_activeFilter == 'appointment_only') {
      list = list.where((s) => s.appointmentId != null).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((s) {
        final matchesReceipt = s.receiptNumber.toLowerCase().contains(q);
        final matchesCustomer = s.customerName.toLowerCase().contains(q);
        final matchesPhone = s.customerPhone.toLowerCase().contains(q);
        final matchesStaff = s.staffName.toLowerCase().contains(q);
        final matchesItem = s.items.any((it) =>
            (it['product_name'] ?? it['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q));
        return matchesReceipt ||
            matchesCustomer ||
            matchesPhone ||
            matchesStaff ||
            matchesItem;
      }).toList();
    }

    return list;
  }

  // Summary counts
  int get _cartOrdersCount => _allSales.where((s) => s.appointmentId == null).length;
  double get _cartOrdersRevenue => _allSales
      .where((s) => s.appointmentId == null)
      .fold(0.0, (acc, s) => acc + s.totalAmount);

  int get _appointmentOrdersCount =>
      _allSales.where((s) => s.appointmentId != null).length;
  double get _appointmentOrdersRevenue => _allSales
      .where((s) => s.appointmentId != null)
      .fold(0.0, (acc, s) => acc + s.totalAmount);

  double get _totalRevenue =>
      _allSales.fold(0.0, (acc, s) => acc + s.totalAmount);

  @override
  Widget build(BuildContext context) {
    final displaySales = _filteredSales;

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
                      : _buildSalesList(displaySales),
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
            const SizedBox(height: 4),
            Text(
              'Track and audit normal orders placed directly from the cart and appointment checkout receipts.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
              ),
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
          title: '🛒 Normal Cart Orders',
          value: '$_cartOrdersCount Orders',
          sub: 'Direct POS cart sales: \$${_cartOrdersRevenue.toStringAsFixed(2)}',
          icon: Icons.shopping_cart_checkout,
          color: const Color(0xFF4F46E5), // Indigo
          bgColor: const Color(0xFFEEF2FF),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: '📅 Appointment Orders',
          value: '$_appointmentOrdersCount Orders',
          sub: 'Service checkouts: \$${_appointmentOrdersRevenue.toStringAsFixed(2)}',
          icon: Icons.calendar_month,
          color: const Color(0xFF059669), // Emerald
          bgColor: const Color(0xFFECFDF5),
        ),
        const SizedBox(width: 14),
        _buildMetricCard(
          title: '💰 Total Revenue',
          value: '\$${_totalRevenue.toStringAsFixed(2)}',
          sub: 'Combined sales across all channels',
          icon: Icons.payments_outlined,
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
  // FILTER BAR & SEARCH
  // =========================================================================
  Widget _buildFilterAndSearchBar() {
    return Row(
      children: [
        // Category Filters
        _buildFilterChip('all', 'All Orders (${_allSales.length})'),
        const SizedBox(width: 8),
        _buildFilterChip(
          'cart_only',
          '🛒 Direct Cart Orders ($_cartOrdersCount)',
          highlightColor: const Color(0xFF4F46E5),
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          'appointment_only',
          '📅 Appointment Orders ($_appointmentOrdersCount)',
          highlightColor: const Color(0xFF059669),
        ),
        const Spacer(),

        // Search Input
        SizedBox(
          width: 280,
          height: 38,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search receipt, customer, item...',
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
                borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? highlightColor}) {
    final isSelected = _activeFilter == filterKey;
    final color = highlightColor ?? const Color(0xFFE11D48);

    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
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
  // SALES LIST
  // =========================================================================
  Widget _buildSalesList(List<SaleModel> sales) {
    return ListView.separated(
      itemCount: sales.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final sale = sales[idx];
        final isCartOrder = sale.appointmentId == null;

        return InkWell(
          onTap: () => _showReceiptDetails(sale),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCartOrder
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.25)
                    : AppTheme.outlineVariant.withValues(alpha: 0.35),
                width: isCartOrder ? 1.5 : 1,
              ),
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
                // Order Type & Receipt Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCartOrder
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCartOrder
                        ? Icons.shopping_cart_outlined
                        : Icons.calendar_month_outlined,
                    color: isCartOrder
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Order Details
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
                          const SizedBox(width: 8),

                          // Direct Cart Order Badge vs Appointment Badge
                          if (isCartOrder)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shopping_cart,
                                      size: 11, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DIRECT CART ORDER',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event,
                                      size: 11, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'APPOINTMENT #${sale.appointmentId}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Customer & Date
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
                            Text(
                              ' (${sale.customerPhone})',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 6),

                      // Items summary pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: sale.items.take(4).map((it) {
                          final name = (it['product_name'] ?? it['name'] ?? 'Item').toString();
                          final qty = it['quantity'] ?? 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$name ×$qty',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList()
                          ..addAll(sale.items.length > 4
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${sale.items.length - 4} more',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                ]
                              : []),
                      ),
                    ],
                  ),
                ),

                // Payment Method & Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${sale.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE11D48),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 14, color: Color(0xFFE11D48)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // RECEIPT DETAIL MODAL
  // =========================================================================
  void _showReceiptDetails(SaleModel sale) {
    final isCartOrder = sale.appointmentId == null;

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
                        'Tax Receipt',
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
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCartOrder ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCartOrder ? '🛒 Direct Cart Order' : '📅 Appointment Order',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCartOrder ? const Color(0xFF4F46E5) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

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
                      if (sale.staffName.isNotEmpty)
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
                constraints: const BoxConstraints(maxHeight: 180),
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
              const Divider(height: 24),

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

              // Close
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
            _searchQuery.isNotEmpty
                ? 'No orders match your search'
                : 'No sales records found',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
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

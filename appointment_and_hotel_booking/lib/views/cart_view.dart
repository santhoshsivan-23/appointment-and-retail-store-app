import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CartItem {
  final ProductModel product;
  int quantity;
  double discount; // Dollar amount discount per item

  CartItem({required this.product, this.quantity = 1, this.discount = 0.0});

  double get lineTotal => (product.price * quantity) - discount;
}

class CartView extends StatefulWidget {
  final CustomerModel? preloadCustomer;
  final List<ProductModel>? preloadProducts;
  final int? preloadAppointmentId;
  final String? preloadStaffName;
  final VoidCallback? onNavigateToSalesHistory;

  const CartView({
    super.key,
    this.preloadCustomer,
    this.preloadProducts,
    this.preloadAppointmentId,
    this.preloadStaffName,
    this.onNavigateToSalesHistory,
  });

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  List<ProductModel> _availableProducts = [];
  List<CategoryModel> _categories = [];
  final List<CartItem> _cart = [];
  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;

  bool _isWalkInMode = false;
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();

  int? _selectedCategoryId; // null = all
  double _overallDiscount = 0.0;
  final _overallDiscountCtrl = TextEditingController(text: '0.00');

  bool _isLoading = true;

  bool get _isAppointmentMode => widget.preloadAppointmentId != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _walkInNameCtrl.dispose();
    _walkInPhoneCtrl.dispose();
    _overallDiscountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final prods = await ApiService.getProducts();
    final custs = await ApiService.getCustomers();
    final cats = await ApiService.getCategories();
    if (!mounted) return;
    setState(() {
      _availableProducts = prods;
      _customers = custs;
      _categories = cats;

      if (widget.preloadCustomer != null) {
        _selectedCustomer = widget.preloadCustomer;
        _isWalkInMode = false;
        if (widget.preloadProducts != null && widget.preloadProducts!.isNotEmpty) {
          for (final p in widget.preloadProducts!) {
            _cart.add(CartItem(product: p, quantity: 1));
          }
        }
      } else {
        if (custs.isNotEmpty) _selectedCustomer = custs.first;
      }
      _isLoading = false;
    });
  }

  List<ProductModel> get _filteredProducts {
    if (_selectedCategoryId == null) return _availableProducts;
    return _availableProducts.where((p) => p.categoryId == _selectedCategoryId).toList();
  }

  double get _subtotal => _cart.fold(0.0, (acc, item) => acc + (item.product.price * item.quantity));
  double get _itemDiscountTotal => _cart.fold(0.0, (acc, item) => acc + item.discount);
  double get _taxableAmount => (_subtotal - _itemDiscountTotal - _overallDiscount).clamp(0, double.infinity);
  double get _tax => _taxableAmount * 0.08;
  double get _grandTotal => _taxableAmount + _tax;

  void _addToCart(ProductModel p) {
    setState(() {
      final existingIdx = _cart.indexWhere((it) => it.product.id == p.id);
      if (existingIdx != -1) {
        _cart[existingIdx].quantity++;
      } else {
        _cart.add(CartItem(product: p, quantity: 1));
      }
    });
  }

  void _showAddCustomerModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Register New Customer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Full Name *')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number *')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (Optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final newC = await ApiService.createCustomer({
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'is_walk_in': false,
              });
              if (newC != null) {
                setState(() {
                  _customers.insert(0, newC);
                  _selectedCustomer = newC;
                  _isWalkInMode = false;
                });
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _showItemDiscountPopover(int cartIdx) {
    final item = _cart[cartIdx];
    final ctrl = TextEditingController(text: item.discount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Discount: ${item.product.name}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unit Price: \$${item.product.price.toStringAsFixed(2)} × ${item.quantity}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Discount Amount (\$)',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _cart[cartIdx].discount = double.tryParse(ctrl.text) ?? 0.0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // PAYMENT MODAL (Phase 8)
  // =====================================================================
  void _showPaymentModal() {
    String selectedMethod = 'cash';
    double amountTendered = _grandTotal;
    final tenderCtrl = TextEditingController(text: _grandTotal.toStringAsFixed(2));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final change = amountTendered - _grandTotal;
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Complete Payment', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Grand Total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFBE123C)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('TOTAL DUE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text('\$${_grandTotal.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Payment Methods
                  Text('Payment Method', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _paymentMethodCard('cash', Icons.payments_outlined, 'Cash', selectedMethod, (v) => setDialogState(() => selectedMethod = v)),
                      const SizedBox(width: 8),
                      _paymentMethodCard('card', Icons.credit_card, 'Card', selectedMethod, (v) => setDialogState(() => selectedMethod = v)),
                      const SizedBox(width: 8),
                      _paymentMethodCard('qr', Icons.qr_code_2, 'QR Code', selectedMethod, (v) => setDialogState(() => selectedMethod = v)),
                      const SizedBox(width: 8),
                      _paymentMethodCard('other', Icons.account_balance_wallet_outlined, 'Other', selectedMethod, (v) => setDialogState(() => selectedMethod = v)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Cash specific: Tender Amount
                  if (selectedMethod == 'cash') ...[
                    Text('Amount Tendered', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tenderCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setDialogState(() => amountTendered = double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 8),
                    // Quick tender buttons
                    Wrap(
                      spacing: 8,
                      children: [_grandTotal, 20, 50, 100, 200].map((amt) {
                        final label = amt == _grandTotal ? 'Exact' : '\$$amt';
                        return ActionChip(
                          label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setDialogState(() {
                              amountTendered = amt.toDouble();
                              tenderCtrl.text = amt.toStringAsFixed(2);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Change
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: change >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: change >= 0 ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(change >= 0 ? 'Change Due' : 'Insufficient', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: change >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                          Text('\$${change.abs().toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: change >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Notes
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Transaction Notes (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (selectedMethod == 'cash' && change < 0)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _processSale(
                                paymentMethod: selectedMethod,
                                amountTendered: selectedMethod == 'cash' ? amountTendered : _grandTotal,
                                changeAmount: selectedMethod == 'cash' ? change.clamp(0, double.infinity) : 0,
                                notes: notesCtrl.text,
                              );
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          Text('Confirm Payment & Save Sale', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paymentMethodCard(String value, IconData icon, String label, String selected, ValueChanged<String> onTap) {
    final isActive = value == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE11D48).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? const Color(0xFFE11D48) : Colors.grey.shade300, width: isActive ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isActive ? const Color(0xFFE11D48) : Colors.grey.shade500),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? const Color(0xFFE11D48) : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processSale({
    required String paymentMethod,
    required double amountTendered,
    required double changeAmount,
    String notes = '',
  }) async {
    // Create walk-in customer if needed
    String custName = _isWalkInMode ? _walkInNameCtrl.text : (_selectedCustomer?.name ?? 'Walk-in');
    String custPhone = _isWalkInMode ? _walkInPhoneCtrl.text : (_selectedCustomer?.phone ?? '');
    int? custId = _isWalkInMode ? null : _selectedCustomer?.id;

    if (_isWalkInMode && _walkInNameCtrl.text.isNotEmpty && _walkInPhoneCtrl.text.isNotEmpty) {
      final newC = await ApiService.createCustomer({
        'name': _walkInNameCtrl.text.trim(),
        'phone': _walkInPhoneCtrl.text.trim(),
        'is_walk_in': true,
      });
      if (newC != null) {
        custId = newC.id;
        custName = newC.name;
        custPhone = newC.phone;
      }
    }

    final sale = await ApiService.createSale({
      'business_id': 1,
      'appointment_id': widget.preloadAppointmentId,
      'customer_id': custId,
      'customer_name': custName,
      'customer_phone': custPhone,
      'staff_id': null,
      'staff_name': widget.preloadStaffName ?? '',
      'subtotal': _subtotal,
      'item_discount_total': _itemDiscountTotal,
      'overall_discount': _overallDiscount,
      'tax_amount': _tax,
      'total_amount': _grandTotal,
      'payment_method': paymentMethod,
      'amount_tendered': amountTendered,
      'change_amount': changeAmount,
      'items': _cart.map((ci) => {
        'product_id': ci.product.id,
        'product_name': ci.product.name,
        'unit_price': ci.product.price,
        'quantity': ci.quantity,
        'discount': ci.discount,
        'line_total': ci.lineTotal,
      }).toList(),
      'notes': notes,
    });

    if (sale != null && mounted) {
      if (widget.preloadAppointmentId != null) {
        await ApiService.updateAppointmentStatus(widget.preloadAppointmentId!, 'completed');
      }
      _showReceiptPopup(sale);
    }
  }

  // =====================================================================
  // RECEIPT POPUP (Phase 8)
  // =====================================================================
  void _showReceiptPopup(SaleModel sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success header
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
                ),
                const SizedBox(height: 12),
                Text('Payment Successful!', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                const SizedBox(height: 4),
                Text(sale.receiptNumber, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const Divider(),

                // Customer & Staff
                _receiptRow('Customer', sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in'),
                if (sale.customerPhone.isNotEmpty) _receiptRow('Phone', sale.customerPhone),
                if (sale.staffName.isNotEmpty) _receiptRow('Staff', sale.staffName),
                _receiptRow('Date', _formatDateTime(sale.createdAt)),
                _receiptRow('Payment', sale.paymentMethodLabel),
                const SizedBox(height: 8),
                const Divider(),

                // Items table
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Items', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                ),
                const SizedBox(height: 6),
                ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['product_name'] ?? ''} × ${item['quantity'] ?? 1}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '\$${((item['line_total'] ?? 0) as num).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                const Divider(),

                // Summary
                _receiptRow('Subtotal', '\$${sale.subtotal.toStringAsFixed(2)}'),
                if (sale.itemDiscountTotal > 0)
                  _receiptRow('Item Discounts', '-\$${sale.itemDiscountTotal.toStringAsFixed(2)}', valueColor: const Color(0xFFE11D48)),
                if (sale.overallDiscount > 0)
                  _receiptRow('Overall Discount', '-\$${sale.overallDiscount.toStringAsFixed(2)}', valueColor: const Color(0xFFE11D48)),
                _receiptRow('Tax (8%)', '\$${sale.taxAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GRAND TOTAL', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('\$${sale.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48))),
                  ],
                ),
                if (sale.paymentMethod == 'cash') ...[
                  const SizedBox(height: 4),
                  _receiptRow('Amount Paid', '\$${sale.amountTendered.toStringAsFixed(2)}'),
                  _receiptRow('Change', '\$${sale.changeAmount.toStringAsFixed(2)}', valueColor: const Color(0xFF10B981)),
                ],
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.print, size: 18),
                        label: Text('Print', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          // Print simulation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Receipt sent to printer.'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onNavigateToSalesHistory != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFFC7D2FE)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: Text('Sales History', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _cart.clear();
                              _overallDiscount = 0;
                              _overallDiscountCtrl.text = '0.00';
                              _walkInNameCtrl.clear();
                              _walkInPhoneCtrl.clear();
                            });
                            widget.onNavigateToSalesHistory?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: Text('New Sale', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _cart.clear();
                            _overallDiscount = 0;
                            _overallDiscountCtrl.text = '0.00';
                            _walkInNameCtrl.clear();
                            _walkInPhoneCtrl.clear();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Full available height for both cards
          children: [
            // Left: Category Section + Product Catalog Grid (Completely inside its own card)
            Expanded(
              flex: 65,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Tabs fully contained inside this card
                    _buildCategoryTabs(),
                    Divider(height: 1, color: Colors.grey.shade200),
                    // Product Catalog Grid inside this card
                    Expanded(child: _buildProductGrid()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right: Cart Section taking FULL AVAILABLE HEIGHT
            SizedBox(
              width: 390,
              child: _buildCartRegister(),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // CATEGORY TABS
  // =====================================================================
  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _categoryTab(null, 'All Items'),
            ..._categories.map((cat) => _categoryTab(cat.id, cat.name)),
          ],
        ),
      ),
    );
  }

  Widget _categoryTab(int? categoryId, String label) {
    final isActive = _selectedCategoryId == categoryId;
    final isAllItems = categoryId == null;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategoryId = categoryId),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFF94A3B8) : Colors.grey.shade300,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAllItems)
                const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFFF97316))
              else
                Icon(
                  Icons.local_offer_outlined,
                  size: 15,
                  color: isActive ? const Color(0xFF0F172A) : Colors.grey.shade500,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // PRODUCT GRID
  // =====================================================================
  Widget _buildProductGrid() {
    final prods = _filteredProducts;
    if (prods.isEmpty) {
      return Center(
        child: Text('No products in this category.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 130,
      ),
      itemCount: prods.length,
      itemBuilder: (context, idx) {
        final p = prods[idx];
        final inCart = _cart.any((it) => it.product.id == p.id);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _addToCart(p),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: inCart ? const Color(0xFFE11D48).withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inCart ? const Color(0xFFE11D48).withValues(alpha: 0.4) : Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.productType != 'normal') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFDDD6FE), borderRadius: BorderRadius.circular(4)),
                    child: Text(p.productType.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${p.price.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48)),
                    ),
                    Icon(
                      inCart ? Icons.check_circle : Icons.add_circle,
                      color: const Color(0xFFE11D48),
                      size: 22,
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

  // =====================================================================
  // CART REGISTER (Right Panel)
  // =====================================================================
  Widget _buildCartRegister() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Register (${_cart.length})', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              if (_cart.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _cart.clear()),
                  child: Text('Clear All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48))),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer selection section inside top of Cart
          _buildCartCustomerSection(),
          const Divider(height: 20),

          // Cart Items
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Cart is empty', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400)),
                        Text('Tap items on the left to add', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => Divider(height: 12, color: Colors.grey.shade100),
                    itemBuilder: (context, idx) {
                      final it = _cart[idx];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Row(
                                  children: [
                                    Text('\$${it.product.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                                    if (it.discount > 0) ...[
                                      const SizedBox(width: 4),
                                      Text('-\$${it.discount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Discount button
                          InkWell(
                            onTap: () => _showItemDiscountPopover(idx),
                            child: Icon(Icons.local_offer_outlined, size: 16, color: it.discount > 0 ? const Color(0xFFE11D48) : Colors.grey.shade400),
                          ),
                          const SizedBox(width: 4),
                          // Quantity controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (it.quantity > 1) {
                                      it.quantity--;
                                    } else {
                                      _cart.removeAt(idx);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.remove, size: 14),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('${it.quantity}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              InkWell(
                                onTap: () => setState(() => it.quantity++),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.add, size: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Line total
                          SizedBox(
                            width: 56,
                            child: Text(
                              '\$${it.lineTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const Divider(height: 16),

          // Summary
          _summaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
          if (_itemDiscountTotal > 0)
            _summaryRow('Item Discounts', '-\$${_itemDiscountTotal.toStringAsFixed(2)}', valueColor: const Color(0xFFE11D48)),
          const SizedBox(height: 4),
          // Overall Discount
          Row(
            children: [
              Text('Overall Discount', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
              const Spacer(),
              SizedBox(
                width: 80,
                height: 28,
                child: TextField(
                  controller: _overallDiscountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48)),
                  decoration: InputDecoration(
                    prefixText: '-\$ ',
                    prefixStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE11D48)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    filled: true,
                    fillColor: const Color(0xFFFEF2F2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: const Color(0xFFE11D48).withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: const Color(0xFFE11D48).withValues(alpha: 0.3))),
                  ),
                  onChanged: (v) => setState(() => _overallDiscount = double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _summaryRow('Tax (8%)', '\$${_tax.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand Total', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('\$${_grandTotal.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48))),
            ],
          ),
          const SizedBox(height: 14),

          // Proceed to Payment Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              onPressed: _cart.isEmpty ? null : _showPaymentModal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Proceed to Payment (\$${_grandTotal.toStringAsFixed(2)})', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade500)),
          Text(value, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildCartCustomerSection() {
    if (_isAppointmentMode) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, size: 14, color: Color(0xFFB45309)),
                const SizedBox(width: 6),
                Text(
                  'APPOINTMENT #${widget.preloadAppointmentId}',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.preloadCustomer?.name ?? 'Customer'} • ${widget.preloadCustomer?.phone ?? ''}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Walk-in Customer',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isWalkInMode,
                  activeThumbColor: const Color(0xFFE11D48),
                  onChanged: (val) => setState(() => _isWalkInMode = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!_isWalkInMode)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CustomerModel>(
                        value: _selectedCustomer,
                        isExpanded: true,
                        hint: Text('Select Customer', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
                        items: _customers.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A))),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedCustomer = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showAddCustomerModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt_1, size: 16, color: Color(0xFFE11D48)),
                        const SizedBox(width: 4),
                        Text('Add', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48))),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _walkInNameCtrl,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Customer Name',
                        hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _walkInPhoneCtrl,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Phone',
                        hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

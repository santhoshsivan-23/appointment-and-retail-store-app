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
  Map<String, String>? _tempNewCustomer; // In-memory temporary new customer {'name': ..., 'phone': ...}
  int? _currentAppointmentId;
  String? _currentStaffName;

  int? _selectedCategoryId; // null = all
  double _overallDiscount = 0.0;
  final _overallDiscountCtrl = TextEditingController(text: '0.00');

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentAppointmentId = widget.preloadAppointmentId;
    _currentStaffName = widget.preloadStaffName;
    _loadInitialData();
  }

  @override
  void dispose() {
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

      _cart.clear();
      if (widget.preloadCustomer != null || _currentAppointmentId != null) {
        _selectedCustomer = (widget.preloadCustomer != null && widget.preloadCustomer!.name.isNotEmpty && widget.preloadCustomer!.name != 'Walk-in')
            ? widget.preloadCustomer
            : null;
        _tempNewCustomer = null;
        if (widget.preloadProducts != null && widget.preloadProducts!.isNotEmpty) {
          for (final p in widget.preloadProducts!) {
            final idx = _cart.indexWhere((it) => it.product.id == p.id);
            if (idx != -1) {
              _cart[idx].quantity++;
            } else {
              _cart.add(CartItem(product: p, quantity: 1));
            }
          }
        }
      } else {
        // Default: No customer selected -> Walk-in Customer flow
        _selectedCustomer = null;
        _tempNewCustomer = null;
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

  void _showCustomerSelectionDialog() {
    final phoneSearchCtrl = TextEditingController();
    final newNameCtrl = TextEditingController();
    final newPhoneCtrl = TextEditingController();

    bool isSearching = false;
    List<CustomerModel> searchResults = [];
    String? searchMessage;
    String? newError;

    final bool hasActiveCustomer = _selectedCustomer != null || _tempNewCustomer != null;
    final String activeCustName = _selectedCustomer?.name ?? _tempNewCustomer?['name'] ?? '';
    final String activeCustPhone = _selectedCustomer?.phone ?? _tempNewCustomer?['phone'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> performSearch() async {
            final query = phoneSearchCtrl.text.trim();
            if (query.isEmpty) {
              setModalState(() {
                searchMessage = 'Please enter a phone number to search.';
                searchResults = [];
              });
              return;
            }

            setModalState(() {
              isSearching = true;
              searchMessage = null;
              searchResults = [];
            });

            try {
              final results = await ApiService.getCustomers(search: query);
              final cleanQuery = query.replaceAll(RegExp(r'\D'), '');
              final matching = results.where((c) {
                final cleanPhone = c.phone.replaceAll(RegExp(r'\D'), '');
                return cleanPhone.contains(cleanQuery) || c.phone.contains(query);
              }).toList();

              setModalState(() {
                isSearching = false;
                searchResults = matching.isNotEmpty ? matching : results;
                if (searchResults.isEmpty) {
                  searchMessage = 'No customer found with phone "$query".';
                  if (newPhoneCtrl.text.isEmpty) {
                    newPhoneCtrl.text = query;
                  }
                }
              });
            } catch (e) {
              setModalState(() {
                isSearching = false;
                searchMessage = 'Error searching customer. Please try again.';
              });
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 720,
              constraints: const BoxConstraints(maxHeight: 560),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Selection',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search existing customer by phone or register a new customer for this order.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasActiveCustomer) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE11D48),
                                side: const BorderSide(color: Color(0xFFFDA4AF)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.person_remove_outlined, size: 16),
                              label: const Text('Remove Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              onPressed: () {
                                setState(() {
                                  _selectedCustomer = null;
                                  _tempNewCustomer = null;
                                  _currentAppointmentId = null;
                                  _currentStaffName = null;
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Customer removed from cart. Order will checkout as Walk-in Customer.'),
                                    backgroundColor: Color(0xFF475569),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (hasActiveCustomer) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCCD5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: Color(0xFFE11D48)),
                          const SizedBox(width: 8),
                          Text(
                            'Currently Assigned: ',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9F1239)),
                          ),
                          Text(
                            activeCustName + (activeCustPhone.isNotEmpty ? ' ($activeCustPhone)' : ''),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF881337)),
                          ),
                          const Spacer(),
                          Text(
                            _tempNewCustomer != null ? 'Temporary in Memory' : 'Existing in Database',
                            style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF9F1239)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 24),

                  // Two columns: Left (Existing Customer), Right (New Customer)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Existing Customer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.person_search, color: Color(0xFF4F46E5), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Existing Customer',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter phone number to search database and assign customer.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        controller: phoneSearchCtrl,
                                        keyboardType: TextInputType.phone,
                                        style: GoogleFonts.inter(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Enter Phone Number...',
                                          hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                                          prefixIcon: const Icon(Icons.phone, size: 18),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        ),
                                        onSubmitted: (_) => performSearch(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      onPressed: isSearching ? null : performSearch,
                                      child: isSearching
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text('Search', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Search Results area
                              Expanded(
                                child: isSearching
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                                    : searchResults.isNotEmpty
                                        ? ListView.separated(
                                            itemCount: searchResults.length,
                                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                                            itemBuilder: (context, idx) {
                                              final c = searchResults[idx];
                                              final isCurrent = _selectedCustomer?.id == c.id;
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: isCurrent ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: isCurrent ? const Color(0xFF818CF8) : Colors.grey.shade200),
                                                ),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 15,
                                                      backgroundColor: const Color(0xFF4F46E5),
                                                      child: Text(
                                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            c.name,
                                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                                          ),
                                                          Text(
                                                            c.phone,
                                                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: isCurrent ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _selectedCustomer = c;
                                                          _tempNewCustomer = null;
                                                        });
                                                        Navigator.pop(ctx);
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Existing customer "${c.name}" assigned to cart.'),
                                                            backgroundColor: const Color(0xFF4F46E5),
                                                            behavior: SnackBarBehavior.floating,
                                                          ),
                                                        );
                                                      },
                                                      child: Text(isCurrent ? 'Assigned' : 'Assign', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        : searchMessage != null
                                            ? Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFFBEB),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                                ),
                                                child: Text(
                                                  searchMessage!,
                                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E)),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  'Enter phone number above to search existing customers.',
                                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 20),
                        Container(width: 1, color: Colors.grey.shade200),
                        const SizedBox(width: 20),

                        // RIGHT: New Customer
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.person_add_alt_1, color: Color(0xFFE11D48), size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'New Customer',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter name and phone. Stored in memory; saved to DB when order completes.',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: newNameCtrl,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name *',
                                    hintText: 'Enter full name...',
                                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: newPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number *',
                                    hintText: 'Enter phone number...',
                                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Customer info will not be saved to DB yet. Only after order payment is completed will it be stored in the database.',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (newError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(newError!, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE11D48),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.save_outlined, size: 16),
                                    label: const Text('Save Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    onPressed: () {
                                      final name = newNameCtrl.text.trim();
                                      final phone = newPhoneCtrl.text.trim();
                                      if (name.isEmpty) {
                                        setModalState(() => newError = 'Customer Name is required.');
                                        return;
                                      }
                                      if (phone.isEmpty) {
                                        setModalState(() => newError = 'Phone Number is required.');
                                        return;
                                      }
                                      setState(() {
                                        _tempNewCustomer = {
                                          'name': name,
                                          'phone': phone,
                                        };
                                        _selectedCustomer = null;
                                      });
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Temporary customer "$name" assigned to cart.'),
                                          backgroundColor: const Color(0xFFE11D48),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
    int? custId;
    String custName = 'Walk-in';
    String custPhone = '';

    if (_selectedCustomer != null) {
      // 1. Existing Customer (retrieved from API/database)
      custId = _selectedCustomer!.id;
      custName = _selectedCustomer!.name;
      custPhone = _selectedCustomer!.phone;
    } else if (_tempNewCustomer != null) {
      // 2. New Customer (stored temporarily in memory) -> Permanently save to DB on order completion
      try {
        final newC = await ApiService.createCustomer({
          'name': _tempNewCustomer!['name']!.trim(),
          'phone': _tempNewCustomer!['phone']!.trim(),
          'email': '',
          'is_walk_in': false,
        });
        if (newC != null) {
          custId = newC.id;
          custName = newC.name;
          custPhone = newC.phone;
          _customers.insert(0, newC);
        } else {
          custName = _tempNewCustomer!['name']!;
          custPhone = _tempNewCustomer!['phone']!;
          custId = null;
        }
      } catch (e) {
        debugPrint('Error saving temporary customer on checkout: $e');
        custName = _tempNewCustomer!['name']!;
        custPhone = _tempNewCustomer!['phone']!;
        custId = null;
      }
      // Clear temporary customer from memory
      _tempNewCustomer = null;
    } else {
      // 3. Walk-in Customer -> Customer ID/number remains NULL (no unnecessary record created in DB)
      custId = null;
      custName = 'Walk-in';
      custPhone = '';
    }

    final sale = await ApiService.createSale({
      'business_id': 1,
      'appointment_id': _currentAppointmentId,
      'customer_id': custId,
      'customer_name': custName,
      'customer_phone': custPhone,
      'staff_id': null,
      'staff_name': _currentStaffName ?? '',
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
      if (_currentAppointmentId != null) {
        await ApiService.updateAppointmentStatus(_currentAppointmentId!, 'completed');
      }
      _currentAppointmentId = null;
      _currentStaffName = null;
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
                              _selectedCustomer = null;
                              _tempNewCustomer = null;
                              _currentAppointmentId = null;
                              _currentStaffName = null;
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
                            _selectedCustomer = null;
                            _tempNewCustomer = null;
                            _currentAppointmentId = null;
                            _currentStaffName = null;
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
    final hasCustomer = _selectedCustomer != null || _tempNewCustomer != null;

    if (!hasCustomer) {
      // Display ONLY the Add Customer button when no customer is selected
      return InkWell(
        onTap: _showCustomerSelectionDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  size: 16,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Customer',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Customer is selected (Existing or Temporary New Customer)
    final String custName = _selectedCustomer?.name ?? _tempNewCustomer?['name'] ?? '';
    final String custPhone = _selectedCustomer?.phone ?? _tempNewCustomer?['phone'] ?? '';
    final bool isTempNew = _tempNewCustomer != null;

    return InkWell(
      onTap: _showCustomerSelectionDialog,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFCCD5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE11D48),
              child: Text(
                custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          custName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTempNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'New (Temp)',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ] else if (_currentAppointmentId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'Apt #$_currentAppointmentId',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (custPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      custPhone,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: Color(0xFFE11D48),
            ),
          ],
        ),
      ),
    );
  }
}

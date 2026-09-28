import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class CartView extends StatefulWidget {
  const CartView({super.key});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  List<ProductModel> _availableProducts = [];
  final List<CartItem> _cart = [];
  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;

  bool _isWalkInMode = false;
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _walkInNameCtrl.dispose();
    _walkInPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final prods = await ApiService.getProducts();
    final custs = await ApiService.getCustomers();
    if (!mounted) return;
    setState(() {
      _availableProducts = prods;
      _customers = custs;
      if (custs.isNotEmpty) _selectedCustomer = custs.first;
      // Pre-add 2 items to demo POS cart
      if (prods.length >= 2) {
        _cart.add(CartItem(product: prods[0], quantity: 1));
        _cart.add(CartItem(product: prods[1], quantity: 1));
      }
      _isLoading = false;
    });
  }

  void _showAddCustomerModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  double get _subtotal => _cart.fold(0.0, (acc, item) => acc + item.total);
  double get _tax => _subtotal * 0.08;
  double get _grandTotal => _subtotal + _tax;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Catalog Picker (Products & Services)
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Point of Sale Catalog',
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                      Text(
                        'Tap item to add to register cart',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 140,
                      ),
                      itemCount: _availableProducts.length,
                      itemBuilder: (context, idx) {
                        final p = _availableProducts[idx];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              final existingIdx = _cart.indexWhere((it) => it.product.id == p.id);
                              if (existingIdx != -1) {
                                _cart[existingIdx].quantity++;
                              } else {
                                _cart.add(CartItem(product: p, quantity: 1));
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '\$${p.price.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const Icon(Icons.add_circle, color: AppTheme.primary, size: 24),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right: Cart Register & Customer Selection
            Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer Header & Walk-In Mode Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Customer Selection', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text('Walk-in', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          Switch(
                            value: _isWalkInMode,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (val) {
                              setState(() => _isWalkInMode = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isWalkInMode) ...[
                    // Walk-in Customer Fields: Name & Phone Number
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_walk, size: 16, color: AppTheme.secondary),
                              const SizedBox(width: 6),
                              Text('Walk-in Customer Details', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _walkInNameCtrl,
                            decoration: const InputDecoration(labelText: 'Walk-in Name *', hintText: 'e.g. Liam Walker'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _walkInPhoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone Number *', hintText: '+1 555-9012'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Registered Customer Selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CustomerModel>(
                            initialValue: _selectedCustomer,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _customers.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text('${c.name} (${c.phone})', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCustomer = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt, color: AppTheme.primary),
                          tooltip: 'Add New Customer',
                          onPressed: _showAddCustomerModal,
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),

                  // Cart Items List
                  Text('Order Register (${_cart.length} items)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Text(
                              'Cart is empty.\nTap items on the left to add.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (context, index) => const Divider(height: 14),
                            itemBuilder: (context, idx) {
                              final it = _cart[idx];
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('\$${it.product.price.toStringAsFixed(2)} each', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            if (it.quantity > 1) {
                                              it.quantity--;
                                            } else {
                                              _cart.removeAt(idx);
                                            }
                                          });
                                        },
                                      ),
                                      Text('${it.quantity}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        onPressed: () => setState(() => it.quantity++),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '\$${it.total.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  const Divider(height: 20),

                  // Subtotals & Grand Total
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                    Text('\$${_subtotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Estimated Tax (8%)', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                    Text('\$${_tax.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Grand Total', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(
                      '\$${_grandTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Tender / Checkout Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                            String custName = _isWalkInMode ? _walkInNameCtrl.text : (_selectedCustomer?.name ?? 'Walk-in');
                            if (_isWalkInMode && _walkInNameCtrl.text.isNotEmpty && _walkInPhoneCtrl.text.isNotEmpty) {
                              await ApiService.createCustomer({
                                'name': _walkInNameCtrl.text.trim(),
                                'phone': _walkInPhoneCtrl.text.trim(),
                                'is_walk_in': true,
                              });
                            }
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Row(children: [
                                  const Icon(Icons.check_circle, color: AppTheme.tertiary),
                                  const SizedBox(width: 8),
                                  const Text('Receipt Tendered!'),
                                ]),
                                content: Text('Tendered \$${_grandTotal.toStringAsFixed(2)} for $custName successfully.'),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _cart.clear();
                                        _walkInNameCtrl.clear();
                                        _walkInPhoneCtrl.clear();
                                      });
                                    },
                                    child: const Text('New Order'),
                                  ),
                                ],
                              ),
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payments_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('Tender & Checkout', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

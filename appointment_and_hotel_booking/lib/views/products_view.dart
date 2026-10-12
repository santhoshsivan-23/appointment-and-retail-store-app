import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../theme/app_theme.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  int _localDbCount = 0;

  String _selectedType = 'all'; // 'all', 'normal', 'modifier', 'combo'
  int? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool syncLocal = true}) async {
    setState(() => _isLoading = true);
    final cats = await ApiService.getCategories();
    List<ProductModel> prods = [];

    try {
      prods = await ApiService.getProducts(
        categoryId: _selectedCategoryId,
        productType: _selectedType == 'all' ? null : _selectedType,
        search: _searchQuery,
      );

      // On full unfiltered load, ensure SQLite has latest product catalog
      if (syncLocal && _selectedCategoryId == null && _selectedType == 'all' && _searchQuery.isEmpty) {
        await SqliteService.syncProducts(prods);
      }
    } catch (_) {
      // Offline fallback: load from SQLite if API is unavailable
      final localAll = await SqliteService.getActiveProducts();
      prods = localAll.where((p) {
        if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) return false;
        if (_selectedType != 'all' && p.productType != _selectedType) return false;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          return p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.description.toLowerCase().contains(q);
        }
        return true;
      }).toList();
    }

    final localCount = await SqliteService.getActiveProductsCount();

    if (!mounted) return;
    setState(() {
      _categories = cats;
      _products = prods;
      _localDbCount = localCount;
      _isLoading = false;
    });
  }

  /// Synchronize product data between Product API and local SQLite database
  Future<void> _syncProductsWithSqlite({bool showFeedback = true}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      // 1. Fetch all products from API (source of truth)
      final apiProducts = await ApiService.getProducts();
      // 2. Store or update retrieved product data in SQLite
      final count = await SqliteService.syncProducts(apiProducts);
      final totalLocal = await SqliteService.getActiveProductsCount();

      if (!mounted) return;
      setState(() {
        _localDbCount = totalLocal;
      });

      await _loadData(syncLocal: false);

      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synchronized $count products to SQLite database.'),
            backgroundColor: AppTheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to synchronize products with SQLite: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddEditProductModal({ProductModel? existing}) {
    final activeCategories = _categories.where((c) => !c.isDeleted && c.isActive).toList();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku.isNotEmpty == true ? existing!.sku : 'PRD-${DateTime.now().millisecondsSinceEpoch % 1000}');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(2) : '25.00');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String prodType = existing?.productType ?? 'normal';
    int? catId;
    if (existing?.categoryId != null && activeCategories.any((c) => c.id == existing!.categoryId)) {
      catId = existing!.categoryId;
    } else if (activeCategories.isNotEmpty) {
      catId = activeCategories.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Create New Product / Service' : 'Edit Product / Service',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Type Selector
                  Text('Product Architecture Type *', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTypeChoiceChip('normal', 'Normal Product', prodType, (t) => setModalState(() => prodType = t)),
                      _buildTypeChoiceChip('modifier', 'Modifier / Addon', prodType, (t) => setModalState(() => prodType = t)),
                      _buildTypeChoiceChip('combo', 'Combo Bundle', prodType, (t) => setModalState(() => prodType = t)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: prodType == 'combo' ? 'Combo Bundle Name *' : 'Product / Service Name *',
                      hintText: prodType == 'combo' ? 'e.g. Grooming + Diet Pack' : 'e.g. Executive Meeting Hall / Spa Bath',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Price (\$) *', prefixText: '\$ '),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: skuCtrl,
                          decoration: const InputDecoration(labelText: 'SKU / Code', hintText: 'e.g. MED-01'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Selector
                  if (activeCategories.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: catId,
                      decoration: const InputDecoration(labelText: 'Assign Category *'),
                      items: activeCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setModalState(() => catId = v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional notes or item details'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final payload = {
                  'name': nameCtrl.text.trim(),
                  'product_type': prodType,
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'sku': skuCtrl.text.trim(),
                  'category_id': catId,
                  'description': descCtrl.text.trim(),
                };

                bool apiSuccess = false;
                if (existing == null) {
                  // Rule 2: Add New Product - send to API first
                  apiSuccess = await ApiService.createProduct(payload);
                } else {
                  // Rule 3: Edit Existing Product - send to Update API first
                  apiSuccess = await ApiService.updateProduct(existing.id, payload);
                }

                if (apiSuccess) {
                  // After API succeeds, call Product API again to fetch latest product list
                  final allProducts = await ApiService.getProducts();
                  // Store or synchronize latest product data in SQLite
                  await SqliteService.syncProducts(allProducts);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing == null
                            ? 'Product created and synchronized with SQLite.'
                            : 'Product updated and synchronized with SQLite.'),
                        backgroundColor: AppTheme.secondary,
                      ),
                    );
                  }
                  await _loadData(syncLocal: false);
                } else {
                  // Rule 5: If API fails, do NOT update SQLite or treat as success
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing == null
                            ? 'Failed to create product on server. SQLite was not modified.'
                            : 'Failed to update product on server. SQLite was not modified.'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Save Product' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChoiceChip(String type, String label, String current, Function(String) onSelect) {
    final isSel = current == type;
    return ChoiceChip(
      selected: isSel,
      label: Text(label),
      selectedColor: AppTheme.primaryContainer.withValues(alpha: 0.2),
      side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.4)),
      labelStyle: TextStyle(
        color: isSel ? AppTheme.primary : AppTheme.onSurface,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelect(type),
    );
  }

  void _deleteProduct(ProductModel prod) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Delete "${prod.name}"? Past sales and appointments will preserve the item line.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      // Rule 4: Send request to Delete Product API first
      final apiSuccess = await ApiService.deleteProduct(prod.id);

      if (apiSuccess) {
        // After API successfully processes deletion, call Product API again
        final allProducts = await ApiService.getProducts();
        // Synchronize SQLite with latest API response
        await SqliteService.syncProducts(allProducts);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${prod.name}" deleted and SQLite synchronized.'),
              backgroundColor: AppTheme.secondary,
            ),
          );
        }
        await _loadData(syncLocal: false);
      } else {
        // If API fails, do NOT update SQLite
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete "${prod.name}" on server. SQLite was not modified.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls Bar: Search & Add
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.onSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              _searchQuery = val;
                              _loadData();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search products by name, SKU, or notes...',
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Update Product Button (Synchronizes with SQLite)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.6), width: 1.5),
                    backgroundColor: AppTheme.secondaryContainer.withValues(alpha: 0.15),
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondary),
                        )
                      : const Icon(Icons.sync, size: 20),
                  label: Text(
                    _isSyncing ? 'Syncing...' : 'Update Product',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSyncing ? null : () => _syncProductsWithSqlite(showFeedback: true),
                ),
                const SizedBox(width: 12),

                // New Product Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  label: Text('New Product', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditProductModal(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Type Tabs & Category Filter Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeTab('all', 'All Products (${_products.length})'),
                  const SizedBox(width: 8),
                  _buildTypeTab('normal', ' Normal Products'),
                  const SizedBox(width: 8),
                  _buildTypeTab('modifier', ' Modifiers & Add-ons'),
                  const SizedBox(width: 8),
                  _buildTypeTab('combo', ' Combo Bundles'),
                  const SizedBox(width: 16),
                  Container(height: 24, width: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 16),
                  _buildCategoryChip(null, 'All Categories'),
                  ..._categories.where((c) => !c.isDeleted && c.isActive).map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildCategoryChip(c.id, c.name),
                      )),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storage_outlined, size: 14, color: AppTheme.secondary),
                        const SizedBox(width: 5),
                        Text(
                          'SQLite: $_localDbCount items',
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Products Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 54, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text('No products matched filter', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 190,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, idx) {
                            final prod = _products[idx];
                            return _buildProductCard(prod);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String type, String label) {
    final isSel = _selectedType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _selectedType = type);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primary : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : AppTheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(int? catId, String label) {
    final isSel = _selectedCategoryId == catId;
    return ChoiceChip(
      selected: isSel,
      label: Text(label),
      selectedColor: AppTheme.secondaryContainer.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        color: isSel ? AppTheme.secondary : AppTheme.onSurfaceVariant,
      ),
      onSelected: (_) {
        setState(() => _selectedCategoryId = catId);
        _loadData();
      },
    );
  }

  Widget _buildProductCard(ProductModel prod) {
    Color typeColor = AppTheme.primary;
    String typeLabel = 'Normal';
    if (prod.productType == 'modifier') {
      typeColor = const Color(0xFF855300);
      typeLabel = 'Modifier';
    } else if (prod.productType == 'combo') {
      typeColor = const Color(0xFF006C49);
      typeLabel = 'Combo Bundle';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                    tooltip: 'Edit product',
                    onPressed: () => _showAddEditProductModal(existing: prod),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                    tooltip: 'Delete product',
                    onPressed: () => _deleteProduct(prod),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prod.name,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (prod.sku.isNotEmpty)
            Text('SKU: ${prod.sku}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            prod.description.isNotEmpty ? prod.description : 'No description',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${prod.price.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              if (prod.productType == 'combo')
                Text('${prod.comboItems.length} items bundled', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.tertiary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

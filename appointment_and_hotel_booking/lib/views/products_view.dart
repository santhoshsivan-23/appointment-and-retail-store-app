import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await ApiService.getCategories();
    final prods = await ApiService.getProducts(
      categoryId: _selectedCategoryId,
      productType: _selectedType == 'all' ? null : _selectedType,
      search: _searchQuery,
    );
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _products = prods;
      _isLoading = false;
    });
  }

  void _showAddProductModal() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController(text: 'PRD-${DateTime.now().millisecondsSinceEpoch % 1000}');
    final priceCtrl = TextEditingController(text: '25.00');
    final descCtrl = TextEditingController();
    String prodType = 'normal';
    int? catId = _categories.isNotEmpty ? _categories.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create New Product / Service',
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
                  if (_categories.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: catId,
                      decoration: const InputDecoration(labelText: 'Assign Category *'),
                      items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
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
                await ApiService.createProduct({
                  'name': nameCtrl.text.trim(),
                  'product_type': prodType,
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'sku': skuCtrl.text.trim(),
                  'category_id': catId,
                  'description': descCtrl.text.trim(),
                });
                _loadData();
              },
              child: const Text('Save Product'),
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
      await ApiService.deleteProduct(prod.id);
      _loadData();
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
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  label: Text('New Product', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  onPressed: _showAddProductModal,
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
                  _buildTypeTab('normal', '📦 Normal Products'),
                  const SizedBox(width: 8),
                  _buildTypeTab('modifier', '✨ Modifiers & Add-ons'),
                  const SizedBox(width: 8),
                  _buildTypeTab('combo', '🎁 Combo Bundles'),
                  const SizedBox(width: 16),
                  Container(height: 24, width: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 16),
                  _buildCategoryChip(null, 'All Categories'),
                  ..._categories.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildCategoryChip(c.id, c.name),
                      )),
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
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                onPressed: () => _deleteProduct(prod),
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

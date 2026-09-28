import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await ApiService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  void _showAddEditCategoryModal({CategoryModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final sortCtrl = TextEditingController(text: existing != null ? existing.sortOrder.toString() : '1');
    String selectedIcon = existing?.icon ?? 'category';

    final iconOptions = [
      {'name': 'category', 'icon': Icons.category},
      {'name': 'medical_services', 'icon': Icons.medical_services},
      {'name': 'content_cut', 'icon': Icons.content_cut},
      {'name': 'hotel', 'icon': Icons.hotel},
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'local_bar', 'icon': Icons.local_bar},
      {'name': 'meeting_room', 'icon': Icons.meeting_room},
      {'name': 'shopping_bag', 'icon': Icons.shopping_bag},
      {'name': 'fitness_center', 'icon': Icons.fitness_center},
      {'name': 'spa', 'icon': Icons.spa},
      {'name': 'pets', 'icon': Icons.pets},
      {'name': 'more_horiz', 'icon': Icons.more_horiz},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Create Category' : 'Edit Category',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supports any industry domain: Food, Service, Drinks, Meeting Hall, Room, Hotel, etc.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g. Meeting Hall, Spa, Food, Room, Clinic...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief category overview or notes',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Display Sort Order',
                    hintText: '1, 2, 3...',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Select Icon:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconOptions.map((opt) {
                    final isSel = selectedIcon == opt['name'];
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setModalState(() => selectedIcon = opt['name'] as String),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryContainer.withValues(alpha: 0.2) : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          size: 20,
                          color: isSel ? AppTheme.primary : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ApiService.createCategory({
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'icon': selectedIcon,
                  'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                });
                _loadCategories();
              },
              child: Text(existing == null ? 'Create Category' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(CategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to remove "${cat.name}"? Products in this category will remain available.'),
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

    if (confirm == true) {
      await ApiService.deleteCategory(cat.id);
      _loadCategories();
    }
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'medical_services':
        return Icons.medical_services;
      case 'content_cut':
        return Icons.content_cut;
      case 'hotel':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_bar':
        return Icons.local_bar;
      case 'meeting_room':
        return Icons.meeting_room;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'spa':
        return Icons.spa;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.category;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Category Architecture',
                      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                    ),
                    Text(
                      'Organize any inventory or appointment domain: Food, Service, Drinks, Meeting Hall, Room, and more.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('New Category', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditCategoryModal(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _categories.isEmpty
                      ? const Center(child: Text('No categories created yet.'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 150,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
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
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(_resolveIcon(cat.icon), color: AppTheme.primary, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Order #${cat.sortOrder}',
                                              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                        onPressed: () => _deleteCategory(cat),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    cat.description.isNotEmpty ? cat.description : 'No description provided.',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

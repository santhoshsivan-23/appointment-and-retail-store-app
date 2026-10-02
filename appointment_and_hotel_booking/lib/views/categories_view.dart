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
    final String selectedIcon = existing?.icon ?? 'category';
    bool showInAppointment = existing?.showInAppointment ?? true;

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
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure category details and manage visibility in the appointment booking flow.',
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

                  // Show in Appointment toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Show in Appointment',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enable to show this category and its products in Book New Appointment popup.',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: showInAppointment,
                          activeThumbColor: const Color(0xFFE11D48),
                          onChanged: (val) => setModalState(() => showInAppointment = val),
                        ),
                      ],
                    ),
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
                final data = {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'icon': selectedIcon,
                  'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                  'show_in_appointment': showInAppointment,
                };
                if (existing == null) {
                  await ApiService.createCategory(data);
                } else {
                  await ApiService.updateCategory(existing.id, data);
                }
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
                      'Organize inventory and manage which categories and products appear in appointment booking.',
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
                            maxCrossAxisExtent: 380,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 180,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            return Container(
                              padding: const EdgeInsets.all(16),
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
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(_resolveIcon(cat.icon), color: AppTheme.primary, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Order #${cat.sortOrder}',
                                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                        tooltip: 'Edit Category',
                                        onPressed: () => _showAddEditCategoryModal(existing: cat),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                        tooltip: 'Delete Category',
                                        onPressed: () => _deleteCategory(cat),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat.description.isNotEmpty ? cat.description : 'No description provided.',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Divider(height: 12, color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            cat.showInAppointment ? Icons.event_available : Icons.event_busy,
                                            size: 15,
                                            color: cat.showInAppointment ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            cat.showInAppointment ? 'Show in Appointment' : 'Hidden in Appointment',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: cat.showInAppointment ? const Color(0xFF047857) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: cat.showInAppointment,
                                          activeThumbColor: const Color(0xFF10B981),
                                          onChanged: (val) async {
                                            setState(() {
                                              final i = _categories.indexWhere((c) => c.id == cat.id);
                                              if (i != -1) {
                                                _categories[i] = CategoryModel(
                                                  id: cat.id,
                                                  businessId: cat.businessId,
                                                  name: cat.name,
                                                  description: cat.description,
                                                  icon: cat.icon,
                                                  sortOrder: cat.sortOrder,
                                                  showInAppointment: val,
                                                  isActive: cat.isActive,
                                                  createdAt: cat.createdAt,
                                                );
                                              }
                                            });
                                            await ApiService.updateCategory(cat.id, {'show_in_appointment': val});
                                          },
                                        ),
                                      ),
                                    ],
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

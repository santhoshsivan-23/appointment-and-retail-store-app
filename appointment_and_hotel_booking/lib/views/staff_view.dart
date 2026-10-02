import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/staff_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/staff_avatar.dart';

class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  List<StaffModel> _staffList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getStaff(search: _searchQuery);
    if (!mounted) return;
    setState(() {
      _staffList = list;
      _isLoading = false;
    });
  }

  void _showStaffDetailsPopup(StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            StaffAvatar(
              staff: staff,
              radius: 22,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              textColor: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    staff.role,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            _buildInfoRow(Icons.email_outlined, 'Email', staff.email.isNotEmpty ? staff.email : 'None recorded'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone_outlined, 'Phone', staff.phone.isNotEmpty ? staff.phone : 'None recorded'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.badge_outlined, 'Staff ID', '#STF-00${staff.id}'),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Scheduling Status',
              staff.isActive ? 'Active for Bookings' : 'Deactivated (Historical Record)',
              valueColor: staff.isActive ? AppTheme.tertiaryContainer : AppTheme.onSurfaceVariant,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Staff'),
            onPressed: () {
              Navigator.pop(ctx);
              _showEditStaffModal(staff);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Staff'),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirmation(staff);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Staff Member?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'Are you sure you want to delete ',
                children: [
                  TextSpan(
                    text: '${staff.name} (${staff.role})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu, size: 20, color: AppTheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Historical appointments will preserve ${staff.name}\'s name for past logs. They will no longer appear in active booking slots.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.deleteStaff(staff.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Staff member ${staff.name} deleted & archived.'),
                      backgroundColor: AppTheme.tertiary,
                    ),
                  );
                  _loadStaff();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete staff member.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Deletion'),
          ),
        ],
      ),
    );
  }

  void _showEditStaffModal(StaffModel staff) {
    final nameCtrl = TextEditingController(text: staff.name);
    final emailCtrl = TextEditingController(text: staff.email);
    final phoneCtrl = TextEditingController(text: staff.phone);
    final roleCtrl = TextEditingController(text: staff.role);
    bool isActive = staff.isActive;
    String? selectedImageBase64 = staff.image;
    Uint8List? previewBytes;
    bool isPicking = false;
    bool isSaving = false;
    bool imageChanged = false;

    if (staff.image != null && staff.image!.trim().isNotEmpty) {
      try {
        final imgStr = staff.image!.trim();
        if (imgStr.startsWith('data:image')) {
          final commaIdx = imgStr.indexOf(',');
          final rawB64 = commaIdx != -1 ? imgStr.substring(commaIdx + 1) : imgStr;
          previewBytes = base64Decode(rawB64);
        } else if (!imgStr.startsWith('http')) {
          previewBytes = base64Decode(imgStr);
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage() async {
            try {
              setDialogState(() => isPicking = true);
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 85,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                final ext = file.name.split('.').last.toLowerCase();
                final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                final b64 = 'data:$mime;base64,${base64Encode(bytes)}';
                setDialogState(() {
                  previewBytes = bytes;
                  selectedImageBase64 = b64;
                  imageChanged = true;
                  isPicking = false;
                });
              } else {
                setDialogState(() => isPicking = false);
              }
            } catch (e) {
              debugPrint('Error picking staff image: $e');
              setDialogState(() => isPicking = false);
            }
          }

          final hasImage = previewBytes != null ||
              (selectedImageBase64 != null &&
                  selectedImageBase64!.trim().isNotEmpty &&
                  (selectedImageBase64!.startsWith('http://') || selectedImageBase64!.startsWith('https://')));

          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Staff Member',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile image upload / edit section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: pickImage,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primary.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: previewBytes != null
                                        ? Image.memory(previewBytes!, width: 84, height: 84, fit: BoxFit.cover)
                                        : (selectedImageBase64 != null &&
                                                (selectedImageBase64!.startsWith('http://') ||
                                                    selectedImageBase64!.startsWith('https://'))
                                            ? Image.network(
                                                selectedImageBase64!,
                                                width: 84,
                                                height: 84,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: AppTheme.primary,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    nameCtrl.text.trim().isNotEmpty
                                                        ? nameCtrl.text.trim()[0].toUpperCase()
                                                        : '?',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.white,
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (nameCtrl.text.trim().isNotEmpty
                                                ? Container(
                                                    color: AppTheme.primary,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      nameCtrl.text.trim()[0].toUpperCase(),
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: Colors.white,
                                                        fontSize: 32,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                : Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.add_a_photo_outlined,
                                                        size: 28,
                                                        color: AppTheme.onSurfaceVariant,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Add Photo',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ))),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: Icon(
                                  hasImage ? Icons.photo_library_outlined : Icons.upload_outlined,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                                label: Text(
                                  hasImage ? 'Change Photo' : 'Upload Profile Image',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                onPressed: isPicking ? null : pickImage,
                              ),
                              if (hasImage) ...[
                                const SizedBox(width: 4),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    'Remove',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      previewBytes = null;
                                      selectedImageBase64 = '';
                                      imageChanged = true;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Dr. Maya Lin'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(labelText: 'Staff Role / Specialization *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Phone', hintText: '+1 555-0100'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address', hintText: 'maya@omopet.clinic'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Active for Bookings',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'Staff is visible and selectable for bookings'
                              : 'Staff is archived from active bookings',
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                        ),
                        value: isActive,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) => setDialogState(() => isActive = val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setDialogState(() => isSaving = true);

                        final staffPayload = <String, dynamic>{
                          'name': nameCtrl.text.trim(),
                          'role': roleCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'is_active': isActive,
                        };
                        if (imageChanged) {
                          staffPayload['image'] = selectedImageBase64 ?? '';
                        } else {
                          staffPayload['image'] = staff.image ?? '';
                        }

                        final success = await ApiService.updateStaff(staff.id, staffPayload);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Staff member "${nameCtrl.text.trim()}" updated successfully.'),
                                backgroundColor: AppTheme.tertiary,
                              ),
                            );
                            _loadStaff();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update staff member.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddStaffModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Stylist / Clinician');
    String? selectedImageBase64;
    Uint8List? previewBytes;
    bool isPicking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage() async {
            try {
              setDialogState(() => isPicking = true);
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 85,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                final ext = file.name.split('.').last.toLowerCase();
                final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                final b64 = 'data:$mime;base64,${base64Encode(bytes)}';
                setDialogState(() {
                  previewBytes = bytes;
                  selectedImageBase64 = b64;
                  isPicking = false;
                });
              } else {
                setDialogState(() => isPicking = false);
              }
            } catch (e) {
              debugPrint('Error picking staff image: $e');
              setDialogState(() => isPicking = false);
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Add New Staff Member',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile image upload section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: pickImage,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: previewBytes != null
                                        ? Image.memory(previewBytes!, width: 84, height: 84, fit: BoxFit.cover)
                                        : (nameCtrl.text.trim().isNotEmpty
                                            ? Container(
                                                color: AppTheme.primary,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  nameCtrl.text.trim()[0].toUpperCase(),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_a_photo_outlined,
                                                    size: 28,
                                                    color: AppTheme.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Add Photo',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              )),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: Icon(
                                  previewBytes != null ? Icons.photo_library_outlined : Icons.upload_outlined,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                                label: Text(
                                  previewBytes != null ? 'Change Photo' : 'Upload Profile Image',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                                onPressed: isPicking ? null : pickImage,
                              ),
                              if (previewBytes != null) ...[
                                const SizedBox(width: 4),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    'Remove',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      previewBytes = null;
                                      selectedImageBase64 = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Dr. Maya Lin'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(labelText: 'Staff Role / Specialization *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Phone', hintText: '+1 555-0100'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address', hintText: 'maya@omopet.clinic'),
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
                  final staffPayload = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                  };
                  if (selectedImageBase64 != null && selectedImageBase64!.isNotEmpty) {
                    staffPayload['image'] = selectedImageBase64;
                  }
                  await ApiService.createStaff(staffPayload);
                  _loadStaff();
                },
                child: const Text('Create Staff'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
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
            // Top Controls Bar
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
                              _loadStaff();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search staff by name, role, email, phone...',
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _loadStaff();
                            },
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
                    minimumSize: const Size(140, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text('Add Staff', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  onPressed: _showAddStaffModal,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _staffList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 54, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No staff members found',
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click "+ Add Staff" to onboard team clinicians & staff.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 180,
                          ),
                          itemCount: _staffList.length,
                          itemBuilder: (context, idx) {
                            final staff = _staffList[idx];
                            return _buildStaffCard(staff);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffModel staff) {
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
              StaffAvatar(
                staff: staff,
                radius: 22,
                backgroundColor: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      staff.role,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: staff.isActive ? AppTheme.tertiaryContainer.withValues(alpha: 0.15) : AppTheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  staff.isActive ? 'Active' : 'Archived',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: staff.isActive ? AppTheme.tertiary : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '📞 ${staff.phone.isNotEmpty ? staff.phone : "No phone"}',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
          ),
          Text(
            '✉️ ${staff.email.isNotEmpty ? staff.email : "No email"}',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Details'),
                onPressed: () => _showStaffDetailsPopup(staff),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                onPressed: () => _showEditStaffModal(staff),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                tooltip: 'Delete Staff',
                onPressed: () => _showDeleteConfirmation(staff),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

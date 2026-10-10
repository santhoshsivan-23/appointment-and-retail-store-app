import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/customer_model.dart';
import '../../models/staff_model.dart';
import '../../services/api_service.dart';
import '../../theme/appointment_v2_theme.dart';
import '../../utils/appointment_v2_utils.dart';

/// Top Navigation Header for Appointment V2 (Permanently Fixed in Top)
/// Matches React AppointmentV2Header.tsx
class AppointmentV2Header extends StatefulWidget {
  final StaffModel selectedStaff;
  final String selectedDate;
  final String viewMode; // 'list', 'grid', 'time'
  final bool isLoadingAppts;
  final VoidCallback onSwitchStaff;
  final ValueChanged<String> onViewModeChange;
  final VoidCallback onOpenFilterModal;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAddModal;
  final ValueChanged<CustomerModel> onSelectCustomerToBook;

  const AppointmentV2Header({
    super.key,
    required this.selectedStaff,
    required this.selectedDate,
    required this.viewMode,
    required this.isLoadingAppts,
    required this.onSwitchStaff,
    required this.onViewModeChange,
    required this.onOpenFilterModal,
    required this.onRefresh,
    required this.onOpenAddModal,
    required this.onSelectCustomerToBook,
  });

  @override
  State<AppointmentV2Header> createState() => _AppointmentV2HeaderState();
}

class _AppointmentV2HeaderState extends State<AppointmentV2Header> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCustomerController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();

  OverlayEntry? _dropdownOverlayEntry;
  Timer? _debounceTimer;
  List<CustomerModel> _customerResults = [];
  bool _isSearchingCustomers = false;

  late AnimationController _spinAnimController;

  @override
  void initState() {
    super.initState();
    _spinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _searchCustomerController.addListener(_onSearchQueryChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant AppointmentV2Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoadingAppts && !_spinAnimController.isAnimating) {
      _spinAnimController.repeat();
    } else if (!widget.isLoadingAppts && _spinAnimController.isAnimating) {
      _spinAnimController.stop();
      _spinAnimController.reset();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeDropdownOverlay();
    _searchCustomerController.dispose();
    _searchFocusNode.dispose();
    _spinAnimController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchCustomerController.text.trim().isNotEmpty) {
      _showDropdownOverlay();
    } else if (!_searchFocusNode.hasFocus) {
      // Delay closing so taps inside dropdown register
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          _removeDropdownOverlay();
        }
      });
    }
  }

  void _onSearchQueryChanged() {
    final query = _searchCustomerController.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _customerResults = [];
        _isSearchingCustomers = false;
      });
      _removeDropdownOverlay();
      return;
    }

    setState(() {
      _isSearchingCustomers = true;
    });
    _showDropdownOverlay();

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ApiService.getCustomers(search: query);
        if (mounted) {
          setState(() {
            _customerResults = results;
            _isSearchingCustomers = false;
          });
          _updateDropdownOverlay();
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _customerResults = [];
            _isSearchingCustomers = false;
          });
          _updateDropdownOverlay();
        }
      }
    });
  }

  void _showDropdownOverlay() {
    if (_dropdownOverlayEntry != null) {
      _dropdownOverlayEntry!.markNeedsBuild();
      return;
    }

    _dropdownOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss tap barrier
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _searchFocusNode.unfocus();
                _removeDropdownOverlay();
              },
            ),
          ),
          Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _searchLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                shadowColor: Colors.black26,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _buildSearchDropdownContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_dropdownOverlayEntry!);
  }

  void _updateDropdownOverlay() {
    _dropdownOverlayEntry?.markNeedsBuild();
  }

  void _removeDropdownOverlay() {
    _dropdownOverlayEntry?.remove();
    _dropdownOverlayEntry = null;
  }

  Widget _buildSearchDropdownContent() {
    final query = _searchCustomerController.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dropdown Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customers (${_customerResults.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Click to book',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body: Loading / Empty / List
        if (_isSearchingCustomers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB))),
                ),
                const SizedBox(width: 8),
                Text(
                  'Searching database...',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else if (_customerResults.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text(
              'No customers found for "$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _customerResults.length,
              separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final customer = _customerResults[index];
                final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C';

                return InkWell(
                  onTap: () {
                    widget.onSelectCustomerToBook(customer);
                    _searchCustomerController.clear();
                    _searchFocusNode.unfocus();
                    _removeDropdownOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDBEAFE),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 10, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.phone.isNotEmpty ? customer.phone : 'No phone',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            'Book',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'ST';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.selectedDate == getTodayDateStr();
    final staffBg = AppointmentV2Theme.getStaffColor(0, widget.selectedStaff.colorCode);
    final initials = _getInitials(widget.selectedStaff.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCD8CFE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D064E3B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1180;
          final rightItems = [
            _buildViewModeToggle(),
            _buildSlotFilterButton(),
            _buildRefreshButton(),
            _buildCustomerSearchBox(),
            _buildAddButton(),
          ];

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLeftGroup(staffBg, initials, isToday),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: rightItems,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLeftGroup(staffBg, initials, isToday),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: rightItems,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeftGroup(Color staffBg, String initials, bool isToday) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 1. Staff Selector Chip
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: staffBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.selectedStaff.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onSwitchStaff,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Switch Staff',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Date Display Pill
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                formatDatePretty(widget.selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Today',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeBtn(
            mode: 'list',
            label: 'List',
            icon: Icons.view_agenda_outlined,
            activeColor: const Color(0xFFE11D48),
            activeBg: const Color(0xFFFFF1F2),
          ),
          const SizedBox(width: 3),
          _buildViewModeBtn(
            mode: 'grid',
            label: 'Grid',
            icon: Icons.grid_view_rounded,
            activeColor: const Color(0xFF059669),
            activeBg: const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 3),
          _buildViewModeBtn(
            mode: 'time',
            label: 'Time',
            icon: Icons.access_time_rounded,
            activeColor: const Color(0xFF2563EB),
            activeBg: const Color(0xFFEFF6FF),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotFilterButton() {
    return OutlinedButton.icon(
      onPressed: widget.onOpenFilterModal,
      icon: const Icon(Icons.filter_alt_outlined, size: 14, color: Color(0xFF64748B)),
      label: Text(
        'Slot Filter',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return InkWell(
      onTap: widget.isLoadingAppts ? null : widget.onRefresh,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: RotationTransition(
          turns: _spinAnimController,
          child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildCustomerSearchBox() {
    return CompositedTransformTarget(
      link: _searchLayerLink,
      child: Container(
        width: 230,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCustomerController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search customer to book...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchCustomerController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCustomerController.clear();
                  _removeDropdownOverlay();
                },
                child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: widget.onOpenAddModal,
      icon: const Icon(Icons.add, size: 16),
      label: Text(
        'Add Appointment',
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _buildViewModeBtn({
    required String mode,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = widget.viewMode == mode;

    return InkWell(
      onTap: () => widget.onViewModeChange(mode),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
              ),
            ),
            const SizedBox(width: 5),
            Icon(icon, size: 13, color: activeColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

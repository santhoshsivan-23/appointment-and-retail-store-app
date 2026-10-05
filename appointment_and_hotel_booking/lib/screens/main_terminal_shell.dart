import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/appointment_model.dart';
import '../models/business_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
import '../views/appointment_config_view.dart';
import '../views/appointment_history_view.dart';
import '../views/appointment_view.dart';
import '../views/cart_view.dart';
import '../views/categories_view.dart';
import '../views/dashboard_view.dart';
import '../views/products_view.dart';
import '../views/sales_history_view.dart';
import '../views/settings_view.dart';
import '../views/staff_view.dart';
import 'login_screen.dart';

class MainTerminalShell extends StatefulWidget {
  final BusinessModel business;

  const MainTerminalShell({super.key, required this.business});

  @override
  State<MainTerminalShell> createState() => _MainTerminalShellState();
}

class _MainTerminalShellState extends State<MainTerminalShell> {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;

  // Display Settings: Header & Footer visibility, Android fullscreen
  bool _hideHeader = false;
  bool _hideFooter = false;
  bool _isFullscreen = false;

  // Cart preloading from Appointment "Start Service"
  CustomerModel? _preloadCustomer;
  List<ProductModel> _preloadProducts = [];
  int? _preloadAppointmentId;
  String? _preloadStaffName;
  int _cartKey = 0; // Force CartView rebuild when preloading
  int _appointmentKey = 1; // Force AppointmentView reload on navigation
  int _staffKey = 1; // Force StaffView reload on navigation
  int _appointmentHistoryKey = 1; // Force AppointmentHistoryView reload on navigation
  int _salesHistoryKey = 1; // Force SalesHistoryView reload on navigation

  // Live system clock and time format
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  String _timeFormat = '12';

  @override
  void initState() {
    super.initState();
    _loadDisplayPreferences();
    _loadTimeFormat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTimeFormat() async {
    final fmt = await AuthStorage.getTimeFormat();
    if (!mounted) return;
    setState(() {
      _timeFormat = fmt;
    });
  }

  String _formatHeaderTime(DateTime now) {
    final s = now.second.toString().padLeft(2, '0');
    if (_timeFormat == '24') {
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } else {
      final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
      final h = hour12.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      final ampm = now.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m:$s $ampm';
    }
  }

  String _formatHeaderDate(DateTime now) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    return '$weekday, $day $month';
  }

  Future<void> _loadDisplayPreferences() async {
    final hideH = await AuthStorage.getHideHeader();
    final hideF = await AuthStorage.getHideFooter();
    final isFull = await AuthStorage.getIsFullscreen();
    if (!mounted) return;
    setState(() {
      _hideHeader = hideH;
      _hideFooter = hideF;
      _isFullscreen = isFull;
    });
    if (isFull) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _toggleHeader(bool val) {
    setState(() => _hideHeader = val);
    AuthStorage.setHideHeader(val);
  }

  void _toggleFooter(bool val) {
    setState(() => _hideFooter = val);
    AuthStorage.setHideFooter(val);
  }

  void _toggleFullscreen(bool val) {
    setState(() => _isFullscreen = val);
    AuthStorage.setIsFullscreen(val);
    if (val) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _navigateToTab(int idx) {
    setState(() {
      // If user leaves Cart/service workflow without completing transaction:
      // Clear temporary appointment cart data so stale products from the previous session do not appear.
      if (_currentIndex == 4 && idx != 4) {
        _preloadCustomer = null;
        _preloadProducts = [];
        _preloadAppointmentId = null;
        _preloadStaffName = null;
        _cartKey++;
      }
      if (idx == 1) _appointmentKey++;
      if (idx == 2) _staffKey++;
      if (idx == 3) _appointmentHistoryKey++;
      if (idx == 5) _salesHistoryKey++;
      _currentIndex = idx;
    });
    _loadTimeFormat();
  }

  final List<Map<String, dynamic>> _navItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard},
    {'title': 'Appointment', 'icon': Icons.calendar_month_outlined, 'activeIcon': Icons.calendar_month},
    {'title': 'Staff', 'icon': Icons.people_alt_outlined, 'activeIcon': Icons.people_alt},
    {'title': 'Appointment History', 'icon': Icons.history_edu_outlined, 'activeIcon': Icons.history_edu},
    {'title': 'Cart & POS', 'icon': Icons.shopping_cart_outlined, 'activeIcon': Icons.shopping_cart},
    {'title': 'Sales History', 'icon': Icons.receipt_long_outlined, 'activeIcon': Icons.receipt_long},
    {'title': 'Categories', 'icon': Icons.category_outlined, 'activeIcon': Icons.category},
    {'title': 'Products', 'icon': Icons.inventory_2_outlined, 'activeIcon': Icons.inventory_2},
    {'title': 'Appointment Config', 'icon': Icons.tune_outlined, 'activeIcon': Icons.tune},
    {'title': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings},
  ];

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out Terminal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out of ${widget.business.businessName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(context);
              await AuthStorage.clearAuth();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // 1. Fixed Top Header (Hidden on demand via Settings)
          if (!_hideHeader) _buildFixedHeader(),

          // 2. Main Row: Collapsible Sidebar + Content Viewport
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                _buildCollapsibleSidebar(),

                // Content Viewport (IndexedStack preserves state of all tabs!)
                Expanded(
                  child: Container(
                    color: AppTheme.surface,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        DashboardView(
                          business: widget.business,
                          onNavigate: (idx) => _navigateToTab(idx),
                        ),
                        AppointmentView(
                          key: ValueKey('appointment_$_appointmentKey'),
                          onStartService: (customer, products, {AppointmentModel? appointment}) {
                            setState(() {
                              _preloadCustomer = customer;
                              _preloadProducts = products;
                              _preloadAppointmentId = appointment?.id;
                              _preloadStaffName = appointment?.staffName;
                              _cartKey++;
                              _currentIndex = 4; // Switch to Cart tab
                            });
                          },
                        ),
                        StaffView(
                          key: ValueKey('staff_$_staffKey'),
                        ),
                        AppointmentHistoryView(
                          key: ValueKey('apt_hist_$_appointmentHistoryKey'),
                        ),
                        CartView(
                          key: ValueKey('cart_$_cartKey'),
                          preloadCustomer: _preloadCustomer,
                          preloadProducts: _preloadProducts,
                          preloadAppointmentId: _preloadAppointmentId,
                          preloadStaffName: _preloadStaffName,
                          onNavigateToSalesHistory: () => _navigateToTab(5),
                        ),
                        SalesHistoryView(
                          key: ValueKey('sales_hist_$_salesHistoryKey'),
                        ),
                        const CategoriesView(),
                        const ProductsView(),
                        const AppointmentConfigView(),
                        SettingsView(
                          business: widget.business,
                          hideHeader: _hideHeader,
                          hideFooter: _hideFooter,
                          isFullscreen: _isFullscreen,
                          onToggleHeader: _toggleHeader,
                          onToggleFooter: _toggleFooter,
                          onToggleFullscreen: _toggleFullscreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Status Footer Bar removed per requirements (Station and Display Settings no longer shown in footer)
        ],
      ),
    );
  }

  // Fixed Header Component
  // Fixed Header Component with IQ App Logo, Curved Border Styling, System Time, and User Info Card
  Widget _buildFixedHeader() {
    final themeColor = Theme.of(context).primaryColor;
    final businessName = widget.business.businessName.trim().isNotEmpty
        ? widget.business.businessName.trim()
        : (widget.business.ownerName.trim().isNotEmpty
            ? widget.business.ownerName.trim()
            : 'IQ Store');

    return Container(
      height: 60,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Corner: IQ App Logo + IQ Store Title
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      'IQ',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IQ Store',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'GROOMING & CLINICAL SUITE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Corner: Time & Date + Gray Carded User Info + Sign Out
          Row(
            children: [
              // System Time & Date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: themeColor),
                    const SizedBox(width: 8),
                    Text(
                      _formatHeaderTime(_currentTime),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(height: 12, width: 1, color: themeColor.withValues(alpha: 0.3)),
                    const SizedBox(width: 10),
                    Text(
                      _formatHeaderDate(_currentTime),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // User Information Card: Displays Business Name on the right side of User Icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // mild/light-gray background
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      businessName,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Sign Out Terminal
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.primary, size: 20),
                tooltip: 'Sign Out Terminal',
                onPressed: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Collapsible Sidebar Component
  Widget _buildCollapsibleSidebar() {
    final double width = _isSidebarExpanded ? 240 : 72;
    final themeColor = Theme.of(context).primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top section of Sidebar with View Toggle
          if (_hideHeader) ...[
            _buildSidebarTopWhenHeaderHidden(themeColor),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ] else ...[
            _buildSidebarTopBar(themeColor),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],

          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: _navItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final item = _navItems[idx];
                final isSelected = _currentIndex == idx;

                if (!_isSidebarExpanded) {
                  // Collapsed Rail Item with Tooltip: White card container / Active light theme card
                  return Tooltip(
                    message: item['title'] as String,
                    preferBelow: false,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _navigateToTab(idx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected ? themeColor.withValues(alpha: 0.10) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? themeColor : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? themeColor.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                            color: isSelected ? themeColor : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Expanded Item: White button/card-style container
                // Active option: light background using theme colour, theme border, black text for clear readability
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _navigateToTab(idx),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColor.withValues(alpha: 0.10) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? themeColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? themeColor.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                          color: isSelected ? themeColor : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.black : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Top header bar of the sidebar containing the View Toggle
  Widget _buildSidebarTopBar(Color themeColor) {
    if (!_isSidebarExpanded) {
      // Grid view active (collapsed): Show only the List icon button so user can switch back
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Tooltip(
          message: 'Switch to List View',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _isSidebarExpanded = true);
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.view_list_rounded,
                  color: themeColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // List view active (expanded): Display Grid and List view options on the right side,
    // each occupying 50% width of the available area, with height 46 (same as sidebar button).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'MENU',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ),
          _buildSidebarViewToggle(themeColor),
        ],
      ),
    );
  }

  // Segmented view toggle control: height 46 (same as sidebar option buttons),
  // Grid and List options each occupying 50% width of the control.
  Widget _buildSidebarViewToggle(Color themeColor) {
    return Container(
      width: 104,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Grid view button (occupies 50% width)
          Expanded(
            child: Tooltip(
              message: 'Grid View (Icons Only)',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                onTap: () {
                  if (_isSidebarExpanded) {
                    setState(() => _isSidebarExpanded = false);
                  }
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: !_isSidebarExpanded ? themeColor.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: !_isSidebarExpanded ? themeColor : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Subtle vertical divider between the two options
          Container(
            width: 1,
            height: 22,
            color: const Color(0xFFE2E8F0),
          ),

          // Right: List view button (occupies 50% width)
          Expanded(
            child: Tooltip(
              message: 'List View (Icons + Labels)',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                onTap: () {
                  if (!_isSidebarExpanded) {
                    setState(() => _isSidebarExpanded = true);
                  }
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isSidebarExpanded ? themeColor.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.view_list_rounded,
                      size: 22,
                      color: _isSidebarExpanded ? themeColor : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact sidebar top header when the fixed top header is hidden
  Widget _buildSidebarTopWhenHeaderHidden(Color themeColor) {
    if (!_isSidebarExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.primary,
                  alignment: Alignment.center,
                  child: Text(
                    'IQ',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Switch to List View',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _isSidebarExpanded = true);
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.view_list_rounded,
                      color: themeColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      'IQ',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IQ Store',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          _buildSidebarViewToggle(themeColor),
        ],
      ),
    );
  }
}

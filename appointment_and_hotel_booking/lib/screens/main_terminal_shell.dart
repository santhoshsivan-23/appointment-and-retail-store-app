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
  int _appointmentHistoryKey = 1; // Force AppointmentHistoryView reload on navigation
  int _salesHistoryKey = 1; // Force SalesHistoryView reload on navigation

  @override
  void initState() {
    super.initState();
    _loadDisplayPreferences();
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
      if (idx == 3) _appointmentHistoryKey++;
      if (idx == 5) _salesHistoryKey++;
      _currentIndex = idx;
    });
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
                        const StaffView(),
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

          // 3. Status Footer Bar (Hidden on demand via Settings)
          if (!_hideFooter) _buildFooterBar(),
        ],
      ),
    );
  }

  // Fixed Header Component
  Widget _buildFixedHeader() {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Sidebar Toggle + Brand Identity
          Row(
            children: [
              // Expand/Collapse Sidebar Toggle Button
              IconButton(
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 250),
                  turns: _isSidebarExpanded ? 0 : 0.5,
                  child: Icon(
                    _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                    color: AppTheme.onSurface,
                  ),
                ),
                tooltip: _isSidebarExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                onPressed: () {
                  setState(() {
                    _isSidebarExpanded = !_isSidebarExpanded;
                  });
                },
              ),
              const SizedBox(width: 8),

              // Brand Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),

              // Brand Name
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

          // Center: Station Indicator & Active Business Name Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Station #01 Online',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(height: 12, width: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 12),
                    Text(
                      widget.business.businessName.isNotEmpty ? widget.business.businessName : 'Grand Horizon Clinic',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right: Sign Out button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.primary, size: 22),
            tooltip: 'Sign Out Terminal',
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  // Collapsible Sidebar Component
  Widget _buildCollapsibleSidebar() {
    final double width = _isSidebarExpanded ? 240 : 72;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // If the top header is hidden, display compact top brand/toggle in sidebar
          if (_hideHeader) ...[
            _buildSidebarTopWhenHeaderHidden(),
            const Divider(height: 1),
          ],

          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: _navItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = _navItems[idx];
                final isSelected = _currentIndex == idx;

                if (!_isSidebarExpanded) {
                  // Collapsed Rail Item with Tooltip
                  return Tooltip(
                    message: item['title'] as String,
                    preferBelow: false,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _navigateToTab(idx),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryContainer.withValues(alpha: 0.14) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                            color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Expanded Item
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _navigateToTab(idx),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryContainer.withValues(alpha: 0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                          color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
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

          // Sidebar Footer Toggle Hint
          const Divider(height: 1),
          InkWell(
            onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                children: [
                  if (_isSidebarExpanded)
                    Text(
                      'Collapse Navigation',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                    ),
                  Icon(
                    _isSidebarExpanded ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_right,
                    size: 18,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact sidebar top header when the fixed top header is hidden
  Widget _buildSidebarTopWhenHeaderHidden() {
    if (!_isSidebarExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            IconButton(
              icon: const Icon(Icons.menu, size: 20),
              tooltip: 'Expand Sidebar',
              onPressed: () => setState(() => _isSidebarExpanded = true),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'IQ Store',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    'CLINICAL SUITE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu_open, size: 20),
            tooltip: 'Collapse Sidebar',
            onPressed: () => setState(() => _isSidebarExpanded = false),
          ),
        ],
      ),
    );
  }

  // Bottom Status Footer Bar
  Widget _buildFooterBar() {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: POS Station & Business Info
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Station #01 Online',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Text('•', style: TextStyle(color: AppTheme.outlineVariant, fontSize: 10)),
              const SizedBox(width: 10),
              Text(
                widget.business.businessName.isNotEmpty ? widget.business.businessName : 'Grand Horizon Clinic',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),

          // Right: Status Badges & Quick Settings Link
          Row(
            children: [
              if (_hideHeader)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_off, size: 10, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Header Hidden',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: () => _navigateToTab(9),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 13, color: _currentIndex == 9 ? AppTheme.primary : AppTheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Display Settings',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _currentIndex == 9 ? FontWeight.bold : FontWeight.w500,
                          color: _currentIndex == 9 ? AppTheme.primary : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

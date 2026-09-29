import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constant.dart';
import '../models/business_model.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';

class SettingsView extends StatefulWidget {
  final BusinessModel business;
  final bool hideHeader;
  final bool hideFooter;
  final bool isFullscreen;
  final ValueChanged<bool> onToggleHeader;
  final ValueChanged<bool> onToggleFooter;
  final ValueChanged<bool> onToggleFullscreen;

  const SettingsView({
    super.key,
    required this.business,
    required this.hideHeader,
    required this.hideFooter,
    required this.isFullscreen,
    required this.onToggleHeader,
    required this.onToggleFooter,
    required this.onToggleFullscreen,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _testingConnection = false;
  String? _testResult;
  bool _testSuccess = false;
  final _customUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomUrl();
  }

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomUrl() async {
    final current = await ApiService.getBaseUrl();
    _customUrlCtrl.text = current;
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final base = await ApiService.getBaseUrl();
      final healthUri = Uri.parse('$base/health');
      final res = await http.get(healthUri, headers: AppConstant.apiHeaders).timeout(const Duration(seconds: 8));
      stopwatch.stop();

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _testSuccess = true;
          _testResult = 'Connected successfully in ${stopwatch.elapsedMilliseconds}ms (${res.statusCode})';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Server returned HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testSuccess = false;
        _testResult = 'Connection failed: $e';
      });
    } finally {
      setState(() => _testingConnection = false);
    }
  }

  Future<void> _saveCustomUrl() async {
    final newUrl = _customUrlCtrl.text.trim();
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL')),
      );
      return;
    }
    await AuthStorage.setCustomBaseUrl(newUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text('API URL updated to: $newUrl'),
      ),
    );
  }

  Future<void> _resetDefaultUrl() async {
    final def = AppConstant.baseUrl.endsWith('/api') ? AppConstant.baseUrl : '${AppConstant.baseUrl}/api';
    _customUrlCtrl.text = def;
    await AuthStorage.setCustomBaseUrl(def);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF3B82F6),
        content: Text('Reset to default ngrok URL'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            _buildPageHeader(),
            const SizedBox(height: 24),

            // Layout & Display Controls Card
            _buildDisplaySettingsCard(),
            const SizedBox(height: 20),

            // Live Visual Screen Preview
            _buildVisualScreenPreview(),
            const SizedBox(height: 20),

            // Backend Connection Card
            _buildNetworkSettingsCard(),
            const SizedBox(height: 20),

            // Station & System Info Card
            _buildStationInfoCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: const Center(
            child: Icon(Icons.tune_rounded, color: AppTheme.primary, size: 26),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terminal & Display Settings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Configure Android screen visibility, hide header/footer, fullscreen & API endpoints',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisplaySettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.phone_android_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Android Screen & Layout Visibility',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                // Quick Action Buttons
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.visibility_off_outlined, size: 15),
                  label: Text('Hide Both', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    widget.onToggleHeader(true);
                    widget.onToggleFooter(true);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: Text('Show Both', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    widget.onToggleHeader(false);
                    widget.onToggleFooter(false);
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),

          // Option 1: Hide Header
          _settingSwitchTile(
            icon: Icons.vertical_align_top_rounded,
            iconColor: const Color(0xFFF43F5E),
            title: 'Hide Header',
            subtitle: 'Hide the fixed top header (IQ Store brand, station status & sign-out) to maximize vertical height on Android screens.',
            value: widget.hideHeader,
            onChanged: widget.onToggleHeader,
            statusBadge: widget.hideHeader ? 'HIDDEN' : 'VISIBLE',
            badgeBg: widget.hideHeader ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
            badgeColor: widget.hideHeader ? const Color(0xFFE11D48) : const Color(0xFF10B981),
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // Option 2: Hide Footer
          _settingSwitchTile(
            icon: Icons.vertical_align_bottom_rounded,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Hide Footer',
            subtitle: 'Hide the bottom terminal status bar for an uninterrupted full-height viewport on Android displays.',
            value: widget.hideFooter,
            onChanged: widget.onToggleFooter,
            statusBadge: widget.hideFooter ? 'HIDDEN' : 'VISIBLE',
            badgeBg: widget.hideFooter ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
            badgeColor: widget.hideFooter ? const Color(0xFFE11D48) : const Color(0xFF10B981),
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // Option 3: Immersive Fullscreen (Android System Bars)
          _settingSwitchTile(
            icon: Icons.fullscreen_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Immersive Fullscreen (Android System Bars)',
            subtitle: 'Hide the Android OS top status/notification bar and bottom navigation bar (Kiosk sticky mode).',
            value: widget.isFullscreen,
            onChanged: widget.onToggleFullscreen,
            statusBadge: widget.isFullscreen ? 'FULLSCREEN' : 'STANDARD',
            badgeBg: widget.isFullscreen ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
            badgeColor: widget.isFullscreen ? const Color(0xFF7C3AED) : const Color(0xFF475569),
          ),
        ],
      ),
    );
  }

  Widget _settingSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String statusBadge,
    required Color badgeBg,
    required Color badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        statusBadge,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualScreenPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Current Screen Layout Preview',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                'Live State',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mock Android Tablet Screen Frame
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B), width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Column(
                children: [
                  // Android System Bar
                  if (!widget.isFullscreen)
                    Container(
                      height: 16,
                      color: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('12:45', style: GoogleFonts.inter(fontSize: 8, color: Colors.white70)),
                          const Row(
                            children: [
                              Icon(Icons.wifi, size: 10, color: Colors.white70),
                              SizedBox(width: 4),
                              Icon(Icons.battery_full, size: 10, color: Colors.white70),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // App Header
                  if (!widget.hideHeader)
                    Container(
                      height: 24,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('IQ Store POS Header', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          const Spacer(),
                          Text('Station #01 Online', style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),

                  // Middle Content Area
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          // Sidebar
                          Container(
                            width: 44,
                            color: Colors.white,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Icon(Icons.dashboard_rounded, size: 11, color: Colors.grey.shade400),
                                const Icon(Icons.calendar_month_rounded, size: 11, color: AppTheme.primary),
                                Icon(Icons.shopping_cart_rounded, size: 11, color: Colors.grey.shade400),
                                Icon(Icons.settings_rounded, size: 11, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                          // Viewport
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.hideHeader && widget.hideFooter
                                        ? 'MAXIMIZED FULL-SCREEN VIEWPORT'
                                        : 'Content Viewport Area',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.hideHeader && widget.hideFooter ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${widget.hideHeader ? 'Header: Hidden' : 'Header: Visible'} • ${widget.hideFooter ? 'Footer: Hidden' : 'Footer: Visible'}',
                                    style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // App Footer
                  if (!widget.hideFooter)
                    Container(
                      height: 18,
                      color: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Terminal Synced • Ready', style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade600)),
                          Text('Footer Bar', style: GoogleFonts.inter(fontSize: 8, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),

                  // Android Nav Bar
                  if (!widget.isFullscreen)
                    Container(
                      height: 14,
                      color: const Color(0xFF1E293B),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(Icons.arrow_back, size: 8, color: Colors.white60),
                          Icon(Icons.circle_outlined, size: 8, color: Colors.white60),
                          Icon(Icons.crop_square, size: 8, color: Colors.white60),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, size: 20, color: Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              Text(
                'API & Cloud Server Connection',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Configure the backend endpoint URL used by Android to sync appointments, staff & sales:',
            style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),

          // URL Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customUrlCtrl,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.link, size: 18),
                    labelText: 'Backend Base URL',
                    hintText: 'https://couch-durably-mankind.ngrok-free.dev/api',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text('Save', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                onPressed: _saveCustomUrl,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: Text('Reset', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                onPressed: _resetDefaultUrl,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Test Button & Status
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _testingConnection
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: Text(
                  _testingConnection ? 'Testing...' : 'Test Connection',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _testingConnection ? null : _testApiConnection,
              ),
              if (_testResult != null) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _testSuccess ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _testSuccess ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF0F172A)),
              const SizedBox(width: 10),
              Text(
                'Active Terminal Information',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('Business Name', widget.business.businessName.isNotEmpty ? widget.business.businessName : 'Grand Horizon Clinic'),
          _infoRow('Business Email', widget.business.email.isNotEmpty ? widget.business.email : 'admin@clinic.com'),
          _infoRow('Terminal Station', 'Station #01 (Android POS)'),
          _infoRow('App Version', '1.0.0 (Release Build 2026.09)'),
          _infoRow('Target Platform', 'Android (ARM64 / x86_64)'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

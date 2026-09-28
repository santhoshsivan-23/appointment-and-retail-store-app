import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/business_model.dart';
import '../theme/app_theme.dart';

class DashboardView extends StatelessWidget {
  final BusinessModel? business;
  final Function(int) onNavigate;

  const DashboardView({super.key, this.business, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Welcome Banner with primary gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Terminal Station #01 • Live Operations',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          business?.businessName.isNotEmpty == true ? business!.businessName : 'IQ Unified Terminal',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manager: ${business?.ownerName.isNotEmpty == true ? business!.ownerName : "Dr. Shaun Ong"} • Category: ${business?.businessType.isNotEmpty == true ? business!.businessType : "Grooming & Clinical Suite"}',
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.point_of_sale, size: 18),
                    label: Text('Open Register / Cart', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    onPressed: () => onNavigate(4), // Navigate to Cart
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // KPI Summary Counters
            Row(
              children: [
                _buildKpiCard('Today\'s Appointments', '14', '4 in progress', Icons.calendar_today, AppTheme.primary),
                const SizedBox(width: 16),
                _buildKpiCard('Register Sales', '\$1,840.50', '26 orders tendered', Icons.receipt_long, AppTheme.secondary),
                const SizedBox(width: 16),
                _buildKpiCard('Active Clinicians', '3 On Duty', '100% capacity', Icons.people_outline, AppTheme.tertiary),
                const SizedBox(width: 16),
                _buildKpiCard('Suite Occupancy', '85%', '12 of 14 rooms filled', Icons.hotel, const Color(0xFFC05621)),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Navigation Shortcuts
            Text('Terminal Operations', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.4,
              children: [
                _buildActionTile(Icons.calendar_month, 'Appointments', 'Manage daily schedule', AppTheme.primary, () => onNavigate(1)),
                _buildActionTile(Icons.people, 'Staff Directory', 'Clinicians & groomers', AppTheme.secondary, () => onNavigate(2)),
                _buildActionTile(Icons.history_edu, 'Appointment History', 'Preserved logs & reports', AppTheme.tertiary, () => onNavigate(3)),
                _buildActionTile(Icons.category, 'Categories', 'Custom domain manager', Colors.deepPurple, () => onNavigate(5)),
                _buildActionTile(Icons.inventory_2, 'Products & Combos', 'Catalog & modifier items', Colors.teal, () => onNavigate(6)),
                _buildActionTile(Icons.tune, 'Appointment Config', 'Hours & interval settings', Colors.blueGrey, () => onNavigate(7)),
                _buildActionTile(Icons.shopping_cart, 'POS Cart', 'Checkout & Tender', Colors.indigo, () => onNavigate(4)),
                _buildActionTile(Icons.sync, 'System Sync', 'Station online status', Colors.green, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
            const SizedBox(height: 2),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant), maxLines: 1),
          ],
        ),
      ),
    );
  }
}

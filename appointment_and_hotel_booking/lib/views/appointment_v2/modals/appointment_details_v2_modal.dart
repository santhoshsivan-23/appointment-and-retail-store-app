import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/appointment_v2_utils.dart';

/// Appointment Details V2 Modal matching React AppointmentDetailsV2Modal
class AppointmentDetailsV2Modal extends StatefulWidget {
  final AppointmentModel appt;
  final String timeFormat;
  final VoidCallback onClose;
  final VoidCallback onStartService;
  final VoidCallback onContinueService;
  final ValueChanged<AppointmentModel> onStatusChanged;
  final VoidCallback onDelete;

  const AppointmentDetailsV2Modal({
    super.key,
    required this.appt,
    this.timeFormat = '12',
    required this.onClose,
    required this.onStartService,
    required this.onContinueService,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  State<AppointmentDetailsV2Modal> createState() => _AppointmentDetailsV2ModalState();
}

class _AppointmentDetailsV2ModalState extends State<AppointmentDetailsV2Modal> {
  late AppointmentModel _currentAppt;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _currentAppt = widget.appt;
  }

  Future<void> _handleStatusChange(String newStatus) async {
    if (_currentAppt.status == newStatus || _isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);

    try {
      await ApiService.updateAppointmentStatus(_currentAppt.id, newStatus);
      final updated = _currentAppt.copyWith(status: newStatus);
      if (mounted) {
        setState(() {
          _currentAppt = updated;
          _isUpdatingStatus = false;
        });
        widget.onStatusChanged(updated);
      }
    } catch (_) {
      // Fallback local update
      final updated = _currentAppt.copyWith(status: newStatus);
      if (mounted) {
        setState(() {
          _currentAppt = updated;
          _isUpdatingStatus = false;
        });
        widget.onStatusChanged(updated);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Appointment',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this appointment for ${_currentAppt.customerName}? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete();
      widget.onClose();
      try {
        await ApiService.deleteAppointment(_currentAppt.id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusMeta = getStatusMeta(_currentAppt.status);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330F172A),
                blurRadius: 28,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(statusMeta),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Details Grid
                      _buildDetailsGrid(),
                      const SizedBox(height: 18),

                      // Section 2: Services List
                      _buildServicesSection(),
                      const SizedBox(height: 18),

                      // Section 3: Notes
                      if (_currentAppt.notes.trim().isNotEmpty) ...[
                        _buildNotesSection(),
                        const SizedBox(height: 18),
                      ],

                      // Section 4: Status Actions
                      _buildStatusActions(),
                    ],
                  ),
                ),
              ),

              // 3. Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(V2StatusMeta statusMeta) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Appointment',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              '#${_currentAppt.id}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusMeta.badgeBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusMeta.border.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusMeta.label,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: statusMeta.badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            formatDatePretty(_currentAppt.appointmentDate),
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          const SizedBox(width: 6),
                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formatTimeSlotLabel(_currentAppt.startTime, _currentAppt.endTime, widget.timeFormat),
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildDetailCard(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFEFF6FF),
              label: 'Customer Name',
              value: _currentAppt.customerName.isNotEmpty
                  ? _currentAppt.customerName
                  : 'Walk-in Guest',
              width: cellWidth,
            ),
            _buildDetailCard(
              icon: Icons.phone_outlined,
              iconColor: const Color(0xFF0D9488),
              iconBg: const Color(0xFFCCFBF1),
              label: 'Phone Number',
              value: _currentAppt.customerPhone.isNotEmpty
                  ? _currentAppt.customerPhone
                  : 'None',
              width: cellWidth,
            ),
            _buildDetailCard(
              icon: Icons.work_outline_rounded,
              iconColor: const Color(0xFF9333EA),
              iconBg: const Color(0xFFFAF5FF),
              label: 'Assigned Staff',
              value: _currentAppt.staffName,
              width: cellWidth,
            ),
            _buildDetailCard(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFEFF6FF),
              label: 'Appointment Date',
              value: formatDatePretty(_currentAppt.appointmentDate),
              width: cellWidth,
            ),
            _buildDetailCard(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFFFBEB),
              label: 'Scheduled Time',
              value: formatTimeSlotLabel(_currentAppt.startTime, _currentAppt.endTime, widget.timeFormat),
              width: cellWidth,
            ),
            _buildDetailCard(
              icon: Icons.credit_card_outlined,
              iconColor: const Color(0xFF059669),
              iconBg: const Color(0xFFECFDF5),
              label: 'Total Payment',
              value: '\$${_currentAppt.totalAmount.toStringAsFixed(2)}',
              valueColor: const Color(0xFF059669),
              width: cellWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    Color? valueColor,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    final services = _currentAppt.serviceItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.content_cut_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Services Included',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${services.length} ${services.length == 1 ? "item" : "items"}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: services.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '\$${s.price.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'General Service',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '\$${_currentAppt.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              'Appointment Notes',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            _currentAppt.notes,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF475569),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              'Change Status',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusBtn(label: 'Booked', status: 'booked', icon: Icons.access_time_rounded, color: const Color(0xFF2563EB)),
            _buildStatusBtn(label: 'In Service', status: 'in_service', icon: Icons.play_arrow_rounded, color: const Color(0xFFD97706)),
            _buildStatusBtn(label: 'Completed', status: 'completed', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF059669)),
            _buildStatusBtn(label: 'No Show', status: 'no_show', icon: Icons.person_off_outlined, color: const Color(0xFFDC2626)),
            _buildStatusBtn(label: 'Cancelled', status: 'cancelled', icon: Icons.cancel_outlined, color: const Color(0xFF64748B)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBtn({
    required String label,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    final isActive = (_currentAppt.status == status);

    return InkWell(
      onTap: _isUpdatingStatus ? null : () => _handleStatusChange(status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Delete action
          OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
            label: Text(
              'Delete',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Actions
          Row(
            children: [
              if (_currentAppt.isBooked)
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onClose();
                    widget.onStartService();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 15),
                  label: Text(
                    'Start Service',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (_currentAppt.isInService)
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onClose();
                    widget.onContinueService();
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: Text(
                    'Continue Service',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

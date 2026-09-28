import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/customer_model.dart';
import '../models/staff_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AppointmentItem {
  final int id;
  final String time;
  final String customerName;
  final String staffName;
  final String service;
  final String status; // 'Confirmed', 'In Progress', 'Completed'
  final Color color;

  AppointmentItem({
    required this.id,
    required this.time,
    required this.customerName,
    required this.staffName,
    required this.service,
    required this.status,
    required this.color,
  });
}

class AppointmentView extends StatefulWidget {
  const AppointmentView({super.key});

  @override
  State<AppointmentView> createState() => _AppointmentViewState();
}

class _AppointmentViewState extends State<AppointmentView> {
  final List<AppointmentItem> _appointments = [
    AppointmentItem(id: 1, time: '09:00 AM - 10:00 AM', customerName: 'Claire Beauchamp', staffName: 'Dr. Shaun Ong', service: 'Comprehensive Health Consult', status: 'In Progress', color: AppTheme.primary),
    AppointmentItem(id: 2, time: '10:30 AM - 11:30 AM', customerName: 'Marcus Wright', staffName: 'Elena Rostova', service: 'Full Luxury Spa & Grooming', status: 'Confirmed', color: AppTheme.secondary),
    AppointmentItem(id: 3, time: '01:00 PM - 02:00 PM', customerName: 'David Kim (Walk-in)', staffName: 'Dr. Shaun Ong', service: 'Express Diagnostic Panel', status: 'Confirmed', color: AppTheme.primary),
    AppointmentItem(id: 4, time: '03:00 PM - 04:30 PM', customerName: 'Sarah Connor', staffName: 'Elena Rostova', service: 'De-shedding & Herbal Bath', status: 'Confirmed', color: AppTheme.secondary),
  ];

  List<StaffModel> _staffList = [];
  List<CustomerModel> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    final staff = await ApiService.getStaff();
    final custs = await ApiService.getCustomers();
    if (!mounted) return;
    setState(() {
      _staffList = staff;
      _customers = custs;
    });
  }

  void _showNewAppointmentModal() {
    StaffModel? selectedStaff = _staffList.isNotEmpty ? _staffList.first : null;
    CustomerModel? selectedCust = _customers.isNotEmpty ? _customers.first : null;
    final serviceCtrl = TextEditingController(text: 'General Appointment / Consult');
    final timeCtrl = TextEditingController(text: '04:30 PM - 05:30 PM');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Book New Appointment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_staffList.isNotEmpty) ...[
                  DropdownButtonFormField<StaffModel>(
                    initialValue: selectedStaff,
                    decoration: const InputDecoration(labelText: 'Assign Staff / Clinician *'),
                    items: _staffList.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.role})'))).toList(),
                    onChanged: (v) => setModalState(() => selectedStaff = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_customers.isNotEmpty) ...[
                  DropdownButtonFormField<CustomerModel>(
                    initialValue: selectedCust,
                    decoration: const InputDecoration(labelText: 'Select Customer *'),
                    items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (v) => setModalState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: serviceCtrl, decoration: const InputDecoration(labelText: 'Service / Session Type *')),
                const SizedBox(height: 12),
                TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time Slot *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _appointments.add(
                    AppointmentItem(
                      id: _appointments.length + 1,
                      time: timeCtrl.text,
                      customerName: selectedCust?.name ?? 'Walk-in Client',
                      staffName: selectedStaff?.name ?? 'Staff Clinician',
                      service: serviceCtrl.text,
                      status: 'Confirmed',
                      color: AppTheme.primary,
                    ),
                  );
                });
              },
              child: const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Appointment Schedule', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Real-time doctor slots, salon grooming queues & room check-ins', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
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
                  label: Text('New Appointment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  onPressed: _showNewAppointmentModal,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.separated(
                itemCount: _appointments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final appt = _appointments[idx];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: appt.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: appt.color),
                              const SizedBox(width: 6),
                              Text(appt.time, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: appt.color)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appt.customerName, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(appt.service, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.person_pin, size: 18, color: AppTheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(appt.staffName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: appt.status == 'In Progress' ? AppTheme.secondaryContainer.withValues(alpha: 0.2) : AppTheme.tertiaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            appt.status,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appt.status == 'In Progress' ? AppTheme.secondary : AppTheme.tertiary,
                            ),
                          ),
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

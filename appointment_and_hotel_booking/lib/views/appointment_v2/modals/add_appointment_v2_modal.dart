import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../models/staff_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/appointment_v2_utils.dart';
import '../../../widgets/clock_time_picker_modal.dart';
import '../../../widgets/wheel_time_picker.dart';

/// Add Appointment V2 Modal matching React AddAppointmentV2Modal
class AddAppointmentV2Modal extends StatefulWidget {
  final StaffModel staff;
  final String defaultDate;
  final BusinessSlot? prefilledSlot;
  final CustomerModel? preselectedCustomer;
  final String openTime;
  final String closeTime;
  final String timeFormat; // '12' or '24'
  final bool useWheelPickers;
  final List<AppointmentModel> existingAppointments;
  final VoidCallback onClose;
  final ValueChanged<AppointmentModel> onSuccess;

  const AddAppointmentV2Modal({
    super.key,
    required this.staff,
    required this.defaultDate,
    this.prefilledSlot,
    this.preselectedCustomer,
    this.openTime = '08:00',
    this.closeTime = '22:00',
    this.timeFormat = '12',
    this.useWheelPickers = true,
    required this.existingAppointments,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<AddAppointmentV2Modal> createState() => _AddAppointmentV2ModalState();
}

class _AddAppointmentV2ModalState extends State<AddAppointmentV2Modal> {
  // Step 1: Date
  late String _apptDate;

  // Step 2: Time Selection
  late String _startTime;
  late String _endTime;
  String? _clockPickerTarget; // 'start' or 'end'

  // Step 3: Customer Information
  late bool _isWalkIn;
  CustomerModel? _selectedCustomer;
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _walkInNameController = TextEditingController();
  final TextEditingController _walkInPhoneController = TextEditingController();
  List<CustomerModel> _customerResults = [];
  bool _isSearchingCustomers = false;
  Timer? _customerSearchDebounce;

  // Step 4: Services
  final TextEditingController _serviceSearchController = TextEditingController();
  List<ProductModel> _serviceResults = [];
  bool _isSearchingServices = false;
  Timer? _serviceSearchDebounce;
  final List<ProductModel> _selectedServices = [];

  // Step 5: Notes & Status
  final TextEditingController _notesController = TextEditingController();
  String? _errorMsg;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _apptDate = widget.defaultDate;
    _startTime = widget.prefilledSlot?.start24 ?? widget.openTime;
    _endTime = widget.prefilledSlot?.end24 ??
        minutesToTime24(timeToMinutes(_startTime) + 30);

    _selectedCustomer = widget.preselectedCustomer;
    _isWalkIn = widget.preselectedCustomer == null;
  }

  @override
  void dispose() {
    _customerSearchDebounce?.cancel();
    _serviceSearchDebounce?.cancel();
    _customerSearchController.dispose();
    _walkInNameController.dispose();
    _walkInPhoneController.dispose();
    _serviceSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onCustomerSearchChanged(String query) {
    _customerSearchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _customerResults = [];
        _isSearchingCustomers = false;
      });
      return;
    }

    setState(() => _isSearchingCustomers = true);
    _customerSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ApiService.searchCustomers(q);
        if (mounted) {
          setState(() {
            _customerResults = results;
            _isSearchingCustomers = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _customerResults = [];
            _isSearchingCustomers = false;
          });
        }
      }
    });
  }

  void _onServiceSearchChanged(String query) {
    _serviceSearchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _serviceResults = [];
        _isSearchingServices = false;
      });
      return;
    }

    setState(() => _isSearchingServices = true);
    _serviceSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ApiService.searchProducts(q);
        if (mounted) {
          setState(() {
            _serviceResults = results;
            _isSearchingServices = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _serviceResults = [];
            _isSearchingServices = false;
          });
        }
      }
    });
  }

  void _toggleService(ProductModel prod) {
    setState(() {
      final idx = _selectedServices.indexWhere((p) => p.id == prod.id);
      if (idx >= 0) {
        _selectedServices.removeAt(idx);
      } else {
        _selectedServices.add(prod);
      }
    });
  }

  double get _totalPrice {
    return _selectedServices.fold<double>(0.0, (sum, p) => sum + p.price);
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMsg = null);

    // 1. Validate Date
    if (_apptDate.trim().isEmpty) {
      setState(() => _errorMsg = 'Please select an appointment date.');
      return;
    }

    // 2. Validate Time
    final startM = timeToMinutes(_startTime);
    final endM = timeToMinutes(_endTime);
    if (endM <= startM) {
      setState(() => _errorMsg = 'End Time must not be earlier than Start Time.');
      return;
    }

    // 3. Customer validation
    final customerName = _isWalkIn
        ? _walkInNameController.text.trim()
        : _selectedCustomer?.name.trim() ?? '';
    if (customerName.isEmpty) {
      setState(() => _errorMsg = _isWalkIn
          ? 'Please enter walk-in customer name.'
          : 'Please search and select a customer.');
      return;
    }

    final customerPhone = _isWalkIn
        ? _walkInPhoneController.text.trim()
        : _selectedCustomer?.phone.trim() ?? '';
    final customerId = _isWalkIn ? null : _selectedCustomer?.id;

    setState(() => _isSubmitting = true);

    try {
      // 4. Local Conflict Validation
      if (_apptDate == widget.defaultDate) {
        final overlap = checkClientOverlap(
          widget.existingAppointments,
          _startTime,
          _endTime,
        );
        if (overlap.hasConflict) {
          setState(() {
            _errorMsg =
                'An appointment already exists for this staff member during the selected time.';
            _isSubmitting = false;
          });
          return;
        }
      }

      // 5. Server Conflict Validation
      final conflict = await ApiService.checkConflict(
        staffId: widget.staff.id,
        appointmentDate: _apptDate,
        startTime: _startTime,
        endTime: _endTime,
      );
      if (conflict.hasConflict) {
        setState(() {
          _errorMsg = conflict.message ??
              'An appointment already exists for this staff member during the selected time.';
          _isSubmitting = false;
        });
        return;
      }

      // 6. Create appointment payload
      final payload = {
        'business_id': widget.staff.businessId,
        'staff_id': widget.staff.id,
        'staff_name': widget.staff.name,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'appointment_date': _apptDate,
        'start_time': _startTime,
        'end_time': _endTime,
        'total_amount': _totalPrice,
        'status': 'booked',
        'services': _selectedServices
            .map((p) => {
                  'product_id': p.id,
                  'name': p.name,
                  'price': p.price,
                  'quantity': 1,
                })
            .toList(),
        'notes': _notesController.text.trim(),
      };

      final created = await ApiService.createAppointment(payload);
      if (created != null) {
        widget.onSuccess(created);
      } else {
        // Fallback local creation if offline
        final fallbackAppt = AppointmentModel(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          businessId: widget.staff.businessId,
          staffId: widget.staff.id,
          staffName: widget.staff.name,
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          appointmentDate: _apptDate,
          startTime: _startTime,
          endTime: _endTime,
          totalAmount: _totalPrice,
          status: 'booked',
          notes: _notesController.text.trim(),
          services: _selectedServices
              .map((p) => {
                    'product_id': p.id,
                    'name': p.name,
                    'price': p.price,
                    'quantity': 1,
                  })
              .toList(),
        );
        widget.onSuccess(fallbackAppt);
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to create appointment: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 780),
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
              _buildHeader(),

              // Error banner if any
              if (_errorMsg != null)
                Container(
                  color: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Date Selection
                      _buildDateSection(),
                      const SizedBox(height: 16),

                      // Section 2: Start & End Time
                      _buildTimeSection(),
                      const SizedBox(height: 16),

                      // Section 3: Customer Information
                      _buildCustomerSection(),
                      const SizedBox(height: 16),

                      // Section 4: Service Selection
                      _buildServiceSection(),
                      const SizedBox(height: 16),

                      // Section 5: Notes
                      _buildNotesSection(),
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

  Widget _buildHeader() {
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
                  child: const Icon(Icons.event_available_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add Appointment',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          children: [
                            const TextSpan(text: 'Assigning staff: '),
                            TextSpan(
                              text: widget.staff.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildDateSection() {
    return _buildCardSection(
      icon: Icons.calendar_today_outlined,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFEFF6FF),
      title: 'Select Appointment',
      subtitle: 'Choose the appointment date',
      badge: formatDatePretty(_apptDate),
      badgeColor: const Color(0xFF2563EB),
      badgeBg: const Color(0xFFEFF6FF),
      content: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final curParts = _apptDate.split('-');
          DateTime initial = now;
          if (curParts.length == 3) {
            final y = int.tryParse(curParts[0]) ?? now.year;
            final m = int.tryParse(curParts[1]) ?? now.month;
            final d = int.tryParse(curParts[2]) ?? now.day;
            initial = DateTime(y, m, d);
          }
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null) {
            setState(() {
              final y = picked.year.toString();
              final m = picked.month.toString().padLeft(2, '0');
              final d = picked.day.toString().padLeft(2, '0');
              _apptDate = '$y-$m-$d';
              _errorMsg = null;
            });
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Text(
                formatDatePretty(_apptDate),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                'Change Date',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    final startM = timeToMinutes(_startTime);
    final endM = timeToMinutes(_endTime);
    final diffM = endM - startM;

    return _buildCardSection(
      icon: Icons.access_time_rounded,
      iconColor: const Color(0xFFD97706),
      iconBg: const Color(0xFFFFFBEB),
      title: 'Select Start & End Time',
      subtitle: 'Business hours: ${formatTime12(widget.openTime)} – ${formatTime12(widget.closeTime)}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.useWheelPickers)
            Row(
              children: [
                Expanded(
                  child: WheelTimePicker(
                    label: 'Start Time',
                    value: _startTime,
                    timeFormat: widget.timeFormat,
                    onChange: (newStart) {
                      setState(() {
                        _startTime = newStart;
                        _errorMsg = null;
                        if (timeToMinutes(_endTime) <= timeToMinutes(newStart)) {
                          _endTime = minutesToTime24(timeToMinutes(newStart) + 30);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WheelTimePicker(
                    label: 'End Time',
                    value: _endTime,
                    timeFormat: widget.timeFormat,
                    onChange: (newEnd) {
                      setState(() {
                        _endTime = newEnd;
                        _errorMsg = null;
                      });
                    },
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildClockTriggerCard(
                    label: 'Start Time',
                    time: _startTime,
                    onTap: () => setState(() => _clockPickerTarget = 'start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildClockTriggerCard(
                    label: 'End Time',
                    time: _endTime,
                    onTap: () => setState(() => _clockPickerTarget = 'end'),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Duration summary bar & presets
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      formatTimeSlotLabel(_startTime, _endTime, widget.timeFormat),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffM > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        diffM > 0 ? '$diffM mins' : 'End must be after Start',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: diffM > 0 ? const Color(0xFF166534) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Quick: ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                    ),
                    for (final mins in [15, 30, 45, 60, 90]) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            final newEndM = timeToMinutes(_startTime) + mins;
                            _endTime = minutesToTime24(newEndM);
                            _errorMsg = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            '+${mins}m',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Clock modal popup if active
          if (_clockPickerTarget != null)
            ClockTimePickerModal(
              label: _clockPickerTarget == 'start' ? 'Select Start Time' : 'Select End Time',
              initialTime24: _clockPickerTarget == 'start' ? _startTime : _endTime,
              onClose: () => setState(() => _clockPickerTarget = null),
              onSelectTime: (newTime24) {
                setState(() {
                  if (_clockPickerTarget == 'start') {
                    _startTime = newTime24;
                    if (timeToMinutes(_endTime) <= timeToMinutes(newTime24)) {
                      _endTime = minutesToTime24(timeToMinutes(newTime24) + 30);
                    }
                  } else {
                    _endTime = newTime24;
                  }
                  _clockPickerTarget = null;
                  _errorMsg = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClockTriggerCard({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  formatTime12(time),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _buildCardSection(
      icon: Icons.person_outline_rounded,
      iconColor: const Color(0xFF059669),
      iconBg: const Color(0xFFECFDF5),
      title: 'Customer Information',
      subtitle: 'Search registered customer or enter walk-in guest',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleOption(
                    title: 'Registered Customer',
                    isSelected: !_isWalkIn,
                    onTap: () => setState(() {
                      _isWalkIn = false;
                      _errorMsg = null;
                    }),
                  ),
                ),
                Expanded(
                  child: _buildToggleOption(
                    title: 'Walk-in Guest',
                    isSelected: _isWalkIn,
                    onTap: () => setState(() {
                      _isWalkIn = true;
                      _errorMsg = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_isWalkIn)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _walkInNameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                      hintText: 'Customer Name *',
                      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _walkInPhoneController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                      hintText: 'Phone Number (optional)',
                      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            )
          else if (_selectedCustomer != null)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      _selectedCustomer!.name.isNotEmpty ? _selectedCustomer!.name[0].toUpperCase() : 'C',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _selectedCustomer!.phone.isNotEmpty ? _selectedCustomer!.phone : 'No phone',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                        _customerSearchController.clear();
                        _customerResults = [];
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: Text(
                      'Change',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _customerSearchController,
                  onChanged: _onCustomerSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                    hintText: 'Search by customer name or phone...',
                    hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                if (_isSearchingCustomers)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_customerResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _customerResults.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = _customerResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            c.name,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            c.phone.isNotEmpty ? c.phone : 'No phone',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = c;
                              _customerSearchController.clear();
                              _customerResults = [];
                              _errorMsg = null;
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSection() {
    return _buildCardSection(
      icon: Icons.work_outline_rounded,
      iconColor: const Color(0xFF9333EA),
      iconBg: const Color(0xFFFAF5FF),
      title: 'Select Service',
      subtitle: '${_selectedServices.length} service${_selectedServices.length == 1 ? "" : "s"} selected',
      badge: 'Total: \$${_totalPrice.toStringAsFixed(2)}',
      badgeColor: const Color(0xFF9333EA),
      badgeBg: const Color(0xFFFAF5FF),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _serviceSearchController,
            onChanged: _onServiceSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
              hintText: 'Search service or product name...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.inter(fontSize: 13),
          ),

          if (_isSearchingServices)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_serviceResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _serviceResults.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prod = _serviceResults[index];
                  final isSelected = _selectedServices.any((p) => p.id == prod.id);
                  return CheckboxListTile(
                    dense: true,
                    value: isSelected,
                    title: Text(
                      prod.name,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      prod.productType,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    secondary: Text(
                      '\$${prod.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    onChanged: (_) => _toggleService(prod),
                  );
                },
              ),
            ),

          if (_selectedServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedServices.map((prod) {
                return Chip(
                  label: Text(
                    '${prod.name} (\$${prod.price.toStringAsFixed(2)})',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => _toggleService(prod),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildCardSection(
      icon: Icons.notes_rounded,
      iconColor: const Color(0xFFE11D48),
      iconBg: const Color(0xFFFFF1F2),
      title: 'Notes',
      subtitle: 'Special requests or instructions (Optional)',
      content: TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Special requests, client preferences, or internal notes...',
          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: GoogleFonts.inter(fontSize: 13),
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSubmitting ? null : widget.onClose,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: Text(
              _isSubmitting ? 'Checking & Saving...' : 'Save Appointment',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    Color? badgeBg,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              if (badge != null && badgeColor != null && badgeBg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

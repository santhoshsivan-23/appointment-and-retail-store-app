import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../models/staff_model.dart';
import '../../services/api_service.dart';
import '../../utils/appointment_v2_utils.dart';
import 'appointment_v2_calendar_sidebar.dart';
import 'appointment_v2_header.dart';
import 'appointment_v2_schedule_viewport.dart';
import 'modals/add_appointment_v2_modal.dart';
import 'modals/appointment_details_v2_modal.dart';
import 'modals/time_slot_filter_modal.dart';
import 'v2_staff_selection_view.dart';

/// Root Appointment V2 View Coordinator
/// Matches React AppointmentV2View.tsx: switches between Screen 1 (Staff Selection)
/// and Screen 2 (Staff Schedule Viewport).
class AppointmentV2View extends StatefulWidget {
  final void Function(
    CustomerModel customer,
    List<ProductModel> products, {
    AppointmentModel? appointment,
  }) onStartService;

  const AppointmentV2View({
    super.key,
    required this.onStartService,
  });

  @override
  State<AppointmentV2View> createState() => _AppointmentV2ViewState();
}

class _AppointmentV2ViewState extends State<AppointmentV2View> {
  // Staff Selection State
  List<StaffModel> _staffList = [];
  bool _isLoadingStaff = true;
  StaffModel? _selectedStaff;

  // Selected Date (default: today)
  String _selectedDate = getTodayDateStr();
  DateTime _calendarViewDate = DateTime.now();

  // View Mode: 'list' (default), 'grid', 'time'
  String _viewMode = 'list';

  // Appointments for selected staff and date
  List<AppointmentModel> _appointments = [];
  bool _isLoadingAppts = false;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoadingStaff = true);
    try {
      final list = await ApiService.getStaff(includeDeleted: false);
      if (mounted) {
        setState(() {
          _staffList = list;
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStaff = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load staff roster: $e')),
        );
      }
    }
  }

  Future<void> _fetchAppointments() async {
    final staff = _selectedStaff;
    if (staff == null) return;

    setState(() => _isLoadingAppts = true);
    try {
      final list = await ApiService.getAppointments(
        staffId: staff.id,
        date: _selectedDate,
      );
      // Sort chronologically by startTime
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      if (mounted) {
        setState(() {
          _appointments = list;
          _isLoadingAppts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAppts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load appointments: $e')),
        );
      }
    }
  }

  void _onSelectStaff(StaffModel staff) {
    setState(() {
      _selectedStaff = staff;
      _selectedDate = getTodayDateStr();
      _calendarViewDate = DateTime.now();
    });
    _fetchAppointments();
  }

  void _onChangeStaff() {
    setState(() {
      _selectedStaff = null;
      _appointments = [];
    });
  }

  void _onViewModeChanged(String mode) {
    setState(() {
      _viewMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // SCREEN 1: Staff Selection Roster
    if (_selectedStaff == null) {
      return V2StaffSelectionView(
        staffList: _staffList,
        isLoading: _isLoadingStaff,
        onSelectStaff: _onSelectStaff,
        onRefresh: _fetchStaff,
      );
    }

    final dayStats = DayStats.fromAppointments(_appointments);

    // SCREEN 2: Main Layout (Fixed Top Header + 2-Column Viewport with Calendar Sidebar)
    return Container(
      color: const Color(0xFFF8FAF9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // Section 1: Top Navigation Header (Permanently Fixed in Top)
            AppointmentV2Header(
              selectedStaff: _selectedStaff!,
              selectedDate: _selectedDate,
              viewMode: _viewMode,
              isLoadingAppts: _isLoadingAppts,
              onSwitchStaff: _onChangeStaff,
              onViewModeChange: _onViewModeChanged,
              onOpenFilterModal: _handleOpenFilterModal,
              onRefresh: _fetchAppointments,
              onOpenAddModal: () => _handleOpenAddModal(),
              onSelectCustomerToBook: (cust) {
                _handleOpenAddModal(preselectedCustomer: cust);
              },
            ),

            const SizedBox(height: 12),

            // Section 2: Two Independently Scrollable Columns (or Adaptive Stack on < 960px)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Section: Appointment Data Viewport (Independently Scrollable)
                        Expanded(
                          child: AppointmentV2ScheduleViewport(
                            isLoadingAppts: _isLoadingAppts,
                            viewMode: _viewMode,
                            selectedStaff: _selectedStaff!,
                            selectedDate: _selectedDate,
                            appointments: _appointments,
                            onStartService: _handleStartService,
                            onContinueService: _handleContinueService,
                            onOpenDetailsModal: _handleOpenDetailsModal,
                            onOpenAddModal: (slot) => _handleOpenAddModal(prefilledSlot: slot),
                            onSelectToday: () {
                              setState(() {
                                _selectedDate = getTodayDateStr();
                                _calendarViewDate = DateTime.now();
                              });
                              _fetchAppointments();
                            },
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Right Section: Calendar and Status Sidebar
                        AppointmentV2CalendarSidebar(
                          selectedStaff: _selectedStaff!,
                          selectedDate: _selectedDate,
                          calendarViewDate: _calendarViewDate,
                          appointments: _appointments,
                          dayStats: dayStats,
                          onSelectDate: (dateStr) {
                            setState(() {
                              _selectedDate = dateStr;
                            });
                            _fetchAppointments();
                          },
                          onChangeCalendarMonth: (date) {
                            setState(() {
                              _calendarViewDate = date;
                            });
                          },
                          onSwitchStaff: _onChangeStaff,
                        ),
                      ],
                    );
                  }

                  // Responsive Column layout for < 960px viewports (Tablets / Mobile)
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 540,
                          child: AppointmentV2ScheduleViewport(
                            isLoadingAppts: _isLoadingAppts,
                            viewMode: _viewMode,
                            selectedStaff: _selectedStaff!,
                            selectedDate: _selectedDate,
                            appointments: _appointments,
                            onStartService: _handleStartService,
                            onContinueService: _handleContinueService,
                            onOpenDetailsModal: _handleOpenDetailsModal,
                            onOpenAddModal: (slot) => _handleOpenAddModal(prefilledSlot: slot),
                            onSelectToday: () {
                              setState(() {
                                _selectedDate = getTodayDateStr();
                                _calendarViewDate = DateTime.now();
                              });
                              _fetchAppointments();
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppointmentV2CalendarSidebar(
                          width: double.infinity,
                          selectedStaff: _selectedStaff!,
                          selectedDate: _selectedDate,
                          calendarViewDate: _calendarViewDate,
                          appointments: _appointments,
                          dayStats: dayStats,
                          onSelectDate: (dateStr) {
                            setState(() {
                              _selectedDate = dateStr;
                            });
                            _fetchAppointments();
                          },
                          onChangeCalendarMonth: (date) {
                            setState(() {
                              _calendarViewDate = date;
                            });
                          },
                          onSwitchStaff: _onChangeStaff,
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

  void _handleStartService(AppointmentModel appt) async {
    try {
      await ApiService.updateAppointmentStatus(appt.id, 'in_service');
      setState(() {
        final idx = _appointments.indexWhere((a) => a.id == appt.id);
        if (idx != -1) {
          _appointments[idx] = appt.copyWith(status: 'in_service');
        }
      });
    } catch (_) {
      setState(() {
        final idx = _appointments.indexWhere((a) => a.id == appt.id);
        if (idx != -1) {
          _appointments[idx] = appt.copyWith(status: 'in_service');
        }
      });
    }

    widget.onStartService(
      CustomerModel(
        id: appt.customerId ?? 0,
        businessId: appt.businessId,
        name: appt.customerName,
        phone: appt.customerPhone,
      ),
      appt.serviceItems
          .map((s) => ProductModel(
                id: s.productId ?? 0,
                businessId: appt.businessId,
                name: s.name,
                sku: 'APPT-${s.productId ?? 0}',
                price: s.price,
              ))
          .toList(),
      appointment: appt,
    );
  }

  void _handleContinueService(AppointmentModel appt) {
    widget.onStartService(
      CustomerModel(
        id: appt.customerId ?? 0,
        businessId: appt.businessId,
        name: appt.customerName,
        phone: appt.customerPhone,
      ),
      appt.serviceItems
          .map((s) => ProductModel(
                id: s.productId ?? 0,
                businessId: appt.businessId,
                name: s.name,
                sku: 'APPT-${s.productId ?? 0}',
                price: s.price,
              ))
          .toList(),
      appointment: appt,
    );
  }

  void _handleOpenDetailsModal(AppointmentModel appt) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => AppointmentDetailsV2Modal(
        appt: appt,
        onClose: () => Navigator.pop(ctx),
        onStartService: () {
          _handleStartService(appt);
        },
        onContinueService: () {
          _handleContinueService(appt);
        },
        onStatusChanged: (updated) {
          setState(() {
            final idx = _appointments.indexWhere((a) => a.id == updated.id);
            if (idx != -1) {
              _appointments[idx] = updated;
            }
          });
        },
        onDelete: () {
          setState(() {
            _appointments.removeWhere((a) => a.id == appt.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment #${appt.id} deleted'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _handleOpenFilterModal() {
    final slots = generateBusinessSlots();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => TimeSlotFilterModal(
        slots: slots,
        appointments: _appointments,
        onClose: () => Navigator.pop(ctx),
        onSelectSlot: (slot) {
          setState(() {
            _viewMode = 'time';
          });
        },
      ),
    );
  }

  void _handleOpenAddModal({
    BusinessSlot? prefilledSlot,
    CustomerModel? preselectedCustomer,
  }) {
    final staff = _selectedStaff;
    if (staff == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => AddAppointmentV2Modal(
        staff: staff,
        defaultDate: _selectedDate,
        prefilledSlot: prefilledSlot,
        preselectedCustomer: preselectedCustomer,
        existingAppointments: _appointments,
        onClose: () => Navigator.pop(ctx),
        onSuccess: (newAppt) {
          Navigator.pop(ctx);
          setState(() {
            _appointments.add(newAppt);
            _appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment #${newAppt.id} successfully created!'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchAppointments();
        },
      ),
    );
  }
}

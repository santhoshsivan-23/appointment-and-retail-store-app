import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/appointment_model.dart';
import '../../models/staff_model.dart';
import '../../utils/appointment_v2_utils.dart';
import 'views/v2_grid_view.dart';
import 'views/v2_list_view.dart';
import 'views/v2_time_view.dart';

/// Coordinator viewport for Screen 2's schedule pane (List, Grid, and Time views)
class AppointmentV2ScheduleViewport extends StatefulWidget {
  final bool isLoadingAppts;
  final String viewMode;
  final StaffModel selectedStaff;
  final String selectedDate;
  final List<AppointmentModel> appointments;
  final ValueChanged<AppointmentModel> onStartService;
  final ValueChanged<AppointmentModel> onContinueService;
  final ValueChanged<AppointmentModel> onOpenDetailsModal;
  final ValueChanged<BusinessSlot?> onOpenAddModal;
  final VoidCallback onSelectToday;

  const AppointmentV2ScheduleViewport({
    super.key,
    required this.isLoadingAppts,
    required this.viewMode,
    required this.selectedStaff,
    required this.selectedDate,
    required this.appointments,
    required this.onStartService,
    required this.onContinueService,
    required this.onOpenDetailsModal,
    required this.onOpenAddModal,
    required this.onSelectToday,
  });

  @override
  State<AppointmentV2ScheduleViewport> createState() => _AppointmentV2ScheduleViewportState();
}

class _AppointmentV2ScheduleViewportState extends State<AppointmentV2ScheduleViewport> {
  int? _expandedApptId;

  void _handleToggleExpand(int id) {
    setState(() {
      if (_expandedApptId == id) {
        _expandedApptId = null;
      } else {
        _expandedApptId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingAppts) {
      return Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading schedule for ${widget.selectedStaff.name}...',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (widget.viewMode) {
      case 'grid':
        return V2GridView(
          appointments: widget.appointments,
          selectedStaff: widget.selectedStaff,
          selectedDate: widget.selectedDate,
          onOpenDetails: widget.onOpenDetailsModal,
          onBookAppointment: () => widget.onOpenAddModal(null),
          onGoToToday: widget.onSelectToday,
        );

      case 'time':
        return V2TimeView(
          appointments: widget.appointments,
          selectedStaff: widget.selectedStaff,
          selectedDate: widget.selectedDate,
          expandedApptId: _expandedApptId,
          onToggleExpand: _handleToggleExpand,
          onStartService: widget.onStartService,
          onContinueService: widget.onContinueService,
          onOpenDetails: widget.onOpenDetailsModal,
          onOpenAddModal: widget.onOpenAddModal,
        );

      case 'list':
      default:
        return V2ListView(
          appointments: widget.appointments,
          selectedStaff: widget.selectedStaff,
          selectedDate: widget.selectedDate,
          expandedApptId: _expandedApptId,
          onToggleExpand: _handleToggleExpand,
          onStartService: widget.onStartService,
          onContinueService: widget.onContinueService,
          onOpenDetails: widget.onOpenDetailsModal,
          onBookAppointment: () => widget.onOpenAddModal(null),
          onGoToToday: widget.onSelectToday,
        );
    }
  }
}

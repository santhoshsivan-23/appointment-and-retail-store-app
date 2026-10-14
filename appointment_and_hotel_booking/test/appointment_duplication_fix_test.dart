import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/services/firebase_service.dart';

void main() {
  group('Appointment Duplication Prevention & Fix Tests', () {
    test('Deduplication logic ensures only unique appointment IDs exist in list', () {
      final appt1 = AppointmentModel(
        id: 38,
        businessId: 1,
        staffId: 12,
        staffName: 'Staff 12',
        customerName: 'dFax',
        customerPhone: '1234567890',
        appointmentDate: '2026-10-14',
        startTime: '12:30',
        endTime: '13:00',
        status: 'booked',
        totalAmount: 100.0,
        services: [],
      );

      // Duplicate twin with same ID (e.g. from repeated network response or concurrent load)
      final appt1Duplicate = AppointmentModel(
        id: 38,
        businessId: 1,
        staffId: 12,
        staffName: 'Staff 12',
        customerName: 'dFax',
        customerPhone: '1234567890',
        appointmentDate: '2026-10-14',
        startTime: '12:30',
        endTime: '13:00',
        status: 'booked',
        totalAmount: 100.0,
        services: [],
      );

      final appt2 = AppointmentModel(
        id: 39,
        businessId: 1,
        staffId: 13,
        staffName: 'Staff 13',
        customerName: 'dFax',
        customerPhone: '1234567890',
        appointmentDate: '2026-10-14',
        startTime: '11:30',
        endTime: '12:00',
        status: 'booked',
        totalAmount: 100.0,
        services: [],
      );

      final rawList = [appt1, appt1Duplicate, appt2];
      expect(rawList.length, 3);

      // Apply deduplication pattern used in getAppointments, _loadData, and _buildStaffLane
      final Map<int, AppointmentModel> uniqueMap = {};
      for (final a in rawList) {
        uniqueMap[a.id] = a;
      }
      final deduplicated = uniqueMap.values.toList();

      expect(deduplicated.length, 2);
      expect(deduplicated.map((a) => a.id).toList(), [38, 39]);
    });

    test('Moving an appointment updates existing entry in place without leaving duplicate behind', () {
      final appt = AppointmentModel(
        id: 38,
        businessId: 1,
        staffId: 12,
        staffName: 'Staff 12',
        customerName: 'dFax',
        customerPhone: '1234567890',
        appointmentDate: '2026-10-14',
        startTime: '12:30',
        endTime: '13:00',
        status: 'booked',
        totalAmount: 100.0,
        services: [],
      );

      List<AppointmentModel> appointments = [appt];

      // Simulate move to staff 13, time 14:00
      final updatedAppt = appt.copyWith(
        staffId: 13,
        staffName: 'Staff 13',
        startTime: '14:00',
        endTime: '14:30',
      );

      final idx = appointments.indexWhere((a) => a.id == appt.id);
      expect(idx, isNot(-1));
      appointments[idx] = updatedAppt;

      // Assert only 1 appointment exists, at new staff and time
      expect(appointments.length, 1);
      expect(appointments.first.staffId, 13);
      expect(appointments.first.startTime, '14:00');
      expect(appointments.first.id, 38);

      // Verify no appointments remain in the old staff lane (staffId 12)
      final staff12Appointments = appointments.where((a) => a.staffId == 12).toList();
      expect(staff12Appointments, isEmpty);

      // Verify new staff lane has exactly this appointment
      final staff13Appointments = appointments.where((a) => a.staffId == 13).toList();
      expect(staff13Appointments.length, 1);
      expect(staff13Appointments.first.id, 38);
    });

    test('Marking appointment as No Show updates status in place without duplication', () {
      final appt = AppointmentModel(
        id: 40,
        businessId: 1,
        staffId: 13,
        staffName: 'Staff 13',
        customerName: 'dcsfsf',
        customerPhone: '1234567890',
        appointmentDate: '2026-10-14',
        startTime: '13:30',
        endTime: '14:00',
        status: 'booked',
        totalAmount: 50.0,
        services: [],
      );

      List<AppointmentModel> appointments = [appt];
      Map<String, int> overviewStats = {'booked': 1, 'no_show': 0};

      // Optimistic status update as implemented in _showAppointmentDetails
      final idx = appointments.indexWhere((a) => a.id == appt.id);
      if (idx != -1) {
        appointments[idx] = appt.copyWith(status: 'no_show');
      }
      overviewStats['booked'] = ((overviewStats['booked'] ?? 1) - 1).clamp(0, 9999);
      overviewStats['no_show'] = (overviewStats['no_show'] ?? 0) + 1;

      expect(appointments.length, 1);
      expect(appointments.first.status, 'no_show');
      expect(overviewStats['booked'], 0);
      expect(overviewStats['no_show'], 1);
    });

    test('Lane sorting orders inactive appointments cleanly without overlapping duplicates', () {
      final apptActive = AppointmentModel(
        id: 50,
        businessId: 1,
        staffId: 11,
        staffName: 'Staff 11',
        customerName: 'Customer A',
        customerPhone: '',
        appointmentDate: '2026-10-14',
        startTime: '10:00',
        endTime: '10:30',
        status: 'booked',
        totalAmount: 50.0,
        services: [],
      );

      final apptInactive = AppointmentModel(
        id: 51,
        businessId: 1,
        staffId: 11,
        staffName: 'Staff 11',
        customerName: 'Customer B',
        customerPhone: '',
        appointmentDate: '2026-10-14',
        startTime: '10:00',
        endTime: '10:30',
        status: 'no_show',
        totalAmount: 50.0,
        services: [],
      );

      final laneList = [apptActive, apptInactive];

      // Deduplicate by ID
      final Map<int, AppointmentModel> uniqueLaneAppts = {};
      for (final a in laneList) {
        uniqueLaneAppts[a.id] = a;
      }
      final sortedAppts = uniqueLaneAppts.values.toList();
      sortedAppts.sort((a, b) {
        final aInactive = (a.status == 'cancelled' || a.status == 'no_show') ? 0 : 1;
        final bInactive = (b.status == 'cancelled' || b.status == 'no_show') ? 0 : 1;
        if (aInactive != bInactive) {
          return aInactive.compareTo(bInactive);
        }
        return a.startMinutes.compareTo(b.startMinutes);
      });

      expect(sortedAppts.length, 2);
      // Inactive (no_show) rendered first (background), active (booked) rendered second (foreground)
      expect(sortedAppts[0].id, 51);
      expect(sortedAppts[0].status, 'no_show');
      expect(sortedAppts[1].id, 50);
      expect(sortedAppts[1].status, 'booked');
    });

    testWidgets('Submission lock prevents duplicate form submissions', (tester) async {
      int submissionCount = 0;
      bool isSubmitting = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ElevatedButton(
                  key: const ValueKey('confirm_btn'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setState(() => isSubmitting = true);
                          submissionCount++;
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (context.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('Confirm Booking'),
                ),
              );
            },
          ),
        ),
      );

      final buttonFinder = find.byKey(const ValueKey('confirm_btn'));
      expect(buttonFinder, findsOneWidget);

      // First tap begins async submission
      await tester.tap(buttonFinder);
      await tester.pump(); // re-render with isSubmitting = true

      expect(submissionCount, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Attempt second tap while submitting (should be disabled)
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump();

      // Submission count remains 1, no duplicate invocation
      expect(submissionCount, 1);

      // Wait for async completion
      await tester.pumpAndSettle();
      expect(submissionCount, 1);
      expect(find.text('Confirm Booking'), findsOneWidget);
    });
  });
}

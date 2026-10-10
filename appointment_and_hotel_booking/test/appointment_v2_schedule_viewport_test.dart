import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_schedule_viewport.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_grid_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_list_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_time_view.dart';

void main() {
  final testStaff = StaffModel(
    id: 1,
    businessId: 1,
    name: 'Sarah Connor',
    role: 'Senior Stylist',
    phone: '555-1234',
    colorCode: '#2563EB',
    isActive: true,
  );

  final sampleAppointments = [
    AppointmentModel(
      id: 101,
      businessId: 1,
      staffId: 1,
      staffName: 'Sarah Connor',
      customerId: 1,
      customerName: 'Emma Watson',
      customerPhone: '555-0101',
      appointmentDate: '2026-10-15',
      startTime: '09:00',
      endTime: '09:30',
      status: 'booked',
      totalAmount: 50.0,
      notes: 'Prefers quiet session',
      services: [
        {'product_id': 10, 'name': 'Haircut & Styling', 'price': 50.0}
      ],
    ),
    AppointmentModel(
      id: 102,
      businessId: 1,
      staffId: 1,
      staffName: 'Sarah Connor',
      customerId: 2,
      customerName: 'John Doe',
      customerPhone: '555-0202',
      appointmentDate: '2026-10-15',
      startTime: '10:00',
      endTime: '11:00',
      status: 'in_service',
      totalAmount: 120.0,
      services: [
        {'product_id': 11, 'name': 'Full Hair Coloring', 'price': 120.0}
      ],
    ),
  ];

  group('V2ListView Tests', () {
    testWidgets('Renders appointment cards and expands accordion panel on tap', (tester) async {
      int? expandedId;
      AppointmentModel? startedAppt;
      AppointmentModel? detailsAppt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2ListView(
                  appointments: sampleAppointments,
                  selectedStaff: testStaff,
                  selectedDate: '2026-10-15',
                  expandedApptId: expandedId,
                  onToggleExpand: (id) => setState(() => expandedId = (expandedId == id ? null : id)),
                  onStartService: (a) => startedAppt = a,
                  onContinueService: (_) {},
                  onOpenDetails: (a) => detailsAppt = a,
                  onBookAppointment: () {},
                  onGoToToday: () {},
                );
              },
            ),
          ),
        ),
      );

      // Verify list items rendered
      expect(find.text('Emma Watson'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);

      // Tap on first appointment to expand accordion
      await tester.tap(find.text('Emma Watson'));
      await tester.pumpAndSettle();

      // Expanded details panel should now be visible
      expect(find.text('SERVICE'), findsOneWidget);
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(find.text('Prefers quiet session'), findsOneWidget);
      expect(find.text('Start Service'), findsOneWidget);
      expect(find.text('Full Details'), findsOneWidget);
      expect(find.text('Collapse'), findsOneWidget);

      // Tap Start Service
      await tester.tap(find.text('Start Service'));
      await tester.pumpAndSettle();
      expect(startedAppt?.id, 101);

      // Tap Full Details
      await tester.tap(find.text('Full Details'));
      await tester.pumpAndSettle();
      expect(detailsAppt?.id, 101);

      // Tap Collapse
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(find.text('Prefers quiet session'), findsNothing);
    });

    testWidgets('Renders empty schedule card when appointments list is empty', (tester) async {
      bool bookTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2ListView(
              appointments: const [],
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              expandedApptId: null,
              onToggleExpand: (_) {},
              onStartService: (_) {},
              onContinueService: (_) {},
              onOpenDetails: (_) {},
              onBookAppointment: () => bookTriggered = true,
              onGoToToday: () {},
            ),
          ),
        ),
      );

      expect(find.text('No Appointments Booked'), findsOneWidget);
      expect(find.text('100% FREE SCHEDULE'), findsOneWidget);
      expect(find.text('Book An Appointment'), findsOneWidget);

      await tester.tap(find.text('Book An Appointment'));
      await tester.pumpAndSettle();
      expect(bookTriggered, isTrue);
    });
  });

  group('V2GridView Tests', () {
    testWidgets('Renders responsive cards with status badges and detail trigger', (tester) async {
      AppointmentModel? clickedAppt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2GridView(
              appointments: sampleAppointments,
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              onOpenDetails: (a) => clickedAppt = a,
              onBookAppointment: () {},
              onGoToToday: () {},
            ),
          ),
        ),
      );

      expect(find.text('Emma Watson'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('View Details'), findsNWidgets(2));

      await tester.tap(find.text('Emma Watson'));
      await tester.pumpAndSettle();
      expect(clickedAppt?.id, 101);
    });
  });

  group('V2TimeView Tests', () {
    testWidgets('Renders timeline slots and booked appointments', (tester) async {
      BusinessSlot? bookedSlot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2TimeView(
              appointments: sampleAppointments,
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              expandedApptId: null,
              onToggleExpand: (_) {},
              onStartService: (_) {},
              onContinueService: (_) {},
              onOpenDetails: (_) {},
              onOpenAddModal: (s) => bookedSlot = s,
            ),
          ),
        ),
      );

      // Half-hour time slots
      expect(find.text('08:00 AM'), findsOneWidget);
      expect(find.text('09:00 AM'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);

      // Booked cards
      expect(find.text('Emma Watson'), findsOneWidget);
      expect(find.text('BOOKED'), findsOneWidget);
      expect(find.text('IN SERVICE'), findsAtLeastNWidgets(1));

      // Tap on empty slot "Book Slot"
      await tester.tap(find.text('Book Slot').first);
      await tester.pumpAndSettle();
      expect(bookedSlot, isNotNull);
    });
  });

  group('AppointmentV2ScheduleViewport Coordinator Tests', () {
    testWidgets('Switches between List, Grid, and Time views seamlessly', (tester) async {
      String viewMode = 'list';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => viewMode = 'grid'),
                      child: const Text('To Grid'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => viewMode = 'time'),
                      child: const Text('To Time'),
                    ),
                    Expanded(
                      child: AppointmentV2ScheduleViewport(
                        isLoadingAppts: false,
                        viewMode: viewMode,
                        selectedStaff: testStaff,
                        selectedDate: '2026-10-15',
                        appointments: sampleAppointments,
                        onStartService: (_) {},
                        onContinueService: (_) {},
                        onOpenDetailsModal: (_) {},
                        onOpenAddModal: (_) {},
                        onSelectToday: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially in List mode
      expect(find.byType(V2ListView), findsOneWidget);
      expect(find.byType(V2GridView), findsNothing);

      // Switch to Grid mode
      await tester.tap(find.text('To Grid'));
      await tester.pumpAndSettle();
      expect(find.byType(V2GridView), findsOneWidget);
      expect(find.byType(V2ListView), findsNothing);

      // Switch to Time mode
      await tester.tap(find.text('To Time'));
      await tester.pumpAndSettle();
      expect(find.byType(V2TimeView), findsOneWidget);
      expect(find.byType(V2GridView), findsNothing);
    });

    testWidgets('Renders loading spinner when isLoadingAppts is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentV2ScheduleViewport(
              isLoadingAppts: true,
              viewMode: 'list',
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              appointments: const [],
              onStartService: (_) {},
              onContinueService: (_) {},
              onOpenDetailsModal: (_) {},
              onOpenAddModal: (_) {},
              onSelectToday: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule for Sarah Connor...'), findsOneWidget);
    });
  });
}

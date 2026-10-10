import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_calendar_sidebar.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_header.dart';

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

  group('AppointmentV2Header Widget Tests', () {
    testWidgets('Renders staff pill, date pill, view switcher, and buttons', (tester) async {
      String currentMode = 'list';
      bool addModalOpened = false;
      bool filterModalOpened = false;
      bool switchStaffTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentV2Header(
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              viewMode: currentMode,
              isLoadingAppts: false,
              onSwitchStaff: () => switchStaffTriggered = true,
              onViewModeChange: (m) => currentMode = m,
              onOpenFilterModal: () => filterModalOpened = true,
              onRefresh: () {},
              onOpenAddModal: () => addModalOpened = true,
              onSelectCustomerToBook: (_) {},
            ),
          ),
        ),
      );

      // Staff details
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Switch Staff'), findsOneWidget);

      // View mode options
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);

      // Action buttons
      expect(find.text('Slot Filter'), findsOneWidget);
      expect(find.text('Add Appointment'), findsOneWidget);

      // Tap Switch Staff
      await tester.tap(find.text('Switch Staff'));
      await tester.pumpAndSettle();
      expect(switchStaffTriggered, isTrue);

      // Tap Slot Filter
      await tester.tap(find.text('Slot Filter'));
      await tester.pumpAndSettle();
      expect(filterModalOpened, isTrue);

      // Tap Add Appointment
      await tester.tap(find.text('Add Appointment'));
      await tester.pumpAndSettle();
      expect(addModalOpened, isTrue);

      // Toggle to Grid mode
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(currentMode, 'grid');
    });
  });

  group('AppointmentV2CalendarSidebar Widget Tests', () {
    testWidgets('Renders monthly calendar, day stats summary, and staff card', (tester) async {
      String selectedDate = '2026-10-15';
      DateTime calendarViewDate = DateTime(2026, 10, 1);
      bool switchStaffCalled = false;

      final sampleAppts = [
        AppointmentModel(
          id: 101,
          businessId: 1,
          staffId: 1,
          staffName: 'Sarah Connor',
          customerId: 1,
          customerName: 'Emma Watson',
          appointmentDate: '2026-10-15',
          startTime: '09:00',
          endTime: '09:30',
          status: 'booked',
          totalAmount: 50.0,
        ),
        AppointmentModel(
          id: 102,
          businessId: 1,
          staffId: 1,
          staffName: 'Sarah Connor',
          customerId: 2,
          customerName: 'John Doe',
          appointmentDate: '2026-10-15',
          startTime: '10:00',
          endTime: '11:00',
          status: 'in_service',
          totalAmount: 120.0,
        ),
        AppointmentModel(
          id: 103,
          businessId: 1,
          staffId: 1,
          staffName: 'Sarah Connor',
          customerId: 3,
          customerName: 'Alice Green',
          appointmentDate: '2026-10-15',
          startTime: '14:00',
          endTime: '14:30',
          status: 'completed',
          totalAmount: 85.0,
        ),
      ];

      final dayStats = DayStats.fromAppointments(sampleAppts);

      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentV2CalendarSidebar(
              selectedStaff: testStaff,
              selectedDate: selectedDate,
              calendarViewDate: calendarViewDate,
              appointments: sampleAppts,
              dayStats: dayStats,
              onSelectDate: (d) => selectedDate = d,
              onChangeCalendarMonth: (m) => calendarViewDate = m,
              onSwitchStaff: () => switchStaffCalled = true,
            ),
          ),
        ),
      );

      // Month Title
      expect(find.text('October 2026'), findsOneWidget);

      // Weekdays
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('Tu'), findsOneWidget);

      // Stats Cards
      expect(find.text('TOTAL APPTS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stat_total_appts')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      expect(find.text('BOOKED'), findsOneWidget);
      expect(find.text('1'), findsAtLeastNWidgets(1)); // 1 booked, 1 in service, 1 completed

      expect(find.text('IN SERVICE'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('NO SHOW'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);

      // Active Staff Profile Card
      expect(find.text('Senior Stylist'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(switchStaffCalled, isTrue);
    });
  });
}

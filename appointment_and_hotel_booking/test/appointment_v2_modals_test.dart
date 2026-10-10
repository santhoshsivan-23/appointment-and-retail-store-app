import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/add_appointment_v2_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/appointment_details_v2_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/time_slot_filter_modal.dart';

void main() {
  final testStaff = StaffModel(
    id: 1,
    businessId: 10,
    name: 'Sarah Connor',
    email: 'sarah@test.com',
    role: 'Senior Stylist',
  );

  final testAppt = AppointmentModel(
    id: 101,
    businessId: 10,
    staffId: 1,
    staffName: 'Sarah Connor',
    customerId: 5,
    customerName: 'John Doe',
    customerPhone: '555-123-4567',
    appointmentDate: '2026-10-15',
    startTime: '10:00',
    endTime: '11:00',
    status: 'booked',
    totalAmount: 75.0,
    notes: 'First time visit, prefer gentle shampoo',
    services: [
      {'product_id': 201, 'name': 'Haircut & Styling', 'price': 50.0, 'quantity': 1},
      {'product_id': 202, 'name': 'Beard Grooming', 'price': 25.0, 'quantity': 1},
    ],
  );

  final testSlots = generateBusinessSlots(openTime: '09:00', closeTime: '12:00', intervalMinutes: 30);

  Widget wrapWithScaffold(Widget child) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('AddAppointmentV2Modal Tests', () {
    testWidgets('Renders Add Appointment Modal fields and widgets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithScaffold(
          AddAppointmentV2Modal(
            staff: testStaff,
            defaultDate: '2026-10-15',
            existingAppointments: [testAppt],
            onClose: () {},
            onSuccess: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and staff info
      expect(find.text('Add Appointment'), findsOneWidget);
      expect(find.textContaining('Sarah Connor'), findsWidgets);

      // Check time selection and wheel pickers
      expect(find.text('START TIME'), findsOneWidget);
      expect(find.text('END TIME'), findsOneWidget);

      // Check customer section
      expect(find.text('Walk-in Guest'), findsOneWidget);
      expect(find.text('Registered Customer'), findsOneWidget);

      // Check notes and actions
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save Appointment'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Toggling Walk-in switches customer entry mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithScaffold(
          AddAppointmentV2Modal(
            staff: testStaff,
            defaultDate: '2026-10-15',
            existingAppointments: const [],
            onClose: () {},
            onSuccess: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default with no preselected customer, walk-in is true -> shows Name & Phone text fields
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Customer Name *'), findsOneWidget);

      // Tap the Registered Customer pill
      final registeredCustTab = find.text('Registered Customer');
      expect(registeredCustTab, findsOneWidget);
      await tester.tap(registeredCustTab);
      await tester.pumpAndSettle();

      // Now customer search input should be visible
      expect(find.text('Search by customer name or phone...'), findsOneWidget);
    });

    testWidgets('Shows error if walk-in customer name is empty on submit', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithScaffold(
          AddAppointmentV2Modal(
            staff: testStaff,
            defaultDate: '2026-10-15',
            existingAppointments: const [],
            onClose: () {},
            onSuccess: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save Appointment without filling customer name
      final saveBtn = find.text('Save Appointment');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error message should appear
      expect(find.text('Please enter walk-in customer name.'), findsOneWidget);
    });
  });

  group('TimeSlotFilterModal Tests', () {
    testWidgets('Renders all slots and status tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BusinessSlot? selectedSlot;
      bool closed = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          TimeSlotFilterModal(
            slots: testSlots,
            appointments: [testAppt], // 10:00-11:00 is booked
            onSelectSlot: (slot) => selectedSlot = slot,
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('30-Minute Time Slot Overview'), findsOneWidget);

      // Status Tabs
      expect(find.textContaining('All Slots'), findsOneWidget);
      expect(find.text('Available Only'), findsOneWidget);
      expect(find.text('Booked Only'), findsOneWidget);

      // Booked status indicator for 10:00 - 10:30 slot
      expect(find.text('Booked'), findsWidgets);

      // Tap on a slot
      final firstSlot = find.text(testSlots.first.label);
      expect(firstSlot, findsOneWidget);
      await tester.tap(firstSlot);
      await tester.pumpAndSettle();

      expect(selectedSlot, isNotNull);
      expect(closed, isTrue);
    });

    testWidgets('Filtering tabs switches visible slots', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithScaffold(
          TimeSlotFilterModal(
            slots: testSlots,
            appointments: [testAppt], // 10:00-11:00 is booked
            onSelectSlot: (_) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Booked Only'
      await tester.tap(find.text('Booked Only'));
      await tester.pumpAndSettle();

      // Available slots like 09:00 - 09:30 should not be visible now
      expect(find.text(testSlots.first.label), findsNothing);

      // Tap 'Available Only'
      await tester.tap(find.text('Available Only'));
      await tester.pumpAndSettle();

      expect(find.text(testSlots.first.label), findsOneWidget);
    });
  });

  group('AppointmentDetailsV2Modal Tests', () {
    testWidgets('Renders appointment details and handles actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool startServiceCalled = false;
      bool doneCalled = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          AppointmentDetailsV2Modal(
            appt: testAppt,
            onClose: () => doneCalled = true,
            onStartService: () => startServiceCalled = true,
            onContinueService: () {},
            onStatusChanged: (_) {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Booked'), findsWidgets);

      // Customer and staff details
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('555-123-4567'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('\$75.00'), findsWidgets);

      // Notes
      expect(find.text('First time visit, prefer gentle shampoo'), findsOneWidget);

      // Services list
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(find.text('Beard Grooming'), findsOneWidget);

      // Action buttons
      expect(find.text('Start Service'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Test Start Service action
      await tester.tap(find.text('Start Service'));
      await tester.pumpAndSettle();
      expect(startServiceCalled, isTrue);

      // Test Done button action
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(doneCalled, isTrue);
    });

    testWidgets('Delete appointment triggers confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool deleteCalled = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          AppointmentDetailsV2Modal(
            appt: testAppt,
            onClose: () {},
            onStartService: () {},
            onContinueService: () {},
            onStatusChanged: (_) {},
            onDelete: () => deleteCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog should pop up
      expect(find.text('Delete Appointment'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete this appointment for John Doe?'), findsOneWidget);

      // Confirm deletion
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });
  });
}

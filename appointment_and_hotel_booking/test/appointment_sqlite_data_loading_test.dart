import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/category_model.dart';
import 'package:appointment_and_hotel_booking/models/product_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/add_appointment_v2_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/appointment_details_v2_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_grid_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_list_view.dart';

void main() {
  final testStaff = StaffModel(
    id: 1,
    businessId: 10,
    name: 'Sarah Connor',
    email: 'sarah@test.com',
    role: 'Senior Stylist',
  );

  final testCategories = [
    CategoryModel(id: 1, businessId: 10, name: 'Hair Care', showInAppointment: true),
    CategoryModel(id: 2, businessId: 10, name: 'Skin Care', showInAppointment: true),
    CategoryModel(id: 3, businessId: 10, name: 'Retail Only', showInAppointment: false),
  ];

  final testProducts = [
    ProductModel(id: 101, businessId: 10, categoryId: 1, name: 'Haircut & Styling', price: 45.0, sku: 'HC-01'),
    ProductModel(id: 102, businessId: 10, categoryId: 1, name: 'Hair Coloring', price: 90.0, sku: 'HC-02'),
    ProductModel(id: 201, businessId: 10, categoryId: 2, name: 'Facial Treatment', price: 65.0, sku: 'FC-01'),
  ];

  final testAppointment = AppointmentModel(
    id: 99,
    businessId: 10,
    staffId: 1,
    staffName: 'Sarah Connor',
    customerId: 5,
    customerName: 'Alice Green',
    customerPhone: '555-111-2222',
    appointmentDate: '2026-10-15',
    startTime: '10:00',
    endTime: '11:00',
    status: 'booked',
    totalAmount: 45.0,
    services: [
      {'product_id': 101, 'name': 'Haircut & Styling', 'price': 45.0},
    ],
  );

  group('Appointment SQLite Data Loading & Display Tests', () {
    test('resolveServicesWithCategories matches services with SQLite categories', () {
      final summary = resolveServicesWithCategories(testAppointment, testProducts, testCategories);
      expect(summary, 'Haircut & Styling (Hair Care)');
    });

    test('resolveServicesWithCategories falls back gracefully when categories are null or empty', () {
      final summaryNoCats = resolveServicesWithCategories(testAppointment, testProducts, []);
      expect(summaryNoCats, 'Haircut & Styling');

      final emptyAppt = testAppointment.copyWith(services: []);
      final summaryEmpty = resolveServicesWithCategories(emptyAppt, testProducts, testCategories);
      expect(summaryEmpty, 'General Consultation / Service');
    });

    testWidgets('AddAppointmentV2Modal uses local SQLite categories and products for filtering', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddAppointmentV2Modal(
              staff: testStaff,
              defaultDate: '2026-10-15',
              existingAppointments: const [],
              categories: testCategories,
              products: testProducts,
              onClose: () {},
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify category chips loaded from SQLite (only those with showInAppointment = true)
      expect(find.text('All Items'), findsOneWidget);
      expect(find.text('Hair Care'), findsOneWidget);
      expect(find.text('Skin Care'), findsOneWidget);
      expect(find.text('Retail Only'), findsNothing); // showInAppointment == false

      // Verify products loaded from SQLite
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(find.text('Facial Treatment'), findsOneWidget);

      // Tap on 'Skin Care' category chip to filter
      await tester.ensureVisible(find.text('Skin Care'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skin Care'));
      await tester.pumpAndSettle();

      // Facial Treatment is under Skin Care, Haircut is not
      expect(find.text('Facial Treatment'), findsOneWidget);
      expect(find.text('Haircut & Styling'), findsNothing);
    });

    testWidgets('AppointmentDetailsV2Modal displays SQLite category badges on services', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentDetailsV2Modal(
              appt: testAppointment,
              categories: testCategories,
              products: testProducts,
              onClose: () {},
              onStartService: () {},
              onContinueService: () {},
              onStatusChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify service name and resolved SQLite category badge
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(find.text('Hair Care'), findsOneWidget);
    });

    testWidgets('V2GridView displays resolved SQLite categories in service summary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V2GridView(
              appointments: [testAppointment],
              selectedStaff: testStaff,
              selectedDate: '2026-10-15',
              categories: testCategories,
              products: testProducts,
              onOpenDetails: (_) {},
              onBookAppointment: () {},
              onGoToToday: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Green'), findsOneWidget);
      expect(find.text('Haircut & Styling (Hair Care)'), findsOneWidget);
    });

    testWidgets('V2ListView expanded panel displays resolved SQLite categories', (tester) async {
      int? expandedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return V2ListView(
                  appointments: [testAppointment],
                  selectedStaff: testStaff,
                  selectedDate: '2026-10-15',
                  expandedApptId: expandedId,
                  categories: testCategories,
                  products: testProducts,
                  onToggleExpand: (id) => setState(() => expandedId = (expandedId == id ? null : id)),
                  onStartService: (_) {},
                  onContinueService: (_) {},
                  onOpenDetails: (_) {},
                  onBookAppointment: () {},
                  onGoToToday: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Green'), findsOneWidget);

      // Expand accordion
      await tester.tap(find.text('Alice Green'));
      await tester.pumpAndSettle();

      // Service row in accordion displays SQLite category
      expect(find.text('Haircut & Styling (Hair Care)'), findsOneWidget);
    });
  });
}

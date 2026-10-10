import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/v2_staff_selection_view.dart';

void main() {
  final sampleStaff = [
    StaffModel(
      id: 1,
      businessId: 1,
      name: 'Alice Smith',
      role: 'Master Stylist',
      phone: '555-0101',
      colorCode: '#2563EB',
      isActive: true,
    ),
    StaffModel(
      id: 2,
      businessId: 1,
      name: 'Bob Jones',
      role: 'Color Specialist',
      phone: '555-0102',
      colorCode: '#7C3AED',
      isActive: false,
    ),
  ];

  testWidgets('V2StaffSelectionView renders header and staff cards', (tester) async {
    StaffModel? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2StaffSelectionView(
            staffList: sampleStaff,
            isLoading: false,
            onSelectStaff: (s) => selected = s,
            onRefresh: () {},
          ),
        ),
      ),
    );

    // Header elements
    expect(find.text('APPOINTMENT V2'), findsOneWidget);
    expect(find.text('Select Staff Member'), findsOneWidget);
    expect(find.text('2 Specialists'), findsOneWidget);

    // Staff names & roles
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Master Stylist'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Color Specialist'), findsOneWidget);

    // Active & Offline badges
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    // Tap first staff card
    await tester.tap(find.text('Alice Smith'));
    await tester.pumpAndSettle();

    expect(selected?.id, 1);
  });

  testWidgets('V2StaffSelectionView filters staff by search query', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2StaffSelectionView(
            staffList: sampleStaff,
            isLoading: false,
            onSelectStaff: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    );

    // Enter query 'Bob'
    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.pumpAndSettle();

    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Alice Smith'), findsNothing);
    expect(find.text('1 Specialist'), findsOneWidget);

    // Enter query matching none
    await tester.enterText(find.byType(TextField), 'UnknownStaff');
    await tester.pumpAndSettle();

    expect(find.text('No Staff Found'), findsOneWidget);
  });
}

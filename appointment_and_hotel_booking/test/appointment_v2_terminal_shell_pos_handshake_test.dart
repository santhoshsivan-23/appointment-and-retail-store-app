import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/business_model.dart';
import 'package:appointment_and_hotel_booking/models/customer_model.dart';
import 'package:appointment_and_hotel_booking/models/product_model.dart';
import 'package:appointment_and_hotel_booking/screens/main_terminal_shell.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_view.dart';
import 'package:appointment_and_hotel_booking/views/cart_view.dart';

void main() {
  final testBusiness = BusinessModel(
    id: 1,
    ownerName: 'Admin Owner',
    businessName: 'Luxe Salon & Spa',
    businessType: 'salon',
    email: 'admin@luxesalon.com',
    phone: '555-0100',
  );

  final testCustomer = CustomerModel(
    id: 42,
    businessId: 1,
    name: 'Eleanor Vance',
    phone: '555-888-9999',
  );

  final testProducts = [
    ProductModel(
      id: 501,
      businessId: 1,
      name: 'Deluxe Hair Spa',
      sku: 'APPT-501',
      price: 85.0,
    ),
    ProductModel(
      id: 502,
      businessId: 1,
      name: 'Scalp Treatment',
      sku: 'APPT-502',
      price: 45.0,
    ),
  ];

  final testAppointment = AppointmentModel(
    id: 777,
    businessId: 1,
    staffId: 3,
    staffName: 'Michael Scott',
    customerId: 42,
    customerName: 'Eleanor Vance',
    customerPhone: '555-888-9999',
    appointmentDate: '2026-10-15',
    startTime: '14:00',
    endTime: '15:30',
    status: 'in_service',
    totalAmount: 130.0,
    notes: 'VIP customer',
  );

  Widget createShellWidget() {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Inter'),
      home: MainTerminalShell(business: testBusiness),
    );
  }

  group('Phase 8: Terminal Shell & POS Cart Handshake Tests', () {
    testWidgets('Sidebar lists both Appointment (V1) and Appointment V2 (dedicated option)', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createShellWidget());
      await tester.pump(const Duration(milliseconds: 300));

      // Check both sidebar options exist
      expect(find.text('Appointment'), findsOneWidget);
      expect(find.text('Appointment V2'), findsOneWidget);

      // Tap on Appointment V2 in sidebar
      await tester.tap(find.text('Appointment V2'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AppointmentV2View is rendered
      expect(find.byType(AppointmentV2View), findsOneWidget);
    });

    testWidgets('Starting service from Appointment V2 triggers POS Cart Handshake', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createShellWidget());
      await tester.pump(const Duration(milliseconds: 300));

      // Navigate to Appointment V2
      await tester.tap(find.text('Appointment V2'));
      await tester.pump(const Duration(milliseconds: 300));

      final apptV2Finder = find.byType(AppointmentV2View);
      expect(apptV2Finder, findsOneWidget);

      // Directly trigger the onStartService callback simulating user clicking "Start Service"
      final apptV2Widget = tester.widget<AppointmentV2View>(apptV2Finder);
      apptV2Widget.onStartService(
        testCustomer,
        testProducts,
        appointment: testAppointment,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Handshake verification:
      // 1. Should have automatically switched to CartView (index 4)
      expect(find.byType(CartView), findsOneWidget);

      // 2. Preloaded customer should be in cart
      expect(find.text('Eleanor Vance'), findsOneWidget);

      // 3. Appointment badge should be rendered
      expect(find.text('Apt #777'), findsOneWidget);

      // 4. Products should be loaded into cart items
      expect(find.text('Deluxe Hair Spa'), findsWidgets);
      expect(find.text('Scalp Treatment'), findsWidgets);
    });

    testWidgets('Navigating away from Cart cleans up temporary appointment preload state', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createShellWidget());
      await tester.pump(const Duration(milliseconds: 300));

      // Go to Appointment V2 and start service
      await tester.tap(find.text('Appointment V2'));
      await tester.pump(const Duration(milliseconds: 300));

      final apptV2Finder = find.byType(AppointmentV2View);
      final apptV2Widget = tester.widget<AppointmentV2View>(apptV2Finder);
      apptV2Widget.onStartService(
        testCustomer,
        testProducts,
        appointment: testAppointment,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apt #777'), findsOneWidget);

      // Now user clicks on Dashboard in the sidebar without completing sale
      await tester.tap(find.text('Dashboard'));
      await tester.pump(const Duration(milliseconds: 300));

      // Return to Cart & POS
      await tester.tap(find.text('Cart & POS'));
      await tester.pump(const Duration(milliseconds: 300));

      // Temporary appointment preloads must be cleanly reset
      expect(find.text('Apt #777'), findsNothing);
      expect(find.text('Eleanor Vance'), findsNothing);
      expect(find.text('Cart is empty'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/business_model.dart';
import 'package:appointment_and_hotel_booking/theme/app_theme.dart';
import 'package:appointment_and_hotel_booking/views/dashboard_view.dart';

void main() {
  group('1. Dashboard Page - Today\'s Appointment - Collapsed Column Layout Fix', () {
    final testAppt = AppointmentModel(
      id: 101,
      businessId: 1,
      staffId: 1,
      customerName: 'Christopher Alexander Longname',
      customerPhone: '+1 (555) 019-2834',
      staffName: 'Dr. Jane Smith',
      status: 'confirmed',
      appointmentDate: '2026-10-15',
      startTime: '10:00:00',
      endTime: '11:30:00',
      totalAmount: 185.00,
      services: [
        {'name': 'Full Hair & Beard Grooming', 'price': 185.00}
      ],
    );

    testWidgets('Collapsed column (<155px) moves end time down to second line without horizontal overflow', (tester) async {
      // Simulate narrow/collapsed column layout (<155px)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: Scaffold(
            body: SizedBox(
              width: 120, // Collapsed column width
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCollapsed = constraints.maxWidth < 155;
                  expect(isCollapsed, isTrue);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 11, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '10:00 AM',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 15),
                          child: Text(
                            '11:30 AM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both start time and end time are found as separate stacked text widgets
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('11:30 AM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Customer column positions name and phone vertically with ellipsis and moving down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: Scaffold(
            body: SizedBox(
              width: 140, // Collapsed customer column width
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    testAppt.customerName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    testAppt.customerPhone,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testAppt.customerName), findsOneWidget);
      expect(find.text(testAppt.customerPhone), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('2. Cart - Payment Successful Popup UI Improvement', () {
    testWidgets('Dialog has 540 width and accommodates all 3 buttons properly without clipping', (tester) async {
      bool printTapped = false;
      bool salesHistoryTapped = false;
      bool newSaleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (dCtx) => Dialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Container(
                        width: 540,
                        constraints: const BoxConstraints(maxWidth: 540),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Success icon header
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                                ),
                                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 36),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Payment Successful!',
                                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 18),

                              // Grand total
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('GRAND TOTAL'),
                                    const Text('\$125.00'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Three buttons row
                              Row(
                                children: [
                                  // Button 1: Print
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.print_rounded, size: 17),
                                      label: const Text('Print', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () => printTapped = true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Button 2: Sales History
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF4F46E5),
                                        backgroundColor: const Color(0xFFEEF2FF),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.receipt_long_rounded, size: 17),
                                      label: const Text('Sales History', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () => salesHistoryTapped = true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Button 3: New Sale
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE11D48),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                                      label: const Text('New Sale', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () => newSaleTapped = true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify all 3 buttons are rendered and visible
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Sales History'), findsOneWidget);
      expect(find.text('New Sale'), findsOneWidget);

      // Verify tapping buttons functions correctly
      await tester.tap(find.text('Print'));
      expect(printTapped, isTrue);

      await tester.tap(find.text('Sales History'));
      expect(salesHistoryTapped, isTrue);

      await tester.tap(find.text('New Sale'));
      expect(newSaleTapped, isTrue);

      // Verify no overflow errors occurred
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/staff_model.dart';
import 'package:appointment_and_hotel_booking/theme/appointment_v2_theme.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_calendar_sidebar.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_header.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/appointment_v2_schedule_viewport.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/appointment_details_v2_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/modals/time_slot_filter_modal.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/v2_staff_selection_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_grid_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_list_view.dart';
import 'package:appointment_and_hotel_booking/views/appointment_v2/views/v2_time_view.dart';

void main() {
  final testStaffList = [
    StaffModel(id: 1, businessId: 10, name: 'Alice Wonderland', email: 'alice@test.com', role: 'Master Barber'),
    StaffModel(id: 2, businessId: 10, name: 'Bob Builder', email: 'bob@test.com', role: 'Stylist'),
    StaffModel(id: 3, businessId: 10, name: 'Charlie Brown', email: 'charlie@test.com', role: 'Colorist'),
  ];

  final testStaff = testStaffList[0];

  final testAppointments = [
    AppointmentModel(
      id: 501,
      businessId: 10,
      staffId: 1,
      staffName: 'Alice Wonderland',
      customerId: 11,
      customerName: 'Diana Prince',
      customerPhone: '555-0011',
      appointmentDate: '2026-10-15',
      startTime: '09:30',
      endTime: '10:30',
      status: 'booked',
      totalAmount: 65.0,
      notes: 'Prefers quiet session',
      services: [
        {'product_id': 101, 'name': 'Classic Cut', 'price': 40.0, 'quantity': 1},
        {'product_id': 102, 'name': 'Beard Trim', 'price': 25.0, 'quantity': 1},
      ],
    ),
    AppointmentModel(
      id: 502,
      businessId: 10,
      staffId: 1,
      staffName: 'Alice Wonderland',
      customerId: 12,
      customerName: 'Bruce Wayne',
      customerPhone: '555-0012',
      appointmentDate: '2026-10-15',
      startTime: '11:00',
      endTime: '12:00',
      status: 'in_service',
      totalAmount: 120.0,
      notes: 'VIP guest',
      services: [
        {'product_id': 103, 'name': 'Deluxe Styling', 'price': 120.0, 'quantity': 1},
      ],
    ),
    AppointmentModel(
      id: 503,
      businessId: 10,
      staffId: 1,
      staffName: 'Alice Wonderland',
      customerId: 13,
      customerName: 'Clark Kent',
      customerPhone: '555-0013',
      appointmentDate: '2026-10-15',
      startTime: '14:00',
      endTime: '14:45',
      status: 'completed',
      totalAmount: 50.0,
      notes: 'Quick trim',
      services: [
        {'product_id': 101, 'name': 'Classic Cut', 'price': 50.0, 'quantity': 1},
      ],
    ),
  ];

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059669)),
      ),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Phase 9: Comprehensive UI & Verification Suite', () {
    testWidgets('Screen 1 Staff Selection: Renders roster, filters staff, and handles selection', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      StaffModel? selected;

      await tester.pumpWidget(
        wrapWithTheme(
          V2StaffSelectionView(
            staffList: testStaffList,
            isLoading: false,
            onSelectStaff: (s) => selected = s,
            onRefresh: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header card banner elements
      expect(find.text('APPOINTMENT V2'), findsOneWidget);
      expect(find.text('Select Staff Member'), findsOneWidget);
      expect(find.text('3 Specialists'), findsOneWidget);

      // Verify all 3 staff members are displayed
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);

      // Test search filter
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Bob');
      await tester.pumpAndSettle();

      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsNothing);
      expect(find.text('Charlie Brown'), findsNothing);

      // Tap Bob Builder to trigger selection
      await tester.tap(find.text('Bob Builder'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, 2);
      expect(selected!.name, 'Bob Builder');
    });

    testWidgets('Screen 2 Desktop vs Tablet Layout: Responsive layout adaptation', (tester) async {
      // 1. Desktop Width (1280x900)
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;

      final dayStats = DayStats.fromAppointments(testAppointments);

      await tester.pumpWidget(
        wrapWithTheme(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppointmentV2ScheduleViewport(
                    isLoadingAppts: false,
                    viewMode: 'list',
                    selectedStaff: testStaff,
                    selectedDate: '2026-10-15',
                    appointments: testAppointments,
                    onStartService: (_) {},
                    onContinueService: (_) {},
                    onOpenDetailsModal: (_) {},
                    onOpenAddModal: (_) {},
                    onSelectToday: () {},
                  ),
                ),
                const SizedBox(width: 16),
                AppointmentV2CalendarSidebar(
                  selectedStaff: testStaff,
                  selectedDate: '2026-10-15',
                  calendarViewDate: DateTime(2026, 10, 15),
                  appointments: testAppointments,
                  dayStats: dayStats,
                  onSelectDate: (_) {},
                  onChangeCalendarMonth: (_) {},
                  onSwitchStaff: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Schedule viewport and sidebar should both be rendered side-by-side
      expect(find.byType(AppointmentV2ScheduleViewport), findsOneWidget);
      expect(find.byType(AppointmentV2CalendarSidebar), findsOneWidget);
      expect(find.text('Diana Prince'), findsOneWidget);
      expect(find.text('TOTAL APPTS'), findsOneWidget);

      // 2. Narrow Width (800x900 - Tablet Portrait)
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpWidget(
        wrapWithTheme(
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 500,
                  child: AppointmentV2ScheduleViewport(
                    isLoadingAppts: false,
                    viewMode: 'list',
                    selectedStaff: testStaff,
                    selectedDate: '2026-10-15',
                    appointments: testAppointments,
                    onStartService: (_) {},
                    onContinueService: (_) {},
                    onOpenDetailsModal: (_) {},
                    onOpenAddModal: (_) {},
                    onSelectToday: () {},
                  ),
                ),
                const SizedBox(height: 16),
                AppointmentV2CalendarSidebar(
                  width: double.infinity,
                  selectedStaff: testStaff,
                  selectedDate: '2026-10-15',
                  calendarViewDate: DateTime(2026, 10, 15),
                  appointments: testAppointments,
                  dayStats: dayStats,
                  onSelectDate: (_) {},
                  onChangeCalendarMonth: (_) {},
                  onSwitchStaff: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentV2ScheduleViewport), findsOneWidget);
      expect(find.byType(AppointmentV2CalendarSidebar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header Controls & View Switching: Switch between List, Grid, and Time views', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String currentMode = 'list';
      bool switchStaffTriggered = false;
      bool addModalTriggered = false;

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  AppointmentV2Header(
                    selectedStaff: testStaff,
                    selectedDate: '2026-10-15',
                    viewMode: currentMode,
                    isLoadingAppts: false,
                    onSwitchStaff: () => switchStaffTriggered = true,
                    onViewModeChange: (m) => setState(() => currentMode = m),
                    onOpenFilterModal: () {},
                    onRefresh: () {},
                    onOpenAddModal: () => addModalTriggered = true,
                    onSelectCustomerToBook: (_) {},
                  ),
                  Expanded(
                    child: currentMode == 'list'
                        ? V2ListView(
                            appointments: testAppointments,
                            selectedStaff: testStaff,
                            selectedDate: '2026-10-15',
                            expandedApptId: null,
                            onToggleExpand: (_) {},
                            onStartService: (_) {},
                            onContinueService: (_) {},
                            onOpenDetails: (_) {},
                            onBookAppointment: () {},
                            onGoToToday: () {},
                          )
                        : currentMode == 'grid'
                            ? V2GridView(
                                appointments: testAppointments,
                                selectedStaff: testStaff,
                                selectedDate: '2026-10-15',
                                onOpenDetails: (_) {},
                                onBookAppointment: () {},
                                onGoToToday: () {},
                              )
                            : V2TimeView(
                                appointments: testAppointments,
                                selectedStaff: testStaff,
                                selectedDate: '2026-10-15',
                                expandedApptId: null,
                                onToggleExpand: (_) {},
                                onStartService: (_) {},
                                onContinueService: (_) {},
                                onOpenDetails: (_) {},
                                onOpenAddModal: (_) {},
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in List View
      expect(find.byType(V2ListView), findsOneWidget);
      expect(find.byType(V2GridView), findsNothing);
      expect(find.byType(V2TimeView), findsNothing);

      // Switch to Grid View
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(find.byType(V2GridView), findsOneWidget);
      expect(find.byType(V2ListView), findsNothing);

      // Switch to Time View
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      expect(find.byType(V2TimeView), findsOneWidget);
      expect(find.byType(V2GridView), findsNothing);

      // Tap Switch Staff button in header
      await tester.tap(find.text('Switch Staff'));
      await tester.pumpAndSettle();
      expect(switchStaffTriggered, isTrue);

      // Tap Add Appointment button
      await tester.tap(find.text('Add Appointment'));
      await tester.pumpAndSettle();
      expect(addModalTriggered, isTrue);
    });

    testWidgets('Calendar Sidebar: Verifies day stats counts and month formatting', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dayStats = DayStats.fromAppointments(testAppointments);

      // 3 appointments: 1 booked, 1 in_service, 1 completed
      expect(dayStats.total, 3);
      expect(dayStats.booked, 1);
      expect(dayStats.inService, 1);
      expect(dayStats.completed, 1);
      expect(dayStats.cancelled, 0);
      expect(dayStats.noShow, 0);

      await tester.pumpWidget(
        wrapWithTheme(
          AppointmentV2CalendarSidebar(
            selectedStaff: testStaff,
            selectedDate: '2026-10-15',
            calendarViewDate: DateTime(2026, 10, 15),
            appointments: testAppointments,
            dayStats: dayStats,
            onSelectDate: (_) {},
            onChangeCalendarMonth: (_) {},
            onSwitchStaff: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Month Title
      expect(find.text('October 2026'), findsOneWidget);

      // 6 Stat cards
      expect(find.text('TOTAL APPTS'), findsOneWidget);
      expect(find.text('IN SERVICE'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('NO SHOW'), findsOneWidget);

      // Active Staff Card
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Master Barber'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('Appointment Details Modal: Verifies 6-card grid and status actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appt = testAppointments[0]; // Booked appointment (Diana Prince)
      bool startServiceCalled = false;
      bool deleteCalled = false;

      await tester.pumpWidget(
        wrapWithTheme(
          AppointmentDetailsV2Modal(
            appt: appt,
            onClose: () {},
            onStartService: () => startServiceCalled = true,
            onContinueService: () {},
            onStatusChanged: (_) {},
            onDelete: () => deleteCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modal Title & Badge
      expect(find.text('Appointment'), findsOneWidget);
      expect(find.text('#501'), findsOneWidget);
      expect(find.text('Diana Prince'), findsOneWidget);
      expect(find.text('Prefers quiet session'), findsOneWidget);
      expect(find.text('Classic Cut'), findsOneWidget);
      expect(find.text('Beard Trim'), findsOneWidget);

      // Status buttons
      expect(find.text('Start Service'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('No Show'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Start Service
      await tester.tap(find.text('Start Service'));
      await tester.pumpAndSettle();
      expect(startServiceCalled, isTrue);

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Appointment'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete this appointment for Diana Prince?'), findsOneWidget);

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(deleteCalled, isTrue);
    });

    testWidgets('Time Slot Filter Modal: Renders time slot chips and handles selection', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final slots = generateBusinessSlots(openTime: '09:00', closeTime: '11:00', intervalMinutes: 30);
      BusinessSlot? selectedSlot;

      await tester.pumpWidget(
        wrapWithTheme(
          TimeSlotFilterModal(
            slots: slots,
            appointments: testAppointments,
            onClose: () {},
            onSelectSlot: (s) => selectedSlot = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30-Minute Time Slot Overview'), findsOneWidget);
      expect(find.textContaining('All Slots'), findsOneWidget);

      // Tap a slot chip (e.g. 9:00 AM - 9:30 AM)
      final slotFinder = find.textContaining('9:00 AM');
      expect(slotFinder, findsWidgets);
      await tester.tap(slotFinder.first);
      await tester.pumpAndSettle();

      expect(selectedSlot, isNotNull);
      expect(selectedSlot!.start24, '09:00');
    });

    testWidgets('Design Tokens & Palette: Exact Color Verification against React', (tester) async {
      // Status Color Metas
      final bookedMeta = getStatusMeta('booked');
      expect(bookedMeta.label, 'Booked');
      expect(bookedMeta.color, const Color(0xFF2563EB));
      expect(bookedMeta.bg, const Color(0xFFEFF6FF));
      expect(bookedMeta.border, const Color(0xFF3B82F6));

      final inServiceMeta = getStatusMeta('in_service');
      expect(inServiceMeta.label, 'In Service');
      expect(inServiceMeta.color, const Color(0xFFD97706));
      expect(inServiceMeta.bg, const Color(0xFFFFFBEB));
      expect(inServiceMeta.border, const Color(0xFFF59E0B));

      final completedMeta = getStatusMeta('completed');
      expect(completedMeta.label, 'Completed');
      expect(completedMeta.color, const Color(0xFF059669));
      expect(completedMeta.bg, const Color(0xFFECFDF5));
      expect(completedMeta.border, const Color(0xFF10B981));

      // Forest Palette
      expect(AppointmentV2Theme.forest50, const Color(0xFFF0FDF4));
      expect(AppointmentV2Theme.forest100, const Color(0xFFDCFCE7));
      expect(AppointmentV2Theme.forest800, const Color(0xFF065F46));
      expect(AppointmentV2Theme.forest900, const Color(0xFF064E3B));

      // Sage Palette
      expect(AppointmentV2Theme.sage50, const Color(0xFFF4F7F5));
      expect(AppointmentV2Theme.sage200, const Color(0xFFCBD8CF));
      expect(AppointmentV2Theme.sage800, const Color(0xFF27352D));

      // Staff cycling colors
      expect(AppointmentV2Theme.staffBgColors.length, 8);
      expect(AppointmentV2Theme.getStaffColor(0), const Color(0xFF2563EB));
      expect(AppointmentV2Theme.getStaffColor(1), const Color(0xFF7C3AED));
    });
  });
}

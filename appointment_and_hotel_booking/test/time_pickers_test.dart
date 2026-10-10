import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/widgets/wheel_time_picker.dart';
import 'package:appointment_and_hotel_booking/widgets/clock_time_picker_modal.dart';

void main() {
  group('WheelTimePicker Widget Tests', () {
    testWidgets('WheelTimePicker renders label and formatted time', (tester) async {
      String selectedTime = '08:30';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WheelTimePicker(
              label: 'Start Time',
              value: selectedTime,
              onChange: (newTime) {
                selectedTime = newTime;
              },
            ),
          ),
        ),
      );

      // Label and formatted badge
      expect(find.text('START TIME'), findsOneWidget);
      expect(find.text('8:30 AM'), findsOneWidget);
    });

    testWidgets('WheelTimePicker supports 24-hour mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WheelTimePicker(
              label: 'Opening Hour',
              value: '14:45',
              timeFormat: '24',
              onChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('OPENING HOUR'), findsOneWidget);
      expect(find.text('14:45'), findsOneWidget);
      // In 24h mode, AM/PM shouldn't be rendered
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });
  });

  group('ClockTimePickerModal Widget Tests', () {
    testWidgets('ClockTimePickerModal renders properly with header and buttons', (tester) async {
      String? confirmedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClockTimePickerModal(
              initialTime24: '09:15',
              label: 'Select Start Time',
              onSelectTime: (t) => confirmedTime = t,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Select Start Time'), findsOneWidget);
      expect(find.text('09'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Confirm Time'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('Confirm Time'));
      await tester.pump();

      expect(confirmedTime, '09:15');
    });

    testWidgets('ClockTimePickerModal toggles AM/PM correctly', (tester) async {
      String? confirmedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClockTimePickerModal(
              initialTime24: '09:15',
              label: 'Select Time',
              onSelectTime: (t) => confirmedTime = t,
              onClose: () {},
            ),
          ),
        ),
      );

      // Tap PM button
      await tester.tap(find.byKey(const Key('clock_modal_pm_btn')), warnIfMissed: false);
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.text('Confirm Time'));
      await tester.pump();

      expect(confirmedTime, '21:15');
    });
  });
}

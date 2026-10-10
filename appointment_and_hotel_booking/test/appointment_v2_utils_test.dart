import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/utils/appointment_v2_utils.dart';

void main() {
  group('Appointment V2 Time Utilities', () {
    test('timeToMinutes converts HH:MM properly', () {
      expect(timeToMinutes('08:00'), 480);
      expect(timeToMinutes('08:30'), 510);
      expect(timeToMinutes('12:15'), 735);
      expect(timeToMinutes('20:00'), 1200);
      expect(timeToMinutes(''), 0);
    });

    test('minutesToTime24 converts minutes to HH:MM format', () {
      expect(minutesToTime24(480), '08:00');
      expect(minutesToTime24(510), '08:30');
      expect(minutesToTime24(735), '12:15');
      expect(minutesToTime24(1200), '20:00');
    });

    test('formatTime12 formats correctly', () {
      expect(formatTime12('08:00'), '8:00 AM');
      expect(formatTime12('12:00'), '12:00 PM');
      expect(formatTime12('13:30'), '1:30 PM');
      expect(formatTime12('00:00'), '12:00 AM');
      expect(formatTime12(''), '--:--');
    });

    test('formatTime12Leading formats with zero padding', () {
      expect(formatTime12Leading('08:00'), '08:00 AM');
      expect(formatTime12Leading('12:00'), '12:00 PM');
      expect(formatTime12Leading('13:30'), '01:30 PM');
      expect(formatTime12Leading(''), '--:--');
    });

    test('formatTimeSlotLabel supports 12h and 24h', () {
      expect(formatTimeSlotLabel('08:00', '08:30', '12'), '8:00 AM – 8:30 AM');
      expect(formatTimeSlotLabel('08:00', '08:30', '24'), '08:00 – 08:30');
    });

    test('generateBusinessSlots creates proper 30-min intervals', () {
      final slots = generateBusinessSlots(openTime: '08:00', closeTime: '10:00', intervalMinutes: 30);
      expect(slots.length, 4);
      expect(slots[0].start24, '08:00');
      expect(slots[0].end24, '08:30');
      expect(slots[1].start24, '08:30');
      expect(slots[1].end24, '09:00');
      expect(slots[2].start24, '09:00');
      expect(slots[2].end24, '09:30');
      expect(slots[3].start24, '09:30');
      expect(slots[3].end24, '10:00');
    });

    test('generateTimePoints creates discrete intervals', () {
      final points = generateTimePoints(openTime: '08:00', closeTime: '09:30', stepMinutes: 30);
      expect(points.length, 4); // 08:00, 08:30, 09:00, 09:30
      expect(points.map((p) => p.time24).toList(), ['08:00', '08:30', '09:00', '09:30']);
    });
  });

  group('Appointment V2 Status Metadata', () {
    test('getStatusMeta correctly identifies status', () {
      expect(getStatusMeta('booked').key, 'booked');
      expect(getStatusMeta('in_service').key, 'in_service');
      expect(getStatusMeta('inservice').key, 'in_service');
      expect(getStatusMeta('completed').key, 'completed');
      expect(getStatusMeta('no_show').key, 'no_show');
      expect(getStatusMeta('noshow').key, 'no_show');
      expect(getStatusMeta('cancelled').key, 'cancelled');
      expect(getStatusMeta('canceled').key, 'cancelled');
      expect(getStatusMeta(null).key, 'booked');
      expect(getStatusMeta('unknown').key, 'booked');
    });
  });

  group('Appointment V2 Client Overlap Check', () {
    final existing = [
      AppointmentModel(
        id: 1,
        businessId: 1,
        staffId: 5,
        customerName: 'Alice',
        appointmentDate: '2026-10-09',
        startTime: '09:00',
        endTime: '10:00',
        status: 'booked',
      ),
      AppointmentModel(
        id: 2,
        businessId: 1,
        staffId: 5,
        customerName: 'Bob',
        appointmentDate: '2026-10-09',
        startTime: '10:00',
        endTime: '11:00',
        status: 'cancelled', // Cancelled shouldn't block
      ),
      AppointmentModel(
        id: 3,
        businessId: 1,
        staffId: 5,
        customerName: 'Charlie',
        appointmentDate: '2026-10-09',
        startTime: '11:00',
        endTime: '12:00',
        status: 'in_service',
      ),
    ];

    test('detects conflicting overlap within booked appointment', () {
      final res = checkClientOverlap(existing, '09:30', '10:30');
      expect(res.hasConflict, isTrue);
      expect(res.conflictingAppt?.id, 1);
    });

    test('no conflict for back-to-back adjacent slot', () {
      final res = checkClientOverlap(existing, '08:00', '09:00');
      expect(res.hasConflict, isFalse);
    });

    test('no conflict when overlapping with cancelled appointment', () {
      final res = checkClientOverlap(existing, '10:15', '10:45');
      expect(res.hasConflict, isFalse);
    });

    test('no conflict when excluding appointment id (e.g. edit mode)', () {
      final res = checkClientOverlap(existing, '09:00', '10:00', excludeId: 1);
      expect(res.hasConflict, isFalse);
    });
  });
}

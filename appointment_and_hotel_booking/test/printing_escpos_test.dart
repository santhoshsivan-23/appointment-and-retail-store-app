import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/models/printer_settings_model.dart';
import 'package:appointment_and_hotel_booking/models/sale_model.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/refund_model.dart';
import 'package:appointment_and_hotel_booking/printing/esc_pos.dart';

void main() {
  group('ESC/POS Command Builder Tests', () {
    test('buildEscPosTestPrint creates valid ESC/POS byte buffer', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'TEST SALON POS');
      final buffer = buildEscPosTestPrint(settings, testText: 'Test Printing');

      expect(buffer.isNotEmpty, isTrue);
      final textContent = String.fromCharCodes(buffer);
      expect(textContent.contains('TEST SALON POS'), isTrue);
      expect(textContent.contains('Test Printing'), isTrue);
      expect(textContent.contains('*** TEST PRINT COMPLETED ***'), isTrue);
    });

    test('buildEscPosReceipt formats sale with refunded items directly below original item', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'TEST SALON POS');

      final refundItem = RefundItemModel(
        productId: 101,
        productName: 'Shampoo Deluxe',
        unitPrice: 20.0,
        quantity: 1,
        totalDiscountReversed: 0.0,
        gstReversed: 1.6,
        refundAmount: 21.6,
      );

      final refundRecord = RefundRecordModel(
        id: 1,
        refundReceiptNumber: '#REF-2026-0001',
        totalRefundAmount: 21.6,
        subtotalRefunded: 20.0,
        gstReversedTotal: 1.6,
        items: [refundItem],
      );

      final sale = SaleModel(
        id: 99,
        customerName: 'John Doe',
        staffName: 'Alice',
        subtotal: 50.0,
        taxAmount: 4.0,
        totalAmount: 54.0,
        items: [
          {
            'product_id': 101,
            'product_name': 'Shampoo Deluxe',
            'unit_price': 20.0,
            'quantity': 2,
            'line_total': 40.0,
          },
          {
            'product_id': 102,
            'product_name': 'Hair Gel',
            'unit_price': 10.0,
            'quantity': 1,
            'line_total': 10.0,
          },
        ],
        refunds: [refundRecord],
        refundStatus: 'partial',
        refundedAmount: 21.6,
        gstReversedTotal: 1.6,
        netTaxAmount: 2.4,
        subtotalRefundedTotal: 20.0,
        netSubtotal: 30.0,
      );

      final buffer = buildEscPosReceipt(
        settings: settings,
        transaction: sale,
        isReprint: true,
      );

      expect(buffer.isNotEmpty, isTrue);
      final textContent = String.fromCharCodes(buffer);
      expect(textContent.contains('*** REPRINT RECEIPT ***'), isTrue);
      expect(textContent.contains('*** STATUS: PARTIALLY REFUNDED ***'), isTrue);
      expect(textContent.contains('Shampoo Deluxe'), isTrue);
      expect(textContent.contains('Refunded: 1x'), isTrue);
      expect(textContent.contains('TOTAL REFUNDED'), isTrue);
      expect(textContent.contains('NET AMOUNT PAID'), isTrue);
    });

    test('buildEscPosReceipt formats appointment receipt properly', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'TEST SALON POS');

      final apt = AppointmentModel(
        id: 42,
        businessId: 1,
        staffId: 10,
        customerName: 'Jane Smith',
        staffName: 'Bob Stylist',
        appointmentDate: '2026-10-15',
        startTime: '10:00',
        endTime: '11:00',
        subtotal: 100.0,
        taxAmount: 8.0,
        totalAmount: 108.0,
        services: [
          {
            'id': 201,
            'name': 'Haircut & Styling',
            'price': 100.0,
            'quantity': 1,
            'line_total': 100.0,
          }
        ],
      );

      final buffer = buildEscPosReceipt(
        settings: settings,
        transaction: apt,
        type: 'appointment',
        isReprint: false,
      );

      expect(buffer.isNotEmpty, isTrue);
      final textContent = String.fromCharCodes(buffer);
      expect(textContent.contains('Haircut & Styling'), isTrue);
      expect(textContent.contains('#APT-0042'), isTrue);
      expect(textContent.contains('Attendant: Bob Stylist'), isTrue);
      expect(textContent.contains('GRAND TOTAL'), isTrue);
    });
  });
}

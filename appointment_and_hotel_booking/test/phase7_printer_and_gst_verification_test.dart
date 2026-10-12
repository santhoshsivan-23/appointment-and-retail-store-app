import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appointment_and_hotel_booking/models/printer_settings_model.dart';
import 'package:appointment_and_hotel_booking/models/sale_model.dart';
import 'package:appointment_and_hotel_booking/models/appointment_model.dart';
import 'package:appointment_and_hotel_booking/models/refund_model.dart';
import 'package:appointment_and_hotel_booking/printing/esc_pos.dart';
import 'package:appointment_and_hotel_booking/printing/receipt_printer_service.dart';
import 'package:appointment_and_hotel_booking/printing/usb_printer.dart';

void main() {
  group('Phase 7 Verification: PrinterSettingsModel Tests', () {
    test('Default settings initializes with sane LAN parameters', () {
      final s = PrinterSettingsModel.defaultSettings(businessName: 'Luxe Salon & Spa');

      expect(s.businessName, equals('Luxe Salon & Spa'));
      expect(s.connectionType, equals('lan'));
      expect(s.ipAddress, equals('192.168.1.51'));
      expect(s.port, equals(9100));
      expect(s.paperSize, equals('mm80'));
      expect(s.isEnabled, isTrue);
      expect(s.orderReceiptEnabled, isTrue);
      expect(s.autoCut, isTrue);
      expect(s.openCashDrawer, isFalse);
    });

    test('JSON serialization & deserialization preserves all LAN and USB fields', () {
      final jsonMap = {
        'printer_name': 'Thermal Counter USB',
        'connection_type': 'usb',
        'usb_device_key': 'POS-80C',
        'usb_device_name': 'POS-80C (USB001)',
        'ip_address': '192.168.1.88',
        'port': 9100,
        'paper_size': 'mm58',
        'business_name': 'Beauty Studio',
        'phone_number': '+1 555 4321',
        'addr_line1': '123 Market St',
        'addr_line2': 'Suite 200',
        'addr_line3': 'Downtown',
        'addr_line4': 'GST: 12345678',
        'header_note': 'Welcome!',
        'footer_note': 'See you again soon!',
        'is_enabled': true,
        'order_receipt_enabled': true,
        'auto_cut': false,
        'open_cash_drawer': false,
      };

      final model = PrinterSettingsModel.fromJson(jsonMap);

      expect(model.printerName, equals('Thermal Counter USB'));
      expect(model.connectionType, equals('usb'));
      expect(model.usbDeviceKey, equals('POS-80C'));
      expect(model.usbDeviceName, equals('POS-80C (USB001)'));
      expect(model.paperSize, equals('mm58'));
      expect(model.autoCut, isFalse);
      expect(model.openCashDrawer, isFalse);

      final exported = model.toJson();
      expect(exported['connection_type'], equals('usb'));
      expect(exported['usb_device_key'], equals('POS-80C'));
      expect(exported['paper_size'], equals('mm58'));
      expect(exported['auto_cut'], isFalse);
      expect(exported['open_cash_drawer'], isFalse);
    });

    test('PrinterSettingsModel handles missing/null values safely', () {
      final model = PrinterSettingsModel.fromJson({});

      expect(model.connectionType, equals('lan'));
      expect(model.paperSize, equals('mm80'));
      expect(model.port, equals(9100));
      expect(model.isEnabled, isTrue);
      expect(model.orderReceiptEnabled, isTrue);
      expect(model.autoCut, isTrue);
      expect(model.openCashDrawer, isFalse);
    });
  });

  group('Phase 7 Verification: Sale & Appointment Reconciled Net GST Calculations', () {
    test('Sale without refunds maintains original subtotal and tax amounts', () {
      final sale = SaleModel(
        id: 10,
        customerName: 'Alice',
        subtotal: 100.0,
        taxAmount: 8.0,
        totalAmount: 108.0,
        items: [
          {'product_id': 1, 'product_name': 'Hair Gel', 'quantity': 2, 'unit_price': 50.0, 'line_total': 100.0}
        ],
      );

      expect(sale.netSubtotal, equals(100.0));
      expect(sale.netTaxAmount, equals(8.0));
      expect(sale.subtotalRefundedTotal, equals(0.0));
      expect(sale.gstReversedTotal, equals(0.0));
      expect(sale.refundedAmount, equals(0.0));
      expect(sale.refundStatus, equals('none'));
    });

    test('Sale with partial refund reconciles Net Subtotal and Net Tax (8% GST)', () {
      final refundItem = RefundItemModel(
        productId: 1,
        productName: 'Hair Gel',
        unitPrice: 50.0,
        quantity: 1,
        totalDiscountReversed: 0.0,
        gstReversed: 4.0,
        refundAmount: 54.0,
      );

      final refundRecord = RefundRecordModel(
        id: 1,
        refundReceiptNumber: '#REF-001',
        totalRefundAmount: 54.0,
        subtotalRefunded: 50.0,
        gstReversedTotal: 4.0,
        items: [refundItem],
      );

      final sale = SaleModel(
        id: 10,
        customerName: 'Alice',
        subtotal: 100.0,
        taxAmount: 8.0,
        totalAmount: 108.0,
        items: [
          {'product_id': 1, 'product_name': 'Hair Gel', 'quantity': 2, 'unit_price': 50.0, 'line_total': 100.0}
        ],
        refunds: [refundRecord],
        refundStatus: 'partial',
        refundedAmount: 54.0,
        subtotalRefundedTotal: 50.0,
        gstReversedTotal: 4.0,
        netSubtotal: 50.0,
        netTaxAmount: 4.0,
      );

      expect(sale.netSubtotal, equals(50.0));
      expect(sale.netTaxAmount, equals(4.0));
      expect(sale.subtotalRefundedTotal, equals(50.0));
      expect(sale.gstReversedTotal, equals(4.0));
      expect(sale.refundedAmount, equals(54.0));
      expect(sale.refundStatus, equals('partial'));
    });

    test('Sale with full refund reduces Net Subtotal and Net Tax to 0', () {
      final refundRecord = RefundRecordModel(
        id: 2,
        refundReceiptNumber: '#REF-002',
        totalRefundAmount: 108.0,
        subtotalRefunded: 100.0,
        gstReversedTotal: 8.0,
        items: [],
      );

      final sale = SaleModel(
        id: 10,
        customerName: 'Alice',
        subtotal: 100.0,
        taxAmount: 8.0,
        totalAmount: 108.0,
        refunds: [refundRecord],
        refundStatus: 'full',
        refundedAmount: 108.0,
        subtotalRefundedTotal: 100.0,
        gstReversedTotal: 8.0,
        netSubtotal: 0.0,
        netTaxAmount: 0.0,
      );

      expect(sale.netSubtotal, equals(0.0));
      expect(sale.netTaxAmount, equals(0.0));
      expect(sale.refundStatus, equals('full'));
    });

    test('AppointmentModel parses and reconciles net totals from JSON API response', () {
      final aptJson = {
        'id': 42,
        'business_id': 1,
        'customer_name': 'Clara Brown',
        'subtotal': 120.0,
        'tax_amount': 9.6,
        'total_amount': 129.6,
        'subtotal_refunded_total': 60.0,
        'gst_reversed_total': 4.8,
        'net_subtotal': 60.0,
        'net_tax_amount': 4.8,
        'refund_status': 'partial',
        'refunded_amount': 64.8,
        'services': [
          {'id': 1, 'name': 'Haircut', 'price': 60.0, 'quantity': 1},
          {'id': 2, 'name': 'Spa Treatment', 'price': 60.0, 'quantity': 1},
        ],
        'refunds': [
          {
            'id': 5,
            'refund_receipt_number': '#REF-APT-042',
            'subtotal_refunded': 60.0,
            'gst_reversed_total': 4.8,
            'total_refund_amount': 64.8,
            'items': [
              {'service_id': 2, 'service_name': 'Spa Treatment', 'quantity': 1, 'price': 60.0}
            ]
          }
        ]
      };

      final apt = AppointmentModel.fromJson(aptJson);

      expect(apt.id, equals(42));
      expect(apt.subtotal, equals(120.0));
      expect(apt.taxAmount, equals(9.6));
      expect(apt.totalAmount, equals(129.6));
      expect(apt.subtotalRefundedTotal, equals(60.0));
      expect(apt.gstReversedTotal, equals(4.8));
      expect(apt.netSubtotal, equals(60.0));
      expect(apt.netTaxAmount, equals(4.8));
      expect(apt.refundStatus, equals('partial'));
      expect(apt.refunds, isNotEmpty);
      expect(apt.refunds.length, equals(1));
    });
  });

  group('Phase 7 Verification: ESC/POS Builder Command Sequence & Layout Tests', () {
    test('ESC/POS Test Print generates expected control sequences', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'TEST SALON POS').copyWith(openCashDrawer: true);

      final buffer = buildEscPosTestPrint(settings, testText: 'Test Printing');
      expect(buffer.isNotEmpty, isTrue);

      // Verify ESC @ (Init printer: 0x1B, 0x40)
      expect(buffer[0], equals(0x1B));
      expect(buffer[1], equals(0x40));

      // Verify paper cut is present when autoCutReceipt is true: GS V B 0 (0x1D, 0x56, 0x42, 0x00)
      final hasCut = buffer.contains(0x1D) && buffer.contains(0x56);
      expect(hasCut, isTrue);

      // Verify cash drawer kick is present when openCashDrawer is true: ESC p 0 25 250 (0x1B, 0x70, 0x00, 0x19, 0xFA)
      final hasDrawerKick = buffer.contains(0x1B) && buffer.contains(0x70);
      expect(hasDrawerKick, isTrue);
    });

    test('ESC/POS Test Print omits cut and cash drawer when toggled off', () {
      final settings = PrinterSettingsModel(
        printerName: 'Basic Printer',
        connectionType: 'lan',
        ipAddress: '192.168.1.50',
        port: 9100,
        paperSize: 'mm80',
        businessName: 'No Drawer Salon',
        autoCut: false,
        openCashDrawer: false,
      );

      final buffer = buildEscPosTestPrint(settings, testText: 'Test Printing');

      // Verify cash drawer kick is omitted: 0x1B 0x70
      bool foundDrawerKick = false;
      for (int i = 0; i < buffer.length - 1; i++) {
        if (buffer[i] == 0x1B && buffer[i + 1] == 0x70) {
          foundDrawerKick = true;
          break;
        }
      }
      expect(foundDrawerKick, isFalse, reason: 'Cash drawer kick byte should not be emitted when disabled');

      // Verify paper cut is omitted: 0x1D 0x56
      bool foundCut = false;
      for (int i = 0; i < buffer.length - 1; i++) {
        if (buffer[i] == 0x1D && buffer[i + 1] == 0x56) {
          foundCut = true;
          break;
        }
      }
      expect(foundCut, isFalse, reason: 'Paper cut byte should not be emitted when disabled');
    });

    test('ESC/POS Receipt formats 80mm divider (48 chars) vs 58mm divider (32 chars)', () {
      final settings80 = PrinterSettingsModel.defaultSettings(businessName: 'SALON 80').copyWith(paperSize: 'mm80');
      final settings58 = PrinterSettingsModel.defaultSettings(businessName: 'SALON 58').copyWith(paperSize: 'mm58');

      final sale = SaleModel(
        id: 1,
        customerName: 'Sam',
        subtotal: 10.0,
        taxAmount: 0.8,
        totalAmount: 10.8,
        items: [
          {'product_name': 'Wax', 'quantity': 1, 'unit_price': 10.0, 'line_total': 10.0}
        ],
      );

      final text80 = String.fromCharCodes(buildEscPosReceipt(settings: settings80, transaction: sale));
      final text58 = String.fromCharCodes(buildEscPosReceipt(settings: settings58, transaction: sale));

      expect(text80.contains('-' * 48), isTrue, reason: '80mm should produce 48-char dividers');
      expect(text58.contains('-' * 32), isTrue, reason: '58mm should produce 32-char dividers');
    });

    test('ESC/POS Receipt prints refunded item directly below original line item', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'TEST SALON POS');

      final refundItem = RefundItemModel(
        productId: 50,
        productName: 'Organic Shampoo',
        unitPrice: 25.0,
        quantity: 1,
        totalDiscountReversed: 0.0,
        gstReversed: 2.0,
        refundAmount: 27.0,
      );

      final refundRecord = RefundRecordModel(
        id: 7,
        refundReceiptNumber: '#REF-007',
        totalRefundAmount: 27.0,
        subtotalRefunded: 25.0,
        gstReversedTotal: 2.0,
        items: [refundItem],
      );

      final sale = SaleModel(
        id: 55,
        customerName: 'Mark Doe',
        staffName: 'Clara',
        subtotal: 50.0,
        taxAmount: 4.0,
        totalAmount: 54.0,
        items: [
          {'product_id': 50, 'product_name': 'Organic Shampoo', 'quantity': 2, 'unit_price': 25.0, 'line_total': 50.0}
        ],
        refunds: [refundRecord],
        refundStatus: 'partial',
        refundedAmount: 27.0,
        subtotalRefundedTotal: 25.0,
        gstReversedTotal: 2.0,
        netSubtotal: 25.0,
        netTaxAmount: 2.0,
      );

      final buffer = buildEscPosReceipt(
        settings: settings,
        transaction: sale,
        isReprint: true,
      );

      final receipt = String.fromCharCodes(buffer);

      // Verify Reprint Banner
      expect(receipt.contains('*** REPRINT RECEIPT ***'), isTrue);
      expect(receipt.contains('*** STATUS: PARTIALLY REFUNDED ***'), isTrue);

      // Verify original line item and indented refund line
      expect(receipt.contains('Organic Shampoo'), isTrue);
      expect(receipt.contains('Refunded: 1x'), isTrue);

      // Verify position: 'Refunded: 1x' occurs AFTER 'Organic Shampoo'
      final originalPos = receipt.indexOf('Organic Shampoo');
      final refundPos = receipt.indexOf('Refunded: 1x');
      expect(refundPos > originalPos, isTrue);

      // Verify Totals and Net amounts
      expect(receipt.contains('Subtotal'), isTrue);
      expect(receipt.contains('Tax (8%)'), isTrue);
      expect(receipt.contains('TOTAL REFUNDED'), isTrue);
      expect(receipt.contains('NET AMOUNT PAID'), isTrue);
      expect(receipt.contains('27.00'), isTrue);
    });

    test('ESC/POS Appointment receipt renders service lines, attendant and appointment code', () {
      final settings = PrinterSettingsModel.defaultSettings(businessName: 'APPOINTMENT SALON');

      final apt = AppointmentModel(
        id: 77,
        businessId: 1,
        staffId: 10,
        customerName: 'Eleanor Vance',
        staffName: 'David Barber',
        appointmentDate: '2026-10-20',
        startTime: '14:00',
        endTime: '15:00',
        subtotal: 80.0,
        taxAmount: 6.4,
        totalAmount: 86.4,
        services: [
          {'id': 1, 'name': 'Beard Grooming', 'price': 30.0, 'quantity': 1, 'line_total': 30.0},
          {'id': 2, 'name': 'Hair Cut & Wash', 'price': 50.0, 'quantity': 1, 'line_total': 50.0},
        ],
      );

      final buffer = buildEscPosReceipt(
        settings: settings,
        transaction: apt,
        type: 'appointment',
        isReprint: false,
      );

      final receipt = String.fromCharCodes(buffer);

      expect(receipt.contains('#APT-0077'), isTrue);
      expect(receipt.contains('Attendant: David Barber'), isTrue);
      expect(receipt.contains('Beard Grooming'), isTrue);
      expect(receipt.contains('Hair Cut & Wash'), isTrue);
      expect(receipt.contains('86.40'), isTrue);
      expect(receipt.contains('*** REPRINT RECEIPT ***'), isFalse);
    });
  });

  group('Phase 7 Verification: Hardware & Windows Spooler Validation', () {
    test('getUsbPrinters() enumerates printers on host platform', () async {
      final printers = await getUsbPrinters();

      // On this Windows developer machine, printers are installed
      if (Platform.isWindows) {
        expect(printers, isNotEmpty, reason: 'Windows machine should have installed printers');
        final hasPos80 = printers.any((p) => p.deviceKey.contains('POS-80C'));
        expect(hasPos80, isTrue, reason: 'POS-80C printer should be detected on this host');
      }
    });
  });

  group('Phase 7 Verification: Printer Selection (LAN vs USB Isolation)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PrinterSettingsModel defaults to LAN but allows switching to USB', () {
      final s = PrinterSettingsModel.defaultSettings();
      expect(s.selectedPrinter, equals('lan'));
      expect(s.isLanSelected, isTrue);
      expect(s.isUsbSelected, isFalse);
      expect(s.effectiveTargetPrinter, equals('lan'));

      final usbSettings = s.copyWith(selectedPrinter: 'usb');
      expect(usbSettings.selectedPrinter, equals('usb'));
      expect(usbSettings.isUsbSelected, isTrue);
      expect(usbSettings.isLanSelected, isFalse);
      expect(usbSettings.effectiveTargetPrinter, equals('usb'));
    });

    test('PrinterSettingsModel preserves selected_printer in toJson and fromJson', () {
      final jsonMap = {
        'printer_name': 'Dual POS Setup',
        'connection_type': 'usb',
        'selected_printer': 'usb',
        'usb_device_key': 'POS-80C',
        'ip_address': '192.168.1.51',
        'port': 9100,
        'paper_size': 'mm80',
        'is_enabled': true,
        'order_receipt_enabled': true,
        'auto_cut': true,
        'open_cash_drawer': false,
      };

      final model = PrinterSettingsModel.fromJson(jsonMap);
      expect(model.selectedPrinter, equals('usb'));
      expect(model.isUsbSelected, isTrue);
      expect(model.isLanSelected, isFalse);

      final exported = model.toJson();
      expect(exported['selected_printer'], equals('usb'));
      expect(exported['connection_type'], equals('usb'));
    });

    test('ReceiptPrinterService synchronizes and stores selected printer type', () async {
      await ReceiptPrinterService.setSelectedPrinterType('lan');
      expect(ReceiptPrinterService.getSelectedPrinterTypeSync(), equals('lan'));
      expect(await ReceiptPrinterService.getSelectedPrinterType(), equals('lan'));

      await ReceiptPrinterService.setSelectedPrinterType('usb');
      expect(ReceiptPrinterService.getSelectedPrinterTypeSync(), equals('usb'));
      expect(await ReceiptPrinterService.getSelectedPrinterType(), equals('usb'));
    });
  });
}

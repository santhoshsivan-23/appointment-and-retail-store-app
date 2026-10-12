import 'dart:convert';
import 'dart:typed_data';

import '../models/printer_settings_model.dart';
import '../models/sale_model.dart';
import '../models/appointment_model.dart';
import '../models/refund_model.dart';

class EscPosPaperSize {
  static const String mm58 = 'mm58';
  static const String mm80 = 'mm80';
}

const Map<String, int> _charsPerLine = {
  EscPosPaperSize.mm58: 32,
  EscPosPaperSize.mm80: 48,
};

const int _esc = 0x1b;
const int _gs = 0x1d;

final Uint8List _init = Uint8List.fromList([_esc, 0x40]);
final Uint8List _leftMarginZero = Uint8List.fromList([_gs, 0x4c, 0x00, 0x00]);
final Uint8List _alignCenter = Uint8List.fromList([_esc, 0x61, 0x01]);
final Uint8List _alignLeft = Uint8List.fromList([_esc, 0x61, 0x00]);
final Uint8List _boldOn = Uint8List.fromList([_esc, 0x45, 0x01]);
final Uint8List _boldOff = Uint8List.fromList([_esc, 0x45, 0x00]);
final Uint8List _sizeDouble = Uint8List.fromList([_gs, 0x21, 0x11]);
final Uint8List _sizeNormal = Uint8List.fromList([_gs, 0x21, 0x00]);
final Uint8List _cut = Uint8List.fromList([_gs, 0x56, 0x41, 0x03]);
final Uint8List _cashDrawer = Uint8List.fromList([_esc, 0x70, 0x00, 0x19, 0xfa]);

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);

String formatMoney(num? amount) {
  final val = (amount == null || amount == 0) ? 0.0 : amount.toDouble();
  return '\$${val.toStringAsFixed(2)}';
}

String padLine(String left, String right, int width) {
  final space = (width - left.length - right.length) < 1
      ? 1
      : (width - left.length - right.length);
  return '$left${' ' * space}$right\n';
}

String itemRow(String qty, String name, String price, int width) {
  final priceWidth = 10;
  const qtyWidth = 5;
  final nameWidth = width - qtyWidth - priceWidth - 1;
  final qtyStr = _clip(qty.padRight(qtyWidth), qtyWidth);
  final nameStr = _clip(name, nameWidth).padRight(nameWidth);
  final priceStr = price.padLeft(priceWidth);
  return '$qtyStr$nameStr $priceStr\n';
}

String _two(int v) => v.toString().padLeft(2, '0');

String formatReceiptDate(DateTime dt) =>
    '${_two(dt.day)}/${_two(dt.month)}/${dt.year.toString().padLeft(4, '0')}';

String formatReceiptTime(DateTime dt) =>
    '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';

Uint8List _concat(List<Uint8List> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

/// Builds ESC/POS buffer for Test Print.
Uint8List buildEscPosTestPrint(
  PrinterSettingsModel settings, {
  String testText = 'Test Printing',
}) {
  final width = _charsPerLine[settings.paperSize] ?? _charsPerLine[EscPosPaperSize.mm80]!;
  final sep = _bytes('${'-' * width}\n');
  final parts = <Uint8List>[_init, _leftMarginZero];

  // Business Name
  final bizName = settings.businessName.trim();
  if (bizName.isNotEmpty) {
    parts.addAll([_alignCenter, _boldOn, _bytes('$bizName\n'), _boldOff]);
  }

  parts.add(sep);

  // Large Bold "Test Printing"
  parts.addAll([
    _alignCenter,
    _sizeDouble,
    _boldOn,
    _bytes('$testText\n'),
    _boldOff,
    _sizeNormal,
  ]);

  parts.add(sep);

  // Date & Time
  final now = DateTime.now();
  final dateLine = padLine('Date: ${formatReceiptDate(now)}', 'Time: ${formatReceiptTime(now)}', width);
  parts.addAll([_alignLeft, _bytes(dateLine), sep]);

  // Diagnostics
  parts.add(_bytes('Printer : ${settings.printerName}\n'));
  if (settings.connectionType == 'usb') {
    parts.add(_bytes('Conn    : USB (${settings.usbDeviceKey ?? settings.usbDeviceName ?? 'Direct'})\n'));
  } else {
    parts.add(_bytes('Conn    : LAN (${settings.ipAddress}:${settings.port})\n'));
  }
  parts.add(_bytes('Roll    : ${settings.paperSize == 'mm58' ? '58mm (32 Col)' : '80mm (48 Col)'}\n'));
  parts.add(_bytes('Status  : Printer Working Successfully\n'));
  parts.add(sep);

  // Footer
  parts.addAll([
    _alignCenter,
    _boldOn,
    _bytes('*** TEST PRINT COMPLETED ***\n'),
    _boldOff,
    _bytes('Powered by IQ POS\n\n\n\n\n'),
  ]);

  if (settings.autoCut) parts.add(_cut);
  if (settings.openCashDrawer) parts.add(_cashDrawer);

  return _concat(parts);
}

/// Builds complete Customer Order Receipt or Reprint ESC/POS buffer.
Uint8List buildEscPosReceipt({
  required PrinterSettingsModel settings,
  required dynamic transaction,
  bool isReprint = false,
  String? type,
}) {
  final width = _charsPerLine[settings.paperSize] ?? _charsPerLine[EscPosPaperSize.mm80]!;
  final sep = _bytes('${'-' * width}\n');
  final dsep = _bytes('${'=' * width}\n');

  final parts = <Uint8List>[_init, _leftMarginZero];

  // Normalize transaction properties
  final isAppointment = type == 'appointment' ||
      transaction is AppointmentModel ||
      (transaction is Map &&
          (transaction['appointment_date'] != null ||
              transaction['services'] != null ||
              (transaction['appointment_id'] != null && transaction['items'] == null)));

  // 1. Business Header (Centered)
  parts.add(_alignCenter);
  final storeName = settings.businessName.isNotEmpty ? settings.businessName : 'IQ RESTAURANT & POS';
  parts.addAll([_boldOn, _bytes('$storeName\n'), _boldOff]);

  final addrLines = [
    settings.addrLine1,
    settings.addrLine2,
    settings.addrLine3,
    settings.addrLine4,
    settings.phoneNumber.isNotEmpty ? 'Tel: ${settings.phoneNumber}' : '',
  ].where((s) => s.trim().isNotEmpty).toList();

  for (final line in addrLines) {
    parts.add(_bytes('$line\n'));
  }

  if (settings.headerNote.trim().isNotEmpty) {
    parts.addAll([_boldOn, _bytes('${settings.headerNote.trim()}\n'), _boldOff]);
  }

  // Reprint Banner
  final refundStatus = (transaction is SaleModel)
      ? transaction.refundStatus
      : (transaction is AppointmentModel)
          ? transaction.refundStatus
          : (transaction is Map)
              ? (transaction['refund_status'] ?? 'none').toString()
              : 'none';

  if (isReprint) {
    parts.add(sep);
    parts.addAll([_boldOn, _bytes('*** REPRINT RECEIPT ***\n'), _boldOff]);
    if (refundStatus == 'full') {
      parts.addAll([_boldOn, _bytes('*** STATUS: FULLY REFUNDED ***\n'), _boldOff]);
    } else if (refundStatus == 'partial') {
      parts.addAll([_boldOn, _bytes('*** STATUS: PARTIALLY REFUNDED ***\n'), _boldOff]);
    }
  }

  parts.add(sep);

  // 2. Receipt Meta Info
  parts.add(_alignLeft);
  DateTime dateObj = DateTime.now();
  String dateStr = '';
  String timeStr = '';

  if (isAppointment) {
    if (transaction is AppointmentModel) {
      dateStr = transaction.appointmentDate;
      timeStr = transaction.timeRange;
    } else if (transaction is Map) {
      dateStr = transaction['appointment_date']?.toString() ?? '';
      final start = transaction['start_time']?.toString() ?? '';
      final end = transaction['end_time']?.toString() ?? '';
      timeStr = end.isNotEmpty ? '$start - $end' : start;
    }
    if (dateStr.isEmpty) {
      dateStr = formatReceiptDate(dateObj);
      timeStr = formatReceiptTime(dateObj);
    }
  } else {
    if (transaction is SaleModel && transaction.createdAt != null) {
      dateObj = transaction.createdAt!;
    } else if (transaction is Map && transaction['created_at'] != null) {
      dateObj = DateTime.tryParse(transaction['created_at'].toString()) ?? DateTime.now();
    }
    dateStr = formatReceiptDate(dateObj);
    timeStr = formatReceiptTime(dateObj);
  }

  parts.add(_bytes(padLine('Date: $dateStr', timeStr.isNotEmpty ? 'Time: $timeStr' : '', width)));

  String receiptNo = '';
  String payMethod = 'CASH';
  String staffName = '';
  String customerName = '';
  String customerPhone = '';

  if (transaction is SaleModel) {
    receiptNo = transaction.receiptNumber;
    payMethod = transaction.paymentMethodLabel;
    staffName = transaction.staffName;
    customerName = transaction.customerName;
    customerPhone = transaction.customerPhone;
  } else if (transaction is AppointmentModel) {
    receiptNo = '#APT-${transaction.id.toString().padLeft(4, '0')}';
    payMethod = 'CASH';
    staffName = transaction.staffName;
    customerName = transaction.customerName;
    customerPhone = transaction.customerPhone;
  } else if (transaction is Map) {
    receiptNo = transaction['receipt_number']?.toString() ??
        (isAppointment
            ? '#APT-${(transaction['id'] ?? 0).toString().padLeft(4, '0')}'
            : '#REC-${(transaction['id'] ?? 0).toString().padLeft(4, '0')}');
    payMethod = (transaction['payment_method'] ?? 'CASH').toString().toUpperCase();
    staffName = transaction['staff_name']?.toString() ?? '';
    customerName = transaction['customer_name']?.toString() ?? '';
    customerPhone = transaction['customer_phone']?.toString() ?? '';
  }

  parts.add(_bytes(padLine('Receipt: $receiptNo', 'Pay: $payMethod', width)));

  if (staffName.isNotEmpty) {
    final role = isAppointment ? 'Attendant' : 'Cashier';
    parts.add(_bytes('$role: $staffName\n'));
  }
  if (customerName.isNotEmpty && customerName.toLowerCase() != 'walk-in') {
    final phoneSuffix = customerPhone.isNotEmpty ? ' ($customerPhone)' : '';
    parts.add(_bytes('Customer: $customerName$phoneSuffix\n'));
  }

  parts.add(sep);

  // 3. Item Column Headers
  parts.addAll([
    _boldOn,
    _bytes(itemRow('Qty', 'Item', 'Price', width)),
    _boldOff,
    sep,
  ]);

  // 4. Extract Items and Refunds
  final rawItems = <Map<String, dynamic>>[];
  if (transaction is SaleModel) {
    rawItems.addAll(transaction.items);
  } else if (transaction is AppointmentModel) {
    for (final s in transaction.services) {
      rawItems.add({
        'product_id': s['id'] ?? s['product_id'],
        'product_name': s['name'] ?? s['product_name'] ?? 'Service',
        'unit_price': s['price'] ?? s['unit_price'] ?? 0.0,
        'quantity': s['quantity'] ?? 1,
        'discount': s['discount'] ?? 0.0,
        'line_total': s['line_total'] ?? ((s['price'] ?? 0.0) * (s['quantity'] ?? 1)),
      });
    }
  } else if (transaction is Map) {
    final itemsList = transaction['items'] ?? transaction['services'];
    if (itemsList is List) {
      for (final it in itemsList) {
        if (it is Map) {
          rawItems.add(Map<String, dynamic>.from(it));
        }
      }
    }
  }

  final allRefunds = <RefundRecordModel>[];
  if (transaction is SaleModel) {
    allRefunds.addAll(transaction.refunds);
  } else if (transaction is AppointmentModel) {
    allRefunds.addAll(transaction.refunds);
  } else if (transaction is Map && transaction['refunds'] is List) {
    for (final rf in transaction['refunds']) {
      if (rf is Map) {
        allRefunds.add(RefundRecordModel.fromJson(Map<String, dynamic>.from(rf)));
      } else if (rf is RefundRecordModel) {
        allRefunds.add(rf);
      }
    }
  }

  for (final it in rawItems) {
    final qty = (it['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
    final lineTotal = (it['line_total'] as num?)?.toDouble() ?? (unitPrice * qty);
    final pName = (it['product_name'] ?? it['name'] ?? 'Item').toString();
    final discount = (it['discount'] as num?)?.toDouble() ?? 0.0;

    parts.add(_bytes(itemRow('${qty}x', pName, formatMoney(lineTotal), width)));

    if (qty > 1 || discount > 0) {
      var subDetail = '  @ ${formatMoney(unitPrice)}';
      if (discount > 0) {
        subDetail += ' (Disc: -${formatMoney(discount)})';
      }
      parts.add(_bytes('${_clip(subDetail, width)}\n'));
    }

    // Match refunds corresponding to this item
    final itKey = (it['product_id'] ?? it['id'] ?? pName).toString().toLowerCase();
    var itemRefundedQty = 0;

    for (final rf in allRefunds) {
      for (final rIt in rf.items) {
        final rKey = (rIt.productId ?? rIt.productName).toString().toLowerCase();
        final nameMatch = pName.trim().toLowerCase() == rIt.productName.trim().toLowerCase();
        if ((itKey.isNotEmpty && rKey.isNotEmpty && itKey == rKey) || nameMatch) {
          itemRefundedQty += rIt.quantity;
        }
      }
    }

    if (itemRefundedQty > 0) {
      parts.addAll([_boldOn, _bytes('  Refunded: ${itemRefundedQty}x\n'), _boldOff]);
    }
  }

  parts.add(sep);

  // 5. Financial Summary
  double totalAmount = 0.0;
  double refundedAmount = 0.0;
  double gstReversedTotal = 0.0;
  double netTaxAmount = 0.0;
  double subtotalRefundedTotal = 0.0;
  double netSubtotal = 0.0;
  double subtotal = 0.0;
  double itemDiscountTotal = 0.0;
  double overallDiscount = 0.0;
  double taxAmount = 0.0;
  double amountTendered = 0.0;
  double changeAmount = 0.0;

  if (transaction is SaleModel) {
    totalAmount = transaction.totalAmount;
    refundedAmount = transaction.refundedAmount;
    gstReversedTotal = transaction.gstReversedTotal;
    netTaxAmount = transaction.netTaxAmount;
    subtotalRefundedTotal = transaction.subtotalRefundedTotal;
    netSubtotal = transaction.netSubtotal;
    subtotal = transaction.subtotal;
    itemDiscountTotal = transaction.itemDiscountTotal;
    overallDiscount = transaction.overallDiscount;
    taxAmount = transaction.taxAmount;
    amountTendered = transaction.amountTendered;
    changeAmount = transaction.changeAmount;
  } else if (transaction is AppointmentModel) {
    totalAmount = transaction.totalAmount;
    refundedAmount = transaction.refundedAmount;
    gstReversedTotal = transaction.gstReversedTotal;
    netTaxAmount = transaction.netTaxAmount;
    subtotalRefundedTotal = transaction.subtotalRefundedTotal;
    netSubtotal = transaction.netSubtotal;
    subtotal = transaction.subtotal;
    taxAmount = transaction.taxAmount;
  } else if (transaction is Map) {
    totalAmount = (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
    refundedAmount = (transaction['refunded_amount'] as num?)?.toDouble() ??
        allRefunds.fold(0.0, (s, r) => s + r.totalRefundAmount);
    gstReversedTotal = (transaction['gst_reversed_total'] as num?)?.toDouble() ??
        allRefunds.fold(0.0, (s, r) => s + r.gstReversedTotal);
    subtotalRefundedTotal = (transaction['subtotal_refunded_total'] as num?)?.toDouble() ??
        allRefunds.fold(0.0, (s, r) => s + r.subtotalRefunded);
    subtotal = (transaction['subtotal'] as num?)?.toDouble() ?? totalAmount;
    taxAmount = (transaction['tax_amount'] as num?)?.toDouble() ?? 0.0;
    netTaxAmount = (transaction['net_tax_amount'] as num?)?.toDouble() ??
        ((taxAmount - gstReversedTotal).clamp(0.0, double.infinity));
    netSubtotal = (transaction['net_subtotal'] as num?)?.toDouble() ??
        ((subtotal - subtotalRefundedTotal).clamp(0.0, double.infinity));
    itemDiscountTotal = (transaction['item_discount_total'] as num?)?.toDouble() ?? 0.0;
    overallDiscount = (transaction['overall_discount'] as num?)?.toDouble() ?? 0.0;
    amountTendered = (transaction['amount_tendered'] as num?)?.toDouble() ?? 0.0;
    changeAmount = (transaction['change_amount'] as num?)?.toDouble() ?? 0.0;
  }

  // Display Subtotal (Net if refunded)
  final displaySubtotal = (refundedAmount > 0) ? netSubtotal : subtotal;
  parts.add(_bytes(padLine('Subtotal', formatMoney(displaySubtotal), width)));

  if (itemDiscountTotal > 0) {
    parts.add(_bytes(padLine('Item Discounts', '-${formatMoney(itemDiscountTotal)}', width)));
  }
  if (overallDiscount > 0) {
    parts.add(_bytes(padLine('Overall Discount', '-${formatMoney(overallDiscount)}', width)));
  }

  // Display Tax (Net if refunded)
  if (taxAmount > 0 || gstReversedTotal > 0) {
    final displayTax = (gstReversedTotal > 0) ? netTaxAmount : taxAmount;
    parts.add(_bytes(padLine('Tax (8%)', formatMoney(displayTax), width)));
  }

  parts.add(dsep);

  if (refundedAmount > 0) {
    parts.add(_bytes(padLine('Original Total', formatMoney(totalAmount), width)));
    parts.addAll([
      _boldOn,
      _bytes(padLine('TOTAL REFUNDED', '-${formatMoney(refundedAmount)}', width)),
      _boldOff,
      sep,
    ]);
    final netRetained = (totalAmount - refundedAmount).clamp(0.0, double.infinity);
    parts.addAll([
      _boldOn,
      _bytes(padLine('NET AMOUNT PAID', formatMoney(netRetained), width)),
      _boldOff,
    ]);
  } else {
    parts.addAll([
      _boldOn,
      _bytes(padLine('GRAND TOTAL', formatMoney(totalAmount), width)),
      _boldOff,
    ]);
  }

  if (payMethod == 'CASH' && amountTendered > 0) {
    parts.add(sep);
    parts.add(_bytes(padLine('Amount Tendered', formatMoney(amountTendered), width)));
    parts.add(_bytes(padLine('Change Due', formatMoney(changeAmount), width)));
  }

  parts.add(sep);

  // 6. Footer (Centered)
  parts.add(_alignCenter);
  final footerNote = settings.footerNote.isNotEmpty
      ? settings.footerNote
      : 'Thank you for your visit! Please come again.';
  parts.add(_bytes('$footerNote\n'));
  parts.add(_bytes('Powered by IQ POS\n\n\n\n'));

  // 7. Auto Cut
  if (settings.autoCut) {
    parts.add(_cut);
  }

  // 8. Cash Drawer Kick
  if (!isReprint && settings.openCashDrawer && payMethod == 'CASH') {
    parts.add(_cashDrawer);
  }

  return _concat(parts);
}

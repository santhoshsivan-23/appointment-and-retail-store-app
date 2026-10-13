import 'dart:math';

class RefundCalculationResult {
  final double subtotalRefunded;
  final double discountReversedTotal;
  final double gstReversedTotal;
  final double totalRefundAmount;
  final List<Map<String, dynamic>> items;
  final bool isFullyRefunded;
  final String refundType; // 'partial' | 'full'

  const RefundCalculationResult({
    required this.subtotalRefunded,
    required this.discountReversedTotal,
    required this.gstReversedTotal,
    required this.totalRefundAmount,
    required this.items,
    required this.isFullyRefunded,
    required this.refundType,
  });

  Map<String, dynamic> toMap() {
    return {
      'subtotal_refunded': subtotalRefunded,
      'discount_reversed_total': discountReversedTotal,
      'gst_reversed_total': gstReversedTotal,
      'total_refund_amount': totalRefundAmount,
      'items': items,
      'is_fully_refunded': isFullyRefunded,
      'refund_type': refundType,
    };
  }
}

class RefundEngine {
  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? defaultVal;
  }

  static int _toInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? defaultVal;
  }

  static double _round2(double val) {
    return (val * 100).round() / 100.0;
  }

  /// Calculates the itemized refund breakdown and reversals matching React refundEngine.ts
  static RefundCalculationResult calculateRefundDetails({
    required Map<String, dynamic> originalTransaction,
    required List<Map<String, dynamic>> refundItems,
    List<Map<String, dynamic>> existingRefunds = const [],
  }) {
    final Map<String, int> prevRefundedMap = {};
    double totalPrevRefundAmount = 0.0;

    for (final ref in existingRefunds) {
      totalPrevRefundAmount += _toDouble(ref['total_refund_amount']);
      final items = ref['items'];
      if (items is List) {
        for (final it in items) {
          if (it is Map) {
            final key = (it['product_id'] ?? it['product_name'] ?? it['name'] ?? '')
                .toString()
                .toLowerCase();
            if (key.isNotEmpty) {
              prevRefundedMap[key] = (prevRefundedMap[key] ?? 0) + _toInt(it['quantity']);
            }
          }
        }
      }
    }

    final rawOrigItems = originalTransaction['items'] ?? originalTransaction['services'] ?? [];
    final List<Map<String, dynamic>> origItems = [];
    if (rawOrigItems is List) {
      for (final item in rawOrigItems) {
        if (item is Map) {
          origItems.add(Map<String, dynamic>.from(item));
        }
      }
    }

    double origSubtotal = _toDouble(originalTransaction['subtotal']);
    if (origSubtotal <= 0.0 && origItems.isNotEmpty) {
      for (final it in origItems) {
        final unitPrice = _toDouble(it['unit_price'] ?? it['price']);
        final qty = _toInt(it['quantity'], 1);
        origSubtotal += unitPrice * qty;
      }
    }

    final double origItemDiscount = _toDouble(originalTransaction['item_discount_total']);
    final double origOverallDiscount = _toDouble(originalTransaction['overall_discount']);
    final double origTaxAmount = _toDouble(originalTransaction['tax_amount']);
    final double origTotalAmount = _toDouble(originalTransaction['total_amount']);

    final double netItemsTotal = max(0.0, origSubtotal - origItemDiscount);
    final double overallDiscountRatio =
        netItemsTotal > 0.0 ? origOverallDiscount / netItemsTotal : 0.0;
    final double origTaxable = max(0.0, netItemsTotal - origOverallDiscount);
    final double taxRate = origTaxable > 0.0
        ? origTaxAmount / origTaxable
        : (origTaxAmount > 0.0 ? 0.08 : 0.0);

    double subtotalRefunded = 0.0;
    double lineDiscountReversedTotal = 0.0;
    final List<Map<String, dynamic>> processedRefundItems = [];

    for (final reqItem in refundItems) {
      final int qtyToRefund = _toInt(reqItem['quantity']);
      if (qtyToRefund <= 0) continue;

      final reqProdId = reqItem['product_id']?.toString();
      final reqProdName = (reqItem['product_name'] ?? reqItem['name'] ?? '')
          .toString()
          .toLowerCase();

      Map<String, dynamic>? orig;
      for (final it in origItems) {
        final itId = (it['product_id'] ?? it['id'])?.toString();
        final itName = (it['product_name'] ?? it['name'] ?? '').toString().toLowerCase();

        if (reqProdId != null && reqProdId.isNotEmpty && itId == reqProdId) {
          orig = it;
          break;
        }
        if (reqProdName.isNotEmpty && itName == reqProdName) {
          orig = it;
          break;
        }
      }

      if (orig == null) {
        throw Exception(
          'Item "${reqItem['product_name'] ?? reqItem['product_id']}" not found in original transaction.',
        );
      }

      final int origQty = _toInt(orig['quantity'], 1);
      final double unitPrice = _toDouble(orig['unit_price'] ?? orig['price']);
      final double origLineDiscount = _toDouble(orig['discount'] ?? orig['item_discount']);

      final key = (orig['product_id'] ?? orig['id'] ?? orig['product_name'] ?? orig['name'] ?? '')
          .toString()
          .toLowerCase();
      final int prevQty = prevRefundedMap[key] ?? 0;
      final int maxRefundable = origQty - prevQty;

      if (qtyToRefund > maxRefundable) {
        final itemName = orig['product_name'] ?? orig['name'] ?? 'Item';
        throw Exception(
          'Cannot refund $qtyToRefund × "$itemName". Only $maxRefundable remaining.',
        );
      }

      final double itemBaseGross = qtyToRefund * unitPrice;
      final double unitLineDiscount = origQty > 0 ? origLineDiscount / origQty : 0.0;
      final double itemLineDiscountReversal = qtyToRefund * unitLineDiscount;
      final double itemNetBeforeOverall = max(0.0, itemBaseGross - itemLineDiscountReversal);

      final double itemOverallDiscountReversal =
          itemNetBeforeOverall * overallDiscountRatio;
      final double itemTaxable =
          max(0.0, itemNetBeforeOverall - itemOverallDiscountReversal);
      final double itemGstReversal = _round2(itemTaxable * taxRate);
      final double itemRefundTotal = _round2(itemTaxable + itemGstReversal);

      subtotalRefunded += itemBaseGross;
      lineDiscountReversedTotal += itemLineDiscountReversal;

      processedRefundItems.add({
        'product_id': orig['product_id'] ?? orig['id'],
        'product_name': orig['product_name'] ?? orig['name'] ?? 'Item',
        'unit_price': unitPrice,
        'quantity': qtyToRefund,
        'original_quantity': origQty,
        'previously_refunded': prevQty,
        'remaining_quantity': origQty - prevQty - qtyToRefund,
        'line_discount_reversed': _round2(itemLineDiscountReversal),
        'overall_discount_reversed': _round2(itemOverallDiscountReversal),
        'total_discount_reversed':
            _round2(itemLineDiscountReversal + itemOverallDiscountReversal),
        'gst_reversed': itemGstReversal,
        'refund_amount': itemRefundTotal,
      });
    }

    if (processedRefundItems.isEmpty) {
      throw Exception('Please select at least one item and quantity to refund.');
    }

    final double selectedNetLineSum =
        max(0.0, subtotalRefunded - lineDiscountReversedTotal);
    final double overallDiscountReversedTotal =
        selectedNetLineSum * overallDiscountRatio;
    final double totalDiscountReversed =
        _round2(lineDiscountReversedTotal + overallDiscountReversedTotal);
    final double taxableRefund =
        max(0.0, selectedNetLineSum - overallDiscountReversedTotal);
    final double gstReversedTotal = _round2(taxableRefund * taxRate);
    double totalRefundAmount = _round2(taxableRefund + gstReversedTotal);

    // Check if this results in full refund of all items
    bool isAllItemsFullyRefunded = true;
    for (final orig in origItems) {
      final int origQty = _toInt(orig['quantity'], 1);
      final key = (orig['product_id'] ?? orig['id'] ?? orig['product_name'] ?? orig['name'] ?? '')
          .toString()
          .toLowerCase();
      final int prevQty = prevRefundedMap[key] ?? 0;

      int currentRefQty = 0;
      for (final p in processedRefundItems) {
        final pKey = (p['product_id'] ?? p['product_name'] ?? '').toString().toLowerCase();
        if (pKey == key) {
          currentRefQty = _toInt(p['quantity']);
          break;
        }
      }

      if (prevQty + currentRefQty < origQty) {
        isAllItemsFullyRefunded = false;
        break;
      }
    }

    if (isAllItemsFullyRefunded) {
      final double remainingPaidBalance =
          _round2(origTotalAmount - totalPrevRefundAmount);
      if (remainingPaidBalance > 0.0) {
        totalRefundAmount = remainingPaidBalance;
      }
    }

    // Strict boundary cap
    if (totalPrevRefundAmount + totalRefundAmount > origTotalAmount + 0.01) {
      totalRefundAmount = max(0.0, _round2(origTotalAmount - totalPrevRefundAmount));
    }

    return RefundCalculationResult(
      subtotalRefunded: _round2(subtotalRefunded),
      discountReversedTotal: totalDiscountReversed,
      gstReversedTotal: gstReversedTotal,
      totalRefundAmount: totalRefundAmount,
      items: processedRefundItems,
      isFullyRefunded: isAllItemsFullyRefunded,
      refundType: isAllItemsFullyRefunded ? 'full' : 'partial',
    );
  }
}

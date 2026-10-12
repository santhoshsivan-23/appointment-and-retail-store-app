import 'dart:convert';

class RefundItemModel {
  final dynamic productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final int originalQuantity;
  final int previouslyRefunded;
  final int remainingQuantity;
  final double lineDiscountReversed;
  final double overallDiscountReversed;
  final double totalDiscountReversed;
  final double gstReversed;
  final double refundAmount;

  RefundItemModel({
    this.productId,
    required this.productName,
    this.unitPrice = 0.0,
    required this.quantity,
    this.originalQuantity = 0,
    this.previouslyRefunded = 0,
    this.remainingQuantity = 0,
    this.lineDiscountReversed = 0.0,
    this.overallDiscountReversed = 0.0,
    this.totalDiscountReversed = 0.0,
    this.gstReversed = 0.0,
    this.refundAmount = 0.0,
  });

  factory RefundItemModel.fromJson(Map<String, dynamic> json) {
    return RefundItemModel(
      productId: json['product_id'],
      productName: (json['product_name'] ?? json['name'] ?? 'Item').toString(),
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      originalQuantity: int.tryParse(json['original_quantity']?.toString() ?? '0') ?? 0,
      previouslyRefunded: int.tryParse(json['previously_refunded']?.toString() ?? '0') ?? 0,
      remainingQuantity: int.tryParse(json['remaining_quantity']?.toString() ?? '0') ?? 0,
      lineDiscountReversed: double.tryParse(json['line_discount_reversed']?.toString() ?? '0') ?? 0.0,
      overallDiscountReversed: double.tryParse(json['overall_discount_reversed']?.toString() ?? '0') ?? 0.0,
      totalDiscountReversed: double.tryParse(json['total_discount_reversed']?.toString() ?? '0') ?? 0.0,
      gstReversed: double.tryParse(json['gst_reversed']?.toString() ?? '0') ?? 0.0,
      refundAmount: double.tryParse(json['refund_amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
      'original_quantity': originalQuantity,
      'previously_refunded': previouslyRefunded,
      'remaining_quantity': remainingQuantity,
      'line_discount_reversed': lineDiscountReversed,
      'overall_discount_reversed': overallDiscountReversed,
      'total_discount_reversed': totalDiscountReversed,
      'gst_reversed': gstReversed,
      'refund_amount': refundAmount,
    };
  }
}

class RefundRecordModel {
  final int id;
  final String refundReceiptNumber;
  final int businessId;
  final int? saleId;
  final int? appointmentId;
  final String refundType; // 'partial' or 'full'
  final double subtotalRefunded;
  final double discountReversedTotal;
  final double gstReversedTotal;
  final double totalRefundAmount;
  final String refundMethod;
  final String reason;
  final String notes;
  final List<RefundItemModel> items;
  final DateTime? createdAt;

  RefundRecordModel({
    required this.id,
    required this.refundReceiptNumber,
    this.businessId = 1,
    this.saleId,
    this.appointmentId,
    this.refundType = 'partial',
    this.subtotalRefunded = 0.0,
    this.discountReversedTotal = 0.0,
    this.gstReversedTotal = 0.0,
    required this.totalRefundAmount,
    this.refundMethod = 'cash',
    this.reason = '',
    this.notes = '',
    this.items = const [],
    this.createdAt,
  });

  factory RefundRecordModel.fromJson(Map<String, dynamic> json) {
    List<RefundItemModel> itemList = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        itemList = (json['items'] as List)
            .map((e) => RefundItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (json['items'] is String) {
        try {
          final decoded = jsonDecode(json['items']);
          if (decoded is List) {
            itemList = decoded
                .map((e) => RefundItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        } catch (_) {}
      }
    }

    return RefundRecordModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      refundReceiptNumber: (json['refund_receipt_number'] ?? '').toString(),
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      saleId: json['sale_id'] != null ? (json['sale_id'] is int ? json['sale_id'] : int.tryParse(json['sale_id'].toString())) : null,
      appointmentId: json['appointment_id'] != null ? (json['appointment_id'] is int ? json['appointment_id'] : int.tryParse(json['appointment_id'].toString())) : null,
      refundType: (json['refund_type'] ?? 'partial').toString(),
      subtotalRefunded: double.tryParse(json['subtotal_refunded']?.toString() ?? '0') ?? 0.0,
      discountReversedTotal: double.tryParse(json['discount_reversed_total']?.toString() ?? '0') ?? 0.0,
      gstReversedTotal: double.tryParse(json['gst_reversed_total']?.toString() ?? '0') ?? 0.0,
      totalRefundAmount: double.tryParse(json['total_refund_amount']?.toString() ?? '0') ?? 0.0,
      refundMethod: (json['refund_method'] ?? 'cash').toString(),
      reason: (json['reason'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      items: itemList,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'refund_receipt_number': refundReceiptNumber,
      'business_id': businessId,
      'sale_id': saleId,
      'appointment_id': appointmentId,
      'refund_type': refundType,
      'subtotal_refunded': subtotalRefunded,
      'discount_reversed_total': discountReversedTotal,
      'gst_reversed_total': gstReversedTotal,
      'total_refund_amount': totalRefundAmount,
      'refund_method': refundMethod,
      'reason': reason,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

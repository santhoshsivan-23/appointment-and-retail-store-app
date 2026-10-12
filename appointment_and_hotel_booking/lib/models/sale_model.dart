import 'dart:convert';
import 'refund_model.dart';

class SaleModel {
  final int id;
  final int businessId;
  final int? appointmentId;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final int? staffId;
  final String staffName;
  final double subtotal;
  final double itemDiscountTotal;
  final double overallDiscount;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod; // 'cash', 'card', 'qr', 'other'
  final double amountTendered;
  final double changeAmount;
  final List<Map<String, dynamic>> items;
  final String notes;
  final DateTime? createdAt;
  final String refundStatus; // 'none', 'partial', 'full'
  final double refundedAmount;
  final List<RefundRecordModel> refunds;
  final double gstReversedTotal;
  final double netTaxAmount;
  final double subtotalRefundedTotal;
  final double netSubtotal;

  SaleModel({
    required this.id,
    this.businessId = 1,
    this.appointmentId,
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.staffId,
    this.staffName = '',
    this.subtotal = 0.0,
    this.itemDiscountTotal = 0.0,
    this.overallDiscount = 0.0,
    this.taxAmount = 0.0,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.amountTendered = 0.0,
    this.changeAmount = 0.0,
    this.items = const [],
    this.notes = '',
    this.createdAt,
    this.refundStatus = 'none',
    this.refundedAmount = 0.0,
    this.refunds = const [],
    this.gstReversedTotal = 0.0,
    double? netTaxAmount,
    this.subtotalRefundedTotal = 0.0,
    double? netSubtotal,
  })  : netTaxAmount = netTaxAmount ??
            ((taxAmount - gstReversedTotal).clamp(0.0, double.infinity)),
        netSubtotal = netSubtotal ??
            ((subtotal - subtotalRefundedTotal).clamp(0.0, double.infinity));

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> itemList = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        itemList = (json['items'] as List)
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (json['items'] is String) {
        try {
          final decoded = jsonDecode(json['items']);
          if (decoded is List) {
            itemList = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        } catch (_) {}
      }
    }

    List<RefundRecordModel> refundList = [];
    if (json['refunds'] != null) {
      if (json['refunds'] is List) {
        refundList = (json['refunds'] as List)
            .map((e) => RefundRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (json['refunds'] is String) {
        try {
          final decoded = jsonDecode(json['refunds']);
          if (decoded is List) {
            refundList = decoded
                .map((e) => RefundRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        } catch (_) {}
      }
    }

    return SaleModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int
          ? json['business_id']
          : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      appointmentId: json['appointment_id'] != null
          ? (json['appointment_id'] is int
              ? json['appointment_id']
              : int.tryParse(json['appointment_id'].toString()))
          : null,
      customerId: json['customer_id'] != null
          ? (json['customer_id'] is int
              ? json['customer_id']
              : int.tryParse(json['customer_id'].toString()))
          : null,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      staffId: json['staff_id'] != null
          ? (json['staff_id'] is int
              ? json['staff_id']
              : int.tryParse(json['staff_id'].toString()))
          : null,
      staffName: json['staff_name'] ?? '',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      itemDiscountTotal:
          double.tryParse(json['item_discount_total']?.toString() ?? '0') ??
              0.0,
      overallDiscount:
          double.tryParse(json['overall_discount']?.toString() ?? '0') ?? 0.0,
      taxAmount:
          double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'cash',
      amountTendered:
          double.tryParse(json['amount_tendered']?.toString() ?? '0') ?? 0.0,
      changeAmount:
          double.tryParse(json['change_amount']?.toString() ?? '0') ?? 0.0,
      items: itemList,
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      refundStatus: (json['refund_status'] ?? 'none').toString(),
      refundedAmount: double.tryParse(json['refunded_amount']?.toString() ?? '0') ?? 0.0,
      refunds: refundList,
      gstReversedTotal: double.tryParse(json['gst_reversed_total']?.toString() ?? '') ??
          refundList.fold(0.0, (sum, r) => sum + r.gstReversedTotal),
      netTaxAmount: double.tryParse(json['net_tax_amount']?.toString() ?? '') ??
          ((double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0) -
                  (double.tryParse(json['gst_reversed_total']?.toString() ?? '') ??
                      refundList.fold(0.0, (sum, r) => sum + r.gstReversedTotal)))
              .clamp(0.0, double.infinity),
      subtotalRefundedTotal: double.tryParse(json['subtotal_refunded_total']?.toString() ?? '') ??
          refundList.fold(0.0, (sum, r) => sum + r.subtotalRefunded),
      netSubtotal: double.tryParse(json['net_subtotal']?.toString() ?? '') ??
          ((double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0) -
                  (double.tryParse(json['subtotal_refunded_total']?.toString() ?? '') ??
                      refundList.fold(0.0, (sum, r) => sum + r.subtotalRefunded)))
              .clamp(0.0, double.infinity),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'appointment_id': appointmentId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'staff_id': staffId,
      'staff_name': staffName,
      'subtotal': subtotal,
      'item_discount_total': itemDiscountTotal,
      'overall_discount': overallDiscount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'amount_tendered': amountTendered,
      'change_amount': changeAmount,
      'items': items,
      'notes': notes,
      'refund_status': refundStatus,
      'refunded_amount': refundedAmount,
      'refunds': refunds.map((e) => e.toJson()).toList(),
      'gst_reversed_total': gstReversedTotal,
      'net_tax_amount': netTaxAmount,
      'subtotal_refunded_total': subtotalRefundedTotal,
      'net_subtotal': netSubtotal,
    };
  }

  SaleModel copyWith({
    int? id,
    int? businessId,
    int? appointmentId,
    int? customerId,
    String? customerName,
    String? customerPhone,
    int? staffId,
    String? staffName,
    double? subtotal,
    double? itemDiscountTotal,
    double? overallDiscount,
    double? taxAmount,
    double? totalAmount,
    String? paymentMethod,
    double? amountTendered,
    double? changeAmount,
    List<Map<String, dynamic>>? items,
    String? notes,
    DateTime? createdAt,
    String? refundStatus,
    double? refundedAmount,
    List<RefundRecordModel>? refunds,
    double? gstReversedTotal,
    double? netTaxAmount,
    double? subtotalRefundedTotal,
    double? netSubtotal,
  }) {
    return SaleModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      appointmentId: appointmentId ?? this.appointmentId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      subtotal: subtotal ?? this.subtotal,
      itemDiscountTotal: itemDiscountTotal ?? this.itemDiscountTotal,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountTendered: amountTendered ?? this.amountTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      refundStatus: refundStatus ?? this.refundStatus,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      refunds: refunds ?? this.refunds,
      gstReversedTotal: gstReversedTotal ?? this.gstReversedTotal,
      netTaxAmount: netTaxAmount ?? this.netTaxAmount,
      subtotalRefundedTotal: subtotalRefundedTotal ?? this.subtotalRefundedTotal,
      netSubtotal: netSubtotal ?? this.netSubtotal,
    );
  }

  /// Receipt number format: #REC-YYYYMMDD-XXXX
  String get receiptNumber {
    final dt = createdAt ?? DateTime.now();
    final dateStr =
        '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    return '#REC-$dateStr-${id.toString().padLeft(4, '0')}';
  }

  /// Human-friendly payment method label
  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'CASH';
      case 'card':
        return 'CARD';
      case 'qr':
        return 'QR CODE';
      case 'other':
        return 'OTHER';
      default:
        return paymentMethod.toUpperCase();
    }
  }
}

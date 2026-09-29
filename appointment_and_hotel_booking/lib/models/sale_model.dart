import 'dart:convert';

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
  });

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
    };
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

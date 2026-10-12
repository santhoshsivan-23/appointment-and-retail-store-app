import 'dart:convert';
import 'refund_model.dart';

class AppointmentModel {
  final int id;
  final int businessId;
  final int staffId;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final String staffName;
  final String appointmentDate; // 'YYYY-MM-DD'
  final String startTime; // 'HH:MM'
  final String endTime; // 'HH:MM'
  final String status; // 'booked', 'in_service', 'completed', 'no_show', 'cancelled'
  final double totalAmount;
  final List<Map<String, dynamic>> services;
  final String notes;
  final DateTime? createdAt;
  final String refundStatus; // 'none', 'partial', 'full'
  final double refundedAmount;
  final List<RefundRecordModel> refunds;
  final double taxAmount;
  final double subtotal;
  final double gstReversedTotal;
  final double netTaxAmount;
  final double subtotalRefundedTotal;
  final double netSubtotal;

  AppointmentModel({
    required this.id,
    required this.businessId,
    required this.staffId,
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.staffName = '',
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    this.status = 'booked',
    this.totalAmount = 0.0,
    this.services = const [],
    this.notes = '',
    this.createdAt,
    this.refundStatus = 'none',
    this.refundedAmount = 0.0,
    this.refunds = const [],
    this.taxAmount = 0.0,
    this.subtotal = 0.0,
    this.gstReversedTotal = 0.0,
    double? netTaxAmount,
    this.subtotalRefundedTotal = 0.0,
    double? netSubtotal,
  })  : netTaxAmount = netTaxAmount ??
            ((taxAmount - gstReversedTotal).clamp(0.0, double.infinity)),
        netSubtotal = netSubtotal ??
            (((subtotal > 0 ? subtotal : totalAmount) - subtotalRefundedTotal).clamp(0.0, double.infinity));

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> svcList = [];
    if (json['services'] != null) {
      if (json['services'] is List) {
        svcList = (json['services'] as List)
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (json['services'] is String) {
        try {
          final decoded = jsonDecode(json['services']);
          if (decoded is List) {
            svcList = decoded
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

    return AppointmentModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int
          ? json['business_id']
          : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      staffId: json['staff_id'] is int
          ? json['staff_id']
          : int.tryParse(json['staff_id']?.toString() ?? '0') ?? 0,
      customerId: json['customer_id'] != null
          ? (json['customer_id'] is int
              ? json['customer_id']
              : int.tryParse(json['customer_id'].toString()))
          : null,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      staffName: json['staff_name'] ?? '',
      // Normalize appointment_date: MySQL DATE fields can arrive as ISO strings
      // like "2026-10-04T18:30:00.000Z". Convert to local date to ensure accurate 'YYYY-MM-DD'.
      appointmentDate: (() {
        final raw = (json['appointment_date'] ?? '').toString().trim();
        if (raw.contains('T')) {
          final dt = DateTime.tryParse(raw)?.toLocal();
          if (dt != null) {
            return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          }
          return raw.split('T')[0].trim();
        }
        return raw;
      })(),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: (() {
        final raw = (json['status'] ?? 'booked').toString().toLowerCase().trim().replaceAll('-', '_');
        if (raw == 'inservice') return 'in_service';
        if (raw == 'noshow') return 'no_show';
        if (raw == 'canceled') return 'cancelled';
        return raw;
      })(),
      totalAmount: json['total_amount'] != null
          ? (double.tryParse(json['total_amount'].toString()) ?? 0.0)
          : 0.0,
      services: svcList,
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      refundStatus: (json['refund_status'] ?? 'none').toString(),
      refundedAmount: double.tryParse(json['refunded_amount']?.toString() ?? '0') ?? 0.0,
      refunds: refundList,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ??
          (double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0),
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
          ((double.tryParse(json['subtotal']?.toString() ?? '') ??
                      (double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0)) -
                  (double.tryParse(json['subtotal_refunded_total']?.toString() ?? '') ??
                      refundList.fold(0.0, (sum, r) => sum + r.subtotalRefunded)))
              .clamp(0.0, double.infinity),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'staff_id': staffId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'appointment_date': appointmentDate,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'total_amount': totalAmount,
      'services': services,
      'notes': notes,
      'refund_status': refundStatus,
      'refunded_amount': refundedAmount,
      'refunds': refunds.map((e) => e.toJson()).toList(),
      'tax_amount': taxAmount,
      'subtotal': subtotal,
      'gst_reversed_total': gstReversedTotal,
      'net_tax_amount': netTaxAmount,
      'subtotal_refunded_total': subtotalRefundedTotal,
      'net_subtotal': netSubtotal,
    };
  }

  AppointmentModel copyWith({
    int? id,
    int? businessId,
    int? staffId,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? staffName,
    String? appointmentDate,
    String? startTime,
    String? endTime,
    String? status,
    double? totalAmount,
    List<Map<String, dynamic>>? services,
    String? notes,
    DateTime? createdAt,
    String? refundStatus,
    double? refundedAmount,
    List<RefundRecordModel>? refunds,
    double? taxAmount,
    double? subtotal,
    double? gstReversedTotal,
    double? netTaxAmount,
    double? subtotalRefundedTotal,
    double? netSubtotal,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      staffId: staffId ?? this.staffId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      staffName: staffName ?? this.staffName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      services: services ?? this.services,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      refundStatus: refundStatus ?? this.refundStatus,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      refunds: refunds ?? this.refunds,
      taxAmount: taxAmount ?? this.taxAmount,
      subtotal: subtotal ?? this.subtotal,
      gstReversedTotal: gstReversedTotal ?? this.gstReversedTotal,
      netTaxAmount: netTaxAmount ?? this.netTaxAmount,
      subtotalRefundedTotal: subtotalRefundedTotal ?? this.subtotalRefundedTotal,
      netSubtotal: netSubtotal ?? this.netSubtotal,
    );
  }

  /// Parse time string "HH:MM" or "HHMM" to total minutes from midnight
  int get startMinutes {
    final parts = startTime.split(':');
    if (parts.length >= 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    } else if (startTime.trim().length == 4) {
      final h = int.tryParse(startTime.trim().substring(0, 2)) ?? 0;
      final m = int.tryParse(startTime.trim().substring(2)) ?? 0;
      return h * 60 + m;
    }
    return 0;
  }

  int get endMinutes {
    final parts = endTime.split(':');
    if (parts.length >= 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    } else if (endTime.trim().length == 4) {
      final h = int.tryParse(endTime.trim().substring(0, 2)) ?? 0;
      final m = int.tryParse(endTime.trim().substring(2)) ?? 0;
      return h * 60 + m;
    }
    return 0;
  }

  int get durationMinutes => endMinutes - startMinutes;

  /// Formatted time range string
  String get timeRange => '$startTime - $endTime';

  /// Typed list of service items
  List<AppointmentServiceItem> get serviceItems =>
      services.map((s) => AppointmentServiceItem.fromMap(s)).toList();

  /// Comma-separated summary of service names
  String get servicesSummary {
    if (services.isEmpty) return 'General Consultation / Service';
    return services.map((s) => (s['name'] ?? s['product_name'] ?? 'Service').toString()).join(', ');
  }

  /// Status flags
  bool get isBooked => status == 'booked';
  bool get isInService => status == 'in_service';
  bool get isCompleted => status == 'completed';
  bool get isNoShow => status == 'no_show';
  bool get isCancelled => status == 'cancelled';

  /// User-friendly status label
  String get statusLabel {
    switch (status) {
      case 'booked':
        return 'BOOKED';
      case 'in_service':
        return 'IN SERVICE';
      case 'completed':
        return 'COMPLETED';
      case 'no_show':
        return 'NO-SHOW';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

}

/// Service item inside an appointment
class AppointmentServiceItem {
  final int? productId;
  final int? id;
  final String name;
  final double price;
  final int quantity;

  AppointmentServiceItem({
    this.productId,
    this.id,
    required this.name,
    this.price = 0.0,
    this.quantity = 1,
  });

  factory AppointmentServiceItem.fromMap(Map<String, dynamic> map) {
    return AppointmentServiceItem(
      productId: map['product_id'] is int
          ? map['product_id']
          : int.tryParse(map['product_id']?.toString() ?? ''),
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),
      name: (map['name'] ?? map['product_name'] ?? 'Service').toString(),
      price: map['price'] != null
          ? (double.tryParse(map['price'].toString()) ?? 0.0)
          : 0.0,
      quantity: map['quantity'] is int
          ? map['quantity']
          : (int.tryParse(map['quantity']?.toString() ?? '1') ?? 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'product_id': productId,
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

/// Conflicting appointment representation returned by server conflict check
class ConflictingAppointmentModel {
  final int id;
  final String customerName;
  final String startTime;
  final String endTime;
  final String status;

  ConflictingAppointmentModel({
    required this.id,
    required this.customerName,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory ConflictingAppointmentModel.fromJson(Map<String, dynamic> json) {
    return ConflictingAppointmentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      customerName: json['customer_name'] ?? 'Guest',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_name': customerName,
    'start_time': startTime,
    'end_time': endTime,
    'status': status,
  };
}

/// Result returned from conflict detection check
class CheckConflictResult {
  final bool hasConflict;
  final ConflictingAppointmentModel? conflictingAppointment;
  final String? message;

  CheckConflictResult({
    required this.hasConflict,
    this.conflictingAppointment,
    this.message,
  });

  factory CheckConflictResult.fromJson(Map<String, dynamic> json) {
    return CheckConflictResult(
      hasConflict: json['has_conflict'] == true || json['hasConflict'] == true,
      conflictingAppointment: json['conflicting_appointment'] != null
          ? ConflictingAppointmentModel.fromJson(
              Map<String, dynamic>.from(json['conflicting_appointment']),
            )
          : null,
      message: json['message']?.toString(),
    );
  }
}


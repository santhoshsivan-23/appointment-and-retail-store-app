class CustomerModel {
  final int id;
  final int businessId;
  final String name;
  final String phone;
  final String email;
  final bool isWalkIn;
  final String notes;
  final DateTime? createdAt;

  CustomerModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.email = '',
    this.isWalkIn = false,
    this.notes = '',
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      isWalkIn: json['is_walk_in'] == 1 || json['is_walk_in'] == true,
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'email': email,
      'is_walk_in': isWalkIn,
      'notes': notes,
    };
  }
}

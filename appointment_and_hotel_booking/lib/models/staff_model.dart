class StaffModel {
  final int id;
  final int businessId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String colorCode;
  final String? image;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  StaffModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.email = '',
    this.phone = '',
    this.role = 'Staff',
    this.colorCode = '#B42907',
    this.image,
    this.isActive = true,
    this.deletedAt,
    this.createdAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'Staff',
      colorCode: json['color_code'] ?? '#B42907',
      image: json['image']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'color_code': colorCode,
      if (image != null) 'image': image,
      'is_active': isActive,
    };
  }
}

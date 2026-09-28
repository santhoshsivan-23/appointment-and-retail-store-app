class BusinessModel {
  final int id;
  final String businessName;
  final String businessType;
  final String ownerName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;
  final String description;
  final DateTime? createdAt;

  BusinessModel({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.ownerName,
    required this.email,
    required this.phone,
    this.address = '',
    this.city = '',
    this.country = '',
    this.description = '',
    this.createdAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessName: json['business_name'] ?? json['businessName'] ?? '',
      businessType: json['business_type'] ?? json['businessType'] ?? '',
      ownerName: json['owner_name'] ?? json['ownerName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_name': businessName,
      'business_type': businessType,
      'owner_name': ownerName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'country': country,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class CategoryModel {
  final int id;
  final int businessId;
  final String name;
  final String description;
  final String icon;
  final int sortOrder;
  final bool showInAppointment;
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description = '',
    this.icon = 'category',
    this.sortOrder = 0,
    this.showInAppointment = true,
    this.isActive = true,
    this.isDeleted = false,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawShow = json['show_in_appointment'];
    final bool showInApt = rawShow == null
        ? true
        : (rawShow == 1 || rawShow == true || rawShow.toString() == 'true');

    final rawDeleted = json['is_deleted'];
    final bool isDel = rawDeleted == 1 || rawDeleted == true || rawDeleted.toString() == 'true';

    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'category',
      sortOrder: json['sort_order'] is int ? json['sort_order'] : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
      showInAppointment: showInApt,
      isActive: json['is_active'] == null ? true : (json['is_active'] == 1 || json['is_active'] == true || json['is_active'].toString() == 'true'),
      isDeleted: isDel,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'show_in_appointment': showInAppointment,
      'is_active': isActive,
      'is_deleted': isDeleted,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'show_in_appointment': showInAppointment ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

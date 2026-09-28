import 'dart:convert';

class ComboItem {
  final int productId;
  final int quantity;
  final String name;

  ComboItem({
    required this.productId,
    this.quantity = 1,
    this.name = '',
  });

  factory ComboItem.fromJson(Map<String, dynamic> json) {
    return ComboItem(
      productId: json['product_id'] is int ? json['product_id'] : int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'name': name,
  };
}

class ProductModel {
  final int id;
  final int businessId;
  final int? categoryId;
  final String name;
  final String sku;
  final String productType; // 'normal', 'modifier', 'combo'
  final double price;
  final String description;
  final List<int> modifiers;
  final List<ComboItem> comboItems;
  final bool isActive;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.businessId,
    this.categoryId,
    required this.name,
    this.sku = '',
    this.productType = 'normal',
    required this.price,
    this.description = '',
    this.modifiers = const [],
    this.comboItems = const [],
    this.isActive = true,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<int> mods = [];
    if (json['modifiers'] != null) {
      if (json['modifiers'] is List) {
        mods = (json['modifiers'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();
      } else if (json['modifiers'] is String) {
        try {
          final decoded = jsonDecode(json['modifiers']);
          if (decoded is List) {
            mods = decoded.map((e) => int.tryParse(e.toString()) ?? 0).toList();
          }
        } catch (_) {}
      }
    }

    List<ComboItem> combos = [];
    if (json['combo_items'] != null) {
      if (json['combo_items'] is List) {
        combos = (json['combo_items'] as List)
            .map((e) => e is Map<String, dynamic> ? ComboItem.fromJson(e) : ComboItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (json['combo_items'] is String) {
        try {
          final decoded = jsonDecode(json['combo_items']);
          if (decoded is List) {
            combos = decoded.map((e) => ComboItem.fromJson(Map<String, dynamic>.from(e))).toList();
          }
        } catch (_) {}
      }
    }

    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id']?.toString() ?? '1') ?? 1,
      categoryId: json['category_id'] != null ? (json['category_id'] is int ? json['category_id'] : int.tryParse(json['category_id'].toString())) : null,
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      productType: json['product_type'] ?? 'normal',
      price: json['price'] != null ? (double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
      description: json['description'] ?? '',
      modifiers: mods,
      comboItems: combos,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'product_type': productType,
      'price': price,
      'description': description,
      'modifiers': modifiers,
      'combo_items': comboItems.map((e) => e.toJson()).toList(),
      'is_active': isActive,
    };
  }
}

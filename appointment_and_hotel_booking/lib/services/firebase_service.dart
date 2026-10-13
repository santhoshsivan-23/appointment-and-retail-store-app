import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/appointment_model.dart';
import '../models/business_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/history_summary_model.dart';
import '../models/printer_settings_model.dart';
import '../models/product_model.dart';
import '../models/refund_model.dart';
import '../models/sale_model.dart';
import '../models/staff_model.dart';
import '../utils/refund_engine.dart';
import 'api_service.dart';
import 'auth_storage.dart';

class FirebaseService {
  static const String apiKey = "AIzaSyB0DwJoWwfCR7kU9zmJcizhEvdhqWXzQ0g";
  static const String projectId = "iq-appointment-booking";
  static const String firestoreBaseUrl =
      "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents";
  static const String identityBaseUrl =
      "https://identitytoolkit.googleapis.com/v1/accounts";

  // ---------------------------------------------------------------------------
  // FIRESTORE REST VALUE ENCODING / DECODING
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> encodeValue(dynamic val) {
    if (val == null) {
      return {'nullValue': null};
    } else if (val is bool) {
      return {'booleanValue': val};
    } else if (val is int) {
      return {'integerValue': val.toString()};
    } else if (val is double) {
      return {'doubleValue': val};
    } else if (val is num) {
      return {'doubleValue': val.toDouble()};
    } else if (val is String) {
      return {'stringValue': val};
    } else if (val is DateTime) {
      return {'stringValue': val.toIso8601String()};
    } else if (val is List) {
      if (val.isEmpty) {
        return {'arrayValue': <String, dynamic>{}};
      }
      return {
        'arrayValue': {
          'values': val.map((e) => encodeValue(e)).toList(),
        }
      };
    } else if (val is Map) {
      if (val.isEmpty) {
        return {'mapValue': <String, dynamic>{}};
      }
      final fields = <String, dynamic>{};
      val.forEach((k, v) {
        fields[k.toString()] = encodeValue(v);
      });
      return {
        'mapValue': {'fields': fields}
      };
    } else {
      return {'stringValue': val.toString()};
    }
  }

  static dynamic decodeValue(dynamic val) {
    if (val == null || val is! Map) return val;

    if (val.containsKey('nullValue')) return null;
    if (val.containsKey('stringValue')) return val['stringValue'];
    if (val.containsKey('booleanValue')) return val['booleanValue'] == true;
    if (val.containsKey('integerValue')) {
      return int.tryParse(val['integerValue'].toString()) ?? 0;
    }
    if (val.containsKey('doubleValue')) {
      final num? n = val['doubleValue'];
      return n?.toDouble() ?? 0.0;
    }
    if (val.containsKey('arrayValue')) {
      final values = val['arrayValue']?['values'];
      if (values is List) {
        return values.map((e) => decodeValue(e)).toList();
      }
      return <dynamic>[];
    }
    if (val.containsKey('mapValue')) {
      final fields = val['mapValue']?['fields'];
      if (fields is Map) {
        final res = <String, dynamic>{};
        fields.forEach((k, v) {
          res[k.toString()] = decodeValue(v);
        });
        return res;
      }
      return <String, dynamic>{};
    }

    return val;
  }

  static Map<String, dynamic> decodeDocument(Map<String, dynamic> docJson) {
    final fields = docJson['fields'];
    final res = <String, dynamic>{};

    // Extract doc ID from resource name if available
    final name = docJson['name']?.toString() ?? '';
    final lastSlash = name.lastIndexOf('/');
    final docId = lastSlash != -1 ? name.substring(lastSlash + 1) : '';

    if (fields is Map) {
      fields.forEach((k, v) {
        res[k.toString()] = decodeValue(v);
      });
    }

    if (!res.containsKey('id') || res['id'] == null || res['id'] == 0) {
      final parsedId = int.tryParse(docId);
      if (parsedId != null) {
        res['id'] = parsedId;
      }
    }

    return res;
  }

  // ---------------------------------------------------------------------------
  // ATOMIC SEQUENCE ID GENERATION ('counters/{collection}')
  // ---------------------------------------------------------------------------

  static Future<int> getNextSequenceId(String collectionName) async {
    final uri = Uri.parse('$firestoreBaseUrl/counters/$collectionName');
    try {
      final getRes = await http.get(uri).timeout(const Duration(seconds: 8));
      int current = 0;
      if (getRes.statusCode == 200) {
        final body = jsonDecode(getRes.body);
        final decoded = decodeDocument(body);
        current = int.tryParse(decoded['current']?.toString() ?? '0') ?? 0;
      }

      final nextId = current + 1;
      final patchUri = Uri.parse(
          '$firestoreBaseUrl/counters/$collectionName?updateMask.fieldPaths=current');

      final patchBody = {
        'fields': {
          'current': {'integerValue': nextId.toString()}
        }
      };

      await http
          .patch(
            patchUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(patchBody),
          )
          .timeout(const Duration(seconds: 8));

      return nextId;
    } catch (e) {
      debugPrint('Firestore atomic sequence fallback for $collectionName: $e');
      return (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 10000000;
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION (Firebase Identity Toolkit & Firestore businesses)
  // ---------------------------------------------------------------------------

  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    String? firebaseToken;
    String? authUid;

    // 1. Firebase Auth SignIn
    try {
      final signUri = Uri.parse('$identityBaseUrl:signInWithPassword?key=$apiKey');
      final signRes = await http.post(
        signUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      if (signRes.statusCode == 200) {
        final signBody = jsonDecode(signRes.body);
        firebaseToken = signBody['idToken'];
        authUid = signBody['localId'];
      } else {
        // If user not registered, attempt auto-signup matching React fallback
        final upUri = Uri.parse('$identityBaseUrl:signUp?key=$apiKey');
        final upRes = await http.post(
          upUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': cleanEmail,
            'password': password,
            'returnSecureToken': true,
          }),
        );
        if (upRes.statusCode == 200) {
          final upBody = jsonDecode(upRes.body);
          firebaseToken = upBody['idToken'];
          authUid = upBody['localId'];
        }
      }
    } catch (e) {
      debugPrint('Firebase Auth sign in notice: $e');
    }

    // 2. Fetch or create business in Firestore
    try {
      final bUri = Uri.parse('$firestoreBaseUrl/businesses?pageSize=100');
      final bRes = await http.get(bUri);

      BusinessModel? business;
      if (bRes.statusCode == 200) {
        final bBody = jsonDecode(bRes.body);
        final docs = bBody['documents'] as List? ?? [];
        for (final doc in docs) {
          final d = decodeDocument(Map<String, dynamic>.from(doc));
          if ((d['email']?.toString().toLowerCase().trim() ?? '') == cleanEmail) {
            business = BusinessModel.fromJson(d);
            break;
          }
        }
      }

      if (business == null) {
        final nextSeqId = await getNextSequenceId('businesses');
        final docKey = (authUid != null && authUid.isNotEmpty)
            ? authUid
            : nextSeqId.toString();

        final newBusinessDoc = {
          'id': nextSeqId,
          'business_name': 'IQ Store Terminal',
          'business_type': 'Store & POS',
          'owner_name': cleanEmail.split('@').first,
          'email': cleanEmail,
          'phone': '',
          'address': '',
          'city': '',
          'country': '',
          'description': '',
          'created_at': DateTime.now().toIso8601String(),
        };

        final fields = <String, dynamic>{};
        newBusinessDoc.forEach((k, v) => fields[k] = encodeValue(v));

        await http.patch(
          Uri.parse('$firestoreBaseUrl/businesses/$docKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fields': fields}),
        );

        business = BusinessModel.fromJson(newBusinessDoc);
      }

      final token = firebaseToken ?? 'fb_token_${DateTime.now().millisecondsSinceEpoch}_${business.id}';
      await AuthStorage.saveAuth(token: token, business: business);

      return ApiResponse(
        success: true,
        message: 'Login successful',
        data: business,
        token: token,
      );
    } catch (e) {
      debugPrint('Firestore login error: $e');
      return ApiResponse(
        success: false,
        message: 'Login failed: $e',
        statusCode: 400,
      );
    }
  }

  static Future<ApiResponse> register(Map<String, dynamic> businessData) async {
    final cleanEmail = (businessData['email'] ?? '').toString().trim().toLowerCase();
    final password = (businessData['password'] ?? '123456').toString();

    String? firebaseToken;
    String? authUid;

    try {
      final upUri = Uri.parse('$identityBaseUrl:signUp?key=$apiKey');
      final upRes = await http.post(
        upUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      if (upRes.statusCode == 200) {
        final upBody = jsonDecode(upRes.body);
        firebaseToken = upBody['idToken'];
        authUid = upBody['localId'];
      }
    } catch (e) {
      debugPrint('Firebase Auth register notice: $e');
    }

    try {
      final nextId = await getNextSequenceId('businesses');
      final docKey = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : nextId.toString();

      final newBusinessDoc = {
        'id': nextId,
        'business_name': (businessData['business_name'] ?? 'IQ Store').toString().trim(),
        'business_type': (businessData['business_type'] ?? 'Store & POS').toString().trim(),
        'owner_name': (businessData['owner_name'] ?? '').toString().trim(),
        'email': cleanEmail,
        'phone': (businessData['phone'] ?? '').toString().trim(),
        'address': (businessData['address'] ?? '').toString().trim(),
        'city': (businessData['city'] ?? '').toString().trim(),
        'country': (businessData['country'] ?? '').toString().trim(),
        'description': (businessData['description'] ?? '').toString().trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      newBusinessDoc.forEach((k, v) => fields[k] = encodeValue(v));

      await http.patch(
        Uri.parse('$firestoreBaseUrl/businesses/$docKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      final business = BusinessModel.fromJson(newBusinessDoc);
      final token = firebaseToken ?? 'fb_token_${DateTime.now().millisecondsSinceEpoch}_$nextId';
      await AuthStorage.saveAuth(token: token, business: business);

      return ApiResponse(
        success: true,
        message: 'Business registered successfully!',
        data: business,
        token: token,
      );
    } catch (e) {
      debugPrint('Firestore register error: $e');
      return ApiResponse(
        success: false,
        message: 'Registration failed: $e',
        statusCode: 400,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // STAFF MANAGEMENT
  // ---------------------------------------------------------------------------

  static Future<List<StaffModel>> getStaff({
    String search = '',
    bool includeDeleted = false,
  }) async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/staff?pageSize=200');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];
      final List<StaffModel> list = [];

      final q = search.trim().toLowerCase();

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        final isActive = d['is_active'] != false && d['deleted_at'] == null;
        if (!includeDeleted && !isActive) continue;

        final name = (d['name'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        final phone = (d['phone'] ?? '').toString().toLowerCase();
        final role = (d['role'] ?? '').toString().toLowerCase();

        if (q.isNotEmpty &&
            !name.contains(q) &&
            !email.contains(q) &&
            !phone.contains(q) &&
            !role.contains(q)) {
          continue;
        }

        list.add(StaffModel.fromJson(d));
      }

      list.sort((a, b) => a.id.compareTo(b.id));
      return list;
    } catch (e) {
      debugPrint('Error getting staff from Firestore: $e');
      return [];
    }
  }

  static Future<StaffModel?> getStaffById(int id) async {
    final all = await getStaff(includeDeleted: true);
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Future<bool> createStaff(Map<String, dynamic> data) async {
    try {
      final nextId = await getNextSequenceId('staff');
      final staffDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'name': (data['name'] ?? '').toString().trim(),
        'email': (data['email'] ?? '').toString().trim(),
        'phone': (data['phone'] ?? '').toString().trim(),
        'role': (data['role'] ?? 'Staff').toString().trim(),
        'color_code': (data['color_code'] ?? '#B42907').toString().trim(),
        'image': data['image'],
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      staffDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/staff/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating staff in Firestore: $e');
      return false;
    }
  }

  static Future<bool> updateStaff(int id, Map<String, dynamic> data) async {
    try {
      final fields = <String, dynamic>{};
      final updateMasks = <String>[];

      data.forEach((k, v) {
        if (k != 'id') {
          fields[k] = encodeValue(v);
          updateMasks.add('updateMask.fieldPaths=$k');
        }
      });

      final maskQuery = updateMasks.join('&');
      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/staff/$id?$maskQuery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating staff in Firestore: $e');
      return false;
    }
  }

  static Future<bool> deleteStaff(int id) async {
    return await updateStaff(id, {
      'is_active': false,
      'deleted_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // CUSTOMERS
  // ---------------------------------------------------------------------------

  static Future<List<CustomerModel>> getCustomers({String search = ''}) async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/customers?pageSize=200');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];
      final List<CustomerModel> list = [];

      final q = search.trim().toLowerCase();

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        final name = (d['name'] ?? '').toString().toLowerCase();
        final phone = (d['phone'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();

        if (q.isNotEmpty &&
            !name.contains(q) &&
            !phone.contains(q) &&
            !email.contains(q)) {
          continue;
        }

        list.add(CustomerModel.fromJson(d));
      }

      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    } catch (e) {
      debugPrint('Error getting customers from Firestore: $e');
      return [];
    }
  }

  static Future<CustomerModel?> createCustomer(Map<String, dynamic> data) async {
    try {
      final nextId = await getNextSequenceId('customers');
      final customerDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'name': (data['name'] ?? '').toString().trim(),
        'phone': (data['phone'] ?? '').toString().trim(),
        'email': (data['email'] ?? '').toString().trim(),
        'is_walk_in': data['is_walk_in'] == true,
        'notes': (data['notes'] ?? '').toString().trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      customerDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/customers/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      if (res.statusCode == 200) {
        return CustomerModel.fromJson(customerDoc);
      }
    } catch (e) {
      debugPrint('Error creating customer in Firestore: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  static Future<List<CategoryModel>> getCategories() async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/categories?pageSize=200');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];
      final List<CategoryModel> list = [];

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        if (d['is_deleted'] == true) continue;
        list.add(CategoryModel.fromJson(d));
      }

      list.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });
      return list;
    } catch (e) {
      debugPrint('Error getting categories from Firestore: $e');
      return [];
    }
  }

  static Future<bool> createCategory(Map<String, dynamic> data) async {
    try {
      final nextId = await getNextSequenceId('categories');
      final catDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'name': (data['name'] ?? '').toString().trim(),
        'description': (data['description'] ?? '').toString().trim(),
        'icon': (data['icon'] ?? 'category').toString().trim(),
        'sort_order': int.tryParse(data['sort_order']?.toString() ?? '0') ?? 0,
        'show_in_appointment': data['show_in_appointment'] != false,
        'is_active': true,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      catDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/categories/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating category in Firestore: $e');
      return false;
    }
  }

  static Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    try {
      final fields = <String, dynamic>{};
      final updateMasks = <String>[];

      data.forEach((k, v) {
        if (k != 'id') {
          fields[k] = encodeValue(v);
          updateMasks.add('updateMask.fieldPaths=$k');
        }
      });

      final maskQuery = updateMasks.join('&');
      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/categories/$id?$maskQuery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating category in Firestore: $e');
      return false;
    }
  }

  static Future<bool> deleteCategory(int id) async {
    return await updateCategory(id, {
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  static Future<List<ProductModel>> getProducts({
    int? categoryId,
    String? productType,
    String search = '',
  }) async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/products?pageSize=300');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];
      final List<ProductModel> list = [];

      final q = search.trim().toLowerCase();

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        if (d['is_deleted'] == true) continue;
        if (d['is_active'] == false) continue;

        if (categoryId != null && d['category_id']?.toString() != categoryId.toString()) {
          continue;
        }

        if (productType != null && productType.isNotEmpty && d['product_type'] != productType) {
          continue;
        }

        final name = (d['name'] ?? '').toString().toLowerCase();
        final sku = (d['sku'] ?? '').toString().toLowerCase();
        final desc = (d['description'] ?? '').toString().toLowerCase();

        if (q.isNotEmpty &&
            !name.contains(q) &&
            !sku.contains(q) &&
            !desc.contains(q)) {
          continue;
        }

        list.add(ProductModel.fromJson(d));
      }

      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    } catch (e) {
      debugPrint('Error getting products from Firestore: $e');
      return [];
    }
  }

  static Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      final nextId = await getNextSequenceId('products');
      final prodDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'category_id': data['category_id'] != null
            ? int.tryParse(data['category_id'].toString())
            : null,
        'name': (data['name'] ?? '').toString().trim(),
        'sku': (data['sku'] ?? '').toString().trim(),
        'product_type': (data['product_type'] ?? 'normal').toString(),
        'price': double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
        'description': (data['description'] ?? '').toString().trim(),
        'modifiers': data['modifiers'] is List ? data['modifiers'] : [],
        'combo_items': data['combo_items'] is List ? data['combo_items'] : [],
        'is_active': true,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      prodDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/products/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating product in Firestore: $e');
      return false;
    }
  }

  static Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      final fields = <String, dynamic>{};
      final updateMasks = <String>[];

      data.forEach((k, v) {
        if (k != 'id') {
          fields[k] = encodeValue(v);
          updateMasks.add('updateMask.fieldPaths=$k');
        }
      });

      final maskQuery = updateMasks.join('&');
      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/products/$id?$maskQuery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating product in Firestore: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(int id) async {
    return await updateProduct(id, {
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // REFUNDS IN-MEMORY MAPPER
  // ---------------------------------------------------------------------------

  static Future<List<RefundRecordModel>> getAllRefunds() async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/refunds?pageSize=300');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];
      final List<RefundRecordModel> list = [];

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        list.add(RefundRecordModel.fromJson(d));
      }

      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      return list;
    } catch (e) {
      debugPrint('Error getting refunds from Firestore: $e');
      return [];
    }
  }

  static Future<List<RefundRecordModel>> getAppointmentRefunds(int appointmentId) async {
    final all = await getAllRefunds();
    return all.where((r) => r.appointmentId == appointmentId).toList();
  }

  static Future<List<RefundRecordModel>> getSaleRefunds(int saleId) async {
    final all = await getAllRefunds();
    return all.where((r) => r.saleId == saleId).toList();
  }

  // ---------------------------------------------------------------------------
  // APPOINTMENTS
  // ---------------------------------------------------------------------------

  static Future<List<AppointmentModel>> getAppointments({
    String? date,
    String? startDate,
    String? endDate,
    int? staffId,
    String? search,
    String? status,
  }) async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/appointments?pageSize=300');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];

      // Fetch refunds once to map in memory
      final allRefunds = await getAllRefunds();
      final Map<int, List<RefundRecordModel>> refundsByAppt = {};
      for (final rf in allRefunds) {
        if (rf.appointmentId != null) {
          refundsByAppt.putIfAbsent(rf.appointmentId!, () => []).add(rf);
        }
      }

      List<AppointmentModel> list = [];
      final q = (search ?? '').trim().toLowerCase();
      final filterDate = date != null && date.isNotEmpty ? date.substring(0, min(10, date.length)) : null;
      final start = startDate != null && startDate.isNotEmpty ? startDate.substring(0, min(10, startDate.length)) : null;
      final end = endDate != null && endDate.isNotEmpty ? endDate.substring(0, min(10, endDate.length)) : null;

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
        final aRefunds = refundsByAppt[id] ?? [];

        final totalRefunded = aRefunds.fold<double>(0.0, (acc, r) => acc + r.totalRefundAmount);
        final totalGstRefunded = aRefunds.fold<double>(0.0, (acc, r) => acc + r.gstReversedTotal);
        final totalSubtotalRefunded = aRefunds.fold<double>(0.0, (acc, r) => acc + r.subtotalRefunded);

        final totalAmt = double.tryParse(d['total_amount']?.toString() ?? '0') ?? 0.0;
        final existingRefundStatus = (d['refund_status'] ?? '').toString();
        final resolvedStatus = existingRefundStatus.isNotEmpty && existingRefundStatus != 'none'
            ? existingRefundStatus
            : (aRefunds.isNotEmpty ? (totalRefunded >= totalAmt ? 'full' : 'partial') : 'none');

        d['refunds'] = aRefunds.map((e) => e.toJson()).toList();
        d['refunded_amount'] = double.tryParse(d['refunded_amount']?.toString() ?? '0') ?? totalRefunded;
        d['refund_status'] = resolvedStatus;
        d['gst_reversed_total'] = totalGstRefunded;
        d['subtotal_refunded_total'] = totalSubtotalRefunded;

        final appt = AppointmentModel.fromJson(d);

        // Date filtering
        final apptDate = appt.appointmentDate.length >= 10 ? appt.appointmentDate.substring(0, 10) : appt.appointmentDate;
        if (start != null && end != null) {
          if (apptDate.compareTo(start) < 0 || apptDate.compareTo(end) > 0) continue;
        } else if (start != null) {
          if (apptDate.compareTo(start) < 0) continue;
        } else if (end != null) {
          if (apptDate.compareTo(end) > 0) continue;
        } else if (filterDate != null) {
          if (apptDate != filterDate) continue;
        }

        // Staff filter
        if (staffId != null && appt.staffId != staffId) continue;

        // Status filter
        if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
          if (appt.status.toLowerCase() != status.toLowerCase()) continue;
        }

        // Search query
        if (q.isNotEmpty) {
          final cName = appt.customerName.toLowerCase();
          final cPhone = appt.customerPhone.toLowerCase();
          final sName = appt.staffName.toLowerCase();
          if (!cName.contains(q) && !cPhone.contains(q) && !sName.contains(q)) {
            continue;
          }
        }

        list.add(appt);
      }

      // Sorting matching React: single date sorts by startTime ASC; else date DESC then startTime DESC
      if (filterDate != null && end == null) {
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
      } else {
        list.sort((a, b) {
          final cmp = b.appointmentDate.compareTo(a.appointmentDate);
          return cmp != 0 ? cmp : b.startTime.compareTo(a.startTime);
        });
      }

      return list;
    } catch (e) {
      debugPrint('Error getting appointments from Firestore: $e');
      return [];
    }
  }

  static Future<PaginatedResult<AppointmentModel>> getAppointmentsPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final list = await getAppointments(
      startDate: startDate,
      endDate: endDate,
      search: search,
      status: status,
    );

    final total = list.length;
    final totalPages = (total / limit).ceil().clamp(1, 999999);
    final p = page.clamp(1, totalPages);
    final offset = (p - 1) * limit;
    final items = list.skip(offset).take(limit).toList();

    return PaginatedResult<AppointmentModel>(
      items: items,
      total: total,
      page: p,
      limit: limit,
      totalPages: totalPages,
    );
  }

  static Future<HistorySummaryModel> getAppointmentSummary({
    String? startDate,
    String? endDate,
    String? search,
    String? date,
  }) async {
    final list = await getAppointments(
      startDate: startDate,
      endDate: endDate,
      search: search,
      date: date,
    );

    final total = list.length;
    final completedList = list.where((a) {
      final s = a.status.toLowerCase();
      return s == 'completed' || s == 'performed';
    }).toList();

    final completed = completedList.length;
    final totalRevenue = completedList.fold<double>(0.0, (acc, a) => acc + a.totalAmount);

    return HistorySummaryModel(
      total: total,
      completed: completed,
      totalRevenue: (totalRevenue * 100).round() / 100.0,
    );
  }

  static Future<Map<String, int>> getAppointmentStats({String? date}) async {
    final list = await getAppointments(date: date);
    final stats = <String, int>{
      'total': list.length,
      'booked': 0,
      'in_service': 0,
      'completed': 0,
      'no_show': 0,
      'cancelled': 0,
    };

    for (final a in list) {
      final s = a.status.toLowerCase().trim();
      if (s == 'booked') {
        stats['booked'] = (stats['booked'] ?? 0) + 1;
      } else if (s == 'in_service' || s == 'inservice' || s == 'in-service') {
        stats['in_service'] = (stats['in_service'] ?? 0) + 1;
      } else if (s == 'completed') {
        stats['completed'] = (stats['completed'] ?? 0) + 1;
      } else if (s == 'no_show' || s == 'noshow' || s == 'no-show') {
        stats['no_show'] = (stats['no_show'] ?? 0) + 1;
      } else if (s == 'cancelled' || s == 'canceled') {
        stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
      }
    }

    return stats;
  }

  static Future<AppointmentModel?> getAppointmentById(int id) async {
    final all = await getAppointments();
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static int _timeToMinutes(String? t) {
    if (t == null || t.isEmpty) return 0;
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  static Future<CheckConflictResult> checkConflict({
    required int staffId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int? excludeId,
  }) async {
    final newStart = _timeToMinutes(startTime);
    final newEnd = _timeToMinutes(endTime);

    final appts = await getAppointments(
      date: appointmentDate,
      staffId: staffId,
    );

    final activeAppts = appts.where((a) {
      if (excludeId != null && a.id == excludeId) return false;
      return ['booked', 'in_service', 'completed'].contains(a.status.toLowerCase());
    });

    for (final a in activeAppts) {
      final aStart = _timeToMinutes(a.startTime);
      final aEnd = _timeToMinutes(a.endTime);
      if (newStart < aEnd && aStart < newEnd) {
        return CheckConflictResult(
          hasConflict: true,
          message: 'Staff member is already booked from ${a.startTime} to ${a.endTime}.',
          conflictingAppointment: ConflictingAppointmentModel(
            id: a.id,
            customerName: a.customerName,
            startTime: a.startTime,
            endTime: a.endTime,
            status: a.status,
          ),
        );
      }
    }

    return CheckConflictResult(
      hasConflict: false,
      message: 'No conflict detected.',
    );
  }

  static Future<AppointmentModel?> createAppointment(Map<String, dynamic> data) async {
    try {
      final staffId = int.tryParse(data['staff_id']?.toString() ?? '0') ?? 0;
      String staffName = (data['staff_name'] ?? '').toString();
      if (staffName.isEmpty && staffId > 0) {
        final st = await getStaffById(staffId);
        if (st != null) staffName = st.name;
      }

      final nextId = await getNextSequenceId('appointments');
      final apptDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'staff_id': staffId,
        'staff_name': staffName,
        'customer_id': data['customer_id'] != null
            ? int.tryParse(data['customer_id'].toString())
            : null,
        'customer_name': (data['customer_name'] ?? '').toString().trim(),
        'customer_phone': (data['customer_phone'] ?? '').toString().trim(),
        'appointment_date': (data['appointment_date'] ?? '').toString().trim(),
        'start_time': (data['start_time'] ?? '').toString().trim(),
        'end_time': (data['end_time'] ?? '').toString().trim(),
        'status': (data['status'] ?? 'booked').toString().trim(),
        'total_amount': double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0,
        'services': data['services'] is List ? data['services'] : [],
        'notes': (data['notes'] ?? '').toString().trim(),
        'refund_status': 'none',
        'refunded_amount': 0.0,
        'refunds': [],
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      apptDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/appointments/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      if (res.statusCode == 200) {
        return AppointmentModel.fromJson(apptDoc);
      }
    } catch (e) {
      debugPrint('Error creating appointment in Firestore: $e');
    }
    return null;
  }

  static Future<bool> updateAppointment(int id, Map<String, dynamic> data) async {
    try {
      final fields = <String, dynamic>{};
      final updateMasks = <String>[];

      data.forEach((k, v) {
        if (k != 'id') {
          fields[k] = encodeValue(v);
          updateMasks.add('updateMask.fieldPaths=$k');
        }
      });

      final maskQuery = updateMasks.join('&');
      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/appointments/$id?$maskQuery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating appointment in Firestore: $e');
      return false;
    }
  }

  static Future<bool> updateAppointmentStatus(int id, String status) async {
    return await updateAppointment(id, {'status': status});
  }

  static Future<bool> deleteAppointment(int id) async {
    try {
      final res = await http.delete(Uri.parse('$firestoreBaseUrl/appointments/$id'));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting appointment in Firestore: $e');
      return false;
    }
  }

  static Future<ApiResponse> processAppointmentRefund(
    int appointmentId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final appt = await getAppointmentById(appointmentId);
      if (appt == null) {
        return ApiResponse(success: false, message: 'Appointment not found.');
      }

      final existingRefunds = await getAppointmentRefunds(appointmentId);
      final rawExisting = existingRefunds.map((e) => e.toJson()).toList();

      final calc = RefundEngine.calculateRefundDetails(
        originalTransaction: {
          'subtotal': appt.subtotal > 0 ? appt.subtotal : appt.totalAmount,
          'item_discount_total': 0.0,
          'overall_discount': 0.0,
          'tax_amount': appt.taxAmount,
          'total_amount': appt.totalAmount,
          'services': appt.services,
          'items': appt.services,
        },
        refundItems: List<Map<String, dynamic>>.from(payload['items'] ?? []),
        existingRefunds: rawExisting,
      );

      final now = DateTime.now();
      final yyyy = now.year.toString();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final randomSuffix = (1000 + Random().nextInt(9000)).toString();
      final refundReceiptNumber = '#REF-$yyyy$mm$dd-APT-${appt.id}-$randomSuffix';

      final prevRefunded = existingRefunds.fold<double>(0.0, (acc, r) => acc + r.totalRefundAmount);
      final newRefundedAmount = ((prevRefunded + calc.totalRefundAmount) * 100).round() / 100.0;
      final newStatus = calc.isFullyRefunded ? 'full' : 'partial';

      final nextRefId = await getNextSequenceId('refunds');
      final refundRecord = {
        'id': nextRefId,
        'refund_receipt_number': refundReceiptNumber,
        'business_id': appt.businessId,
        'sale_id': null,
        'appointment_id': appt.id,
        'refund_type': calc.refundType,
        'subtotal_refunded': calc.subtotalRefunded,
        'discount_reversed_total': calc.discountReversedTotal,
        'gst_reversed_total': calc.gstReversedTotal,
        'total_refund_amount': calc.totalRefundAmount,
        'refund_method': payload['refund_method'] ?? 'cash',
        'reason': payload['reason'] ?? '',
        'notes': payload['notes'] ?? '',
        'items': calc.items,
        'created_at': now.toIso8601String(),
      };

      final fields = <String, dynamic>{};
      refundRecord.forEach((k, v) => fields[k] = encodeValue(v));

      await http.patch(
        Uri.parse('$firestoreBaseUrl/refunds/$nextRefId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      await updateAppointment(appt.id, {
        'refund_status': newStatus,
        'refunded_amount': newRefundedAmount,
      });

      final updatedAppt = await getAppointmentById(appt.id);

      return ApiResponse(
        success: true,
        message: 'Refund processed successfully!',
        data: {
          'data': refundRecord,
          'refund': RefundRecordModel.fromJson(refundRecord),
          'appointment': updatedAppt?.toJson() ?? {},
        },
      );
    } catch (e) {
      debugPrint('Error processing appointment refund: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // SALES
  // ---------------------------------------------------------------------------

  static Future<List<SaleModel>> getSales({
    int? appointmentId,
    String? search,
    String? startDate,
    String? endDate,
    String? paymentMethod,
    bool includeAppointments = false,
  }) async {
    try {
      final uri = Uri.parse('$firestoreBaseUrl/sales?pageSize=300');
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final docs = body['documents'] as List? ?? [];

      final allRefunds = await getAllRefunds();
      final Map<int, List<RefundRecordModel>> refundsBySale = {};
      for (final rf in allRefunds) {
        if (rf.saleId != null) {
          refundsBySale.putIfAbsent(rf.saleId!, () => []).add(rf);
        }
      }

      List<SaleModel> list = [];
      final q = (search ?? '').trim().toLowerCase();
      final start = startDate != null && startDate.isNotEmpty ? startDate.substring(0, min(10, startDate.length)) : null;
      final end = endDate != null && endDate.isNotEmpty ? endDate.substring(0, min(10, endDate.length)) : null;

      for (final doc in docs) {
        final d = decodeDocument(Map<String, dynamic>.from(doc));
        final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
        final sRefunds = refundsBySale[id] ?? [];

        final totalRefunded = sRefunds.fold<double>(0.0, (acc, r) => acc + r.totalRefundAmount);
        final totalGstRefunded = sRefunds.fold<double>(0.0, (acc, r) => acc + r.gstReversedTotal);
        final totalSubtotalRefunded = sRefunds.fold<double>(0.0, (acc, r) => acc + r.subtotalRefunded);

        final totalAmt = double.tryParse(d['total_amount']?.toString() ?? '0') ?? 0.0;
        final existingRefundStatus = (d['refund_status'] ?? '').toString();
        final resolvedStatus = existingRefundStatus.isNotEmpty && existingRefundStatus != 'none'
            ? existingRefundStatus
            : (sRefunds.isNotEmpty ? (totalRefunded >= totalAmt ? 'full' : 'partial') : 'none');

        d['refunds'] = sRefunds.map((e) => e.toJson()).toList();
        d['refunded_amount'] = double.tryParse(d['refunded_amount']?.toString() ?? '0') ?? totalRefunded;
        d['refund_status'] = resolvedStatus;
        d['gst_reversed_total'] = totalGstRefunded;
        d['subtotal_refunded_total'] = totalSubtotalRefunded;

        final sale = SaleModel.fromJson(d);

        // Appointment link filtering
        if (!includeAppointments && appointmentId == null) {
          if (sale.appointmentId != null && sale.appointmentId! > 0) {
            continue;
          }
        }

        if (appointmentId != null && sale.appointmentId != appointmentId) {
          continue;
        }

        if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod.toLowerCase() != 'all') {
          if (sale.paymentMethod.toLowerCase() != paymentMethod.toLowerCase()) {
            continue;
          }
        }

        // Date range
        final createdStr = sale.createdAt?.toIso8601String() ?? '';
        final sDate = createdStr.length >= 10 ? createdStr.substring(0, 10) : '';
        if (start != null && end != null) {
          if (sDate.compareTo(start) < 0 || sDate.compareTo(end) > 0) continue;
        } else if (start != null) {
          if (sDate.compareTo(start) < 0) continue;
        } else if (end != null) {
          if (sDate.compareTo(end) > 0) continue;
        }

        // Search
        if (q.isNotEmpty) {
          final cName = sale.customerName.toLowerCase();
          final cPhone = sale.customerPhone.toLowerCase();
          final sName = sale.staffName.toLowerCase();
          if (!cName.contains(q) && !cPhone.contains(q) && !sName.contains(q)) {
            continue;
          }
        }

        list.add(sale);
      }

      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      debugPrint('Error getting sales from Firestore: $e');
      return [];
    }
  }

  static Future<PaginatedResult<SaleModel>> getSalesPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? paymentMethod,
    bool includeAppointments = false,
    int page = 1,
    int limit = 20,
  }) async {
    final list = await getSales(
      startDate: startDate,
      endDate: endDate,
      search: search,
      paymentMethod: paymentMethod,
      includeAppointments: includeAppointments,
    );

    final total = list.length;
    final totalPages = (total / limit).ceil().clamp(1, 999999);
    final p = page.clamp(1, totalPages);
    final offset = (p - 1) * limit;
    final items = list.skip(offset).take(limit).toList();

    return PaginatedResult<SaleModel>(
      items: items,
      total: total,
      page: p,
      limit: limit,
      totalPages: totalPages,
    );
  }

  static Future<HistorySummaryModel> getSaleSummary({
    String? startDate,
    String? endDate,
    String? search,
    String? paymentMethod,
    bool includeAppointments = false,
  }) async {
    final list = await getSales(
      startDate: startDate,
      endDate: endDate,
      search: search,
      paymentMethod: paymentMethod,
      includeAppointments: includeAppointments,
    );

    final total = list.length;
    final completed = total;
    final totalRevenue = list.fold<double>(0.0, (acc, s) => acc + s.totalAmount);

    return HistorySummaryModel(
      total: total,
      completed: completed,
      totalRevenue: (totalRevenue * 100).round() / 100.0,
    );
  }

  static Future<SaleModel?> getSaleById(int id) async {
    final all = await getSales(includeAppointments: true);
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Future<SaleModel?> createSale(Map<String, dynamic> data) async {
    try {
      final staffId = int.tryParse(data['staff_id']?.toString() ?? '0');
      String staffName = (data['staff_name'] ?? '').toString();
      if (staffName.isEmpty && staffId != null && staffId > 0) {
        final st = await getStaffById(staffId);
        if (st != null) staffName = st.name;
      }

      final nextId = await getNextSequenceId('sales');
      final apptId = data['appointment_id'] != null
          ? int.tryParse(data['appointment_id'].toString())
          : null;

      final saleDoc = {
        'id': nextId,
        'business_id': data['business_id'] ?? 1,
        'appointment_id': apptId,
        'customer_id': data['customer_id'] != null
            ? int.tryParse(data['customer_id'].toString())
            : null,
        'customer_name': (data['customer_name'] ?? '').toString().trim(),
        'customer_phone': (data['customer_phone'] ?? '').toString().trim(),
        'staff_id': staffId,
        'staff_name': staffName,
        'subtotal': double.tryParse(data['subtotal']?.toString() ?? '0') ?? 0.0,
        'item_discount_total': double.tryParse(data['item_discount_total']?.toString() ?? '0') ?? 0.0,
        'overall_discount': double.tryParse(data['overall_discount']?.toString() ?? '0') ?? 0.0,
        'tax_amount': double.tryParse(data['tax_amount']?.toString() ?? '0') ?? 0.0,
        'total_amount': double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0,
        'payment_method': (data['payment_method'] ?? 'cash').toString(),
        'amount_tendered': double.tryParse(data['amount_tendered']?.toString() ?? '0') ?? 0.0,
        'change_amount': double.tryParse(data['change_amount']?.toString() ?? '0') ?? 0.0,
        'items': data['items'] is List ? data['items'] : [],
        'notes': (data['notes'] ?? '').toString().trim(),
        'refund_status': 'none',
        'refunded_amount': 0.0,
        'refunds': [],
        'created_at': DateTime.now().toIso8601String(),
      };

      final fields = <String, dynamic>{};
      saleDoc.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/sales/$nextId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      // Auto-transition linked appointment to 'completed' in Firestore matching React PR
      if (apptId != null && apptId > 0) {
        try {
          await updateAppointment(apptId, {
            'status': 'completed',
            'total_amount': saleDoc['total_amount'],
          });
        } catch (e) {
          debugPrint('Notice: could not auto-complete appointment $apptId: $e');
        }
      }

      if (res.statusCode == 200) {
        return SaleModel.fromJson(saleDoc);
      }
    } catch (e) {
      debugPrint('Error creating sale in Firestore: $e');
    }
    return null;
  }

  static Future<ApiResponse> processSaleRefund(
    int saleId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final sale = await getSaleById(saleId);
      if (sale == null) {
        return ApiResponse(success: false, message: 'Sale not found.');
      }

      final existingRefunds = await getSaleRefunds(saleId);
      final rawExisting = existingRefunds.map((e) => e.toJson()).toList();

      final calc = RefundEngine.calculateRefundDetails(
        originalTransaction: {
          'subtotal': sale.subtotal,
          'item_discount_total': sale.itemDiscountTotal,
          'overall_discount': sale.overallDiscount,
          'tax_amount': sale.taxAmount,
          'total_amount': sale.totalAmount,
          'items': sale.items,
        },
        refundItems: List<Map<String, dynamic>>.from(payload['items'] ?? []),
        existingRefunds: rawExisting,
      );

      final now = DateTime.now();
      final yyyy = now.year.toString();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final randomSuffix = (1000 + Random().nextInt(9000)).toString();
      final refundReceiptNumber = '#REF-$yyyy$mm$dd-${sale.id}-$randomSuffix';

      final prevRefunded = existingRefunds.fold<double>(0.0, (acc, r) => acc + r.totalRefundAmount);
      final newRefundedAmount = ((prevRefunded + calc.totalRefundAmount) * 100).round() / 100.0;
      final newStatus = calc.isFullyRefunded ? 'full' : 'partial';

      final nextRefId = await getNextSequenceId('refunds');
      final refundRecord = {
        'id': nextRefId,
        'refund_receipt_number': refundReceiptNumber,
        'business_id': sale.businessId,
        'sale_id': sale.id,
        'appointment_id': sale.appointmentId,
        'refund_type': calc.refundType,
        'subtotal_refunded': calc.subtotalRefunded,
        'discount_reversed_total': calc.discountReversedTotal,
        'gst_reversed_total': calc.gstReversedTotal,
        'total_refund_amount': calc.totalRefundAmount,
        'refund_method': payload['refund_method'] ?? sale.paymentMethod,
        'reason': payload['reason'] ?? '',
        'notes': payload['notes'] ?? '',
        'items': calc.items,
        'created_at': now.toIso8601String(),
      };

      final fields = <String, dynamic>{};
      refundRecord.forEach((k, v) => fields[k] = encodeValue(v));

      await http.patch(
        Uri.parse('$firestoreBaseUrl/refunds/$nextRefId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      // Update sale doc
      final updateSaleFields = {
        'refund_status': encodeValue(newStatus),
        'refunded_amount': encodeValue(newRefundedAmount),
      };
      await http.patch(
        Uri.parse('$firestoreBaseUrl/sales/${sale.id}?updateMask.fieldPaths=refund_status&updateMask.fieldPaths=refunded_amount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': updateSaleFields}),
      );

      // If linked to appointment, also update appointment doc
      if (sale.appointmentId != null && sale.appointmentId! > 0) {
        try {
          await updateAppointment(sale.appointmentId!, {
            'refund_status': newStatus,
            'refunded_amount': newRefundedAmount,
          });
        } catch (_) {}
      }

      final updatedSale = await getSaleById(sale.id);

      return ApiResponse(
        success: true,
        message: 'Refund processed successfully!',
        data: {
          'data': refundRecord,
          'refund': RefundRecordModel.fromJson(refundRecord),
          'sale': updatedSale?.toJson() ?? {},
        },
      );
    } catch (e) {
      debugPrint('Error processing sale refund: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // SETTINGS & PRINTER SETTINGS
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _defaultSettings(int bId) {
    return {
      'id': bId,
      'business_id': bId,
      'time_format': '12',
      'clock_display': '12h',
      'booking_slot_interval': 30,
      'slot_duration': 30,
      'buffer_time_between_sessions': 10,
      'buffer_time': 10,
      'open_time': '08:00',
      'close_time': '20:00',
      'operating_business_hours': {
        'open_time': '08:00',
        'close_time': '20:00',
      },
      'allow_walk_in_queue': true,
      'require_doctor_notes': true,
      'allow_delete_service': false,
      'appointment_v2_clock': true,
      'printer_settings': {
        'printer_name': 'Main Counter ESC/POS Printer',
        'connection_type': 'lan',
        'ip_address': '192.168.1.51',
        'port': 9100,
        'paper_size': 'mm80',
        'business_name': 'IQ RESTAURANT & POS',
        'phone_number': '',
        'addr_line1': '',
        'addr_line2': '',
        'addr_line3': '',
        'header_note': 'Thank you for your visit!',
        'footer_note': 'Thank you for your visit! Please come again.',
        'is_default': true,
        'is_enabled': true,
        'order_receipt_enabled': true,
        'auto_cut': true,
        'open_cash_drawer': false,
      },
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Future<ApiResponse> getSettings({int? businessId}) async {
    final bId = businessId ?? 1;
    try {
      final uri = Uri.parse('$firestoreBaseUrl/settings/$bId');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final d = decodeDocument(body);
        return ApiResponse(success: true, message: 'Settings retrieved', data: d);
      } else {
        // Fallback default creation
        final def = _defaultSettings(bId);
        final fields = <String, dynamic>{};
        def.forEach((k, v) => fields[k] = encodeValue(v));
        await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fields': fields}),
        );
        return ApiResponse(success: true, message: 'Default settings loaded', data: def);
      }
    } catch (e) {
      debugPrint('Error getting settings from Firestore: $e');
      return ApiResponse(success: true, message: 'Default settings used', data: _defaultSettings(bId));
    }
  }

  static Future<ApiResponse> updateSettings(Map<String, dynamic> settingsData) async {
    final bId = settingsData['business_id'] ?? 1;
    try {
      final currentRes = await getSettings(businessId: bId);
      final current = currentRes.data is Map ? Map<String, dynamic>.from(currentRes.data) : _defaultSettings(bId);

      final merged = {...current, ...settingsData, 'updated_at': DateTime.now().toIso8601String()};
      final fields = <String, dynamic>{};
      merged.forEach((k, v) => fields[k] = encodeValue(v));

      final res = await http.patch(
        Uri.parse('$firestoreBaseUrl/settings/$bId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'Settings updated successfully.', data: merged);
      }
    } catch (e) {
      debugPrint('Error updating settings in Firestore: $e');
    }
    return ApiResponse(success: false, message: 'Could not update settings.');
  }

  static Future<PrinterSettingsModel> getPrinterSettings({int? businessId}) async {
    final res = await getSettings(businessId: businessId);
    if (res.success && res.data is Map) {
      final dataMap = Map<String, dynamic>.from(res.data);
      if (dataMap['printer_settings'] is Map) {
        return PrinterSettingsModel.fromJson(Map<String, dynamic>.from(dataMap['printer_settings']));
      }
    }
    return PrinterSettingsModel.defaultSettings();
  }

  static Future<ApiResponse> updatePrinterSettings(Map<String, dynamic> printerData, {int? businessId}) async {
    final bId = businessId ?? 1;
    try {
      final currentSettingsRes = await getSettings(businessId: bId);
      final currentSettings = currentSettingsRes.data is Map
          ? Map<String, dynamic>.from(currentSettingsRes.data)
          : _defaultSettings(bId);

      currentSettings['printer_settings'] = printerData;
      return await updateSettings(currentSettings);
    } catch (e) {
      debugPrint('Error updating printer settings: $e');
      return ApiResponse(success: false, message: 'Could not update printer settings: $e');
    }
  }
}

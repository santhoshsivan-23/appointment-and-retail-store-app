import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constant.dart';
import '../models/appointment_model.dart';
import '../models/business_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/staff_model.dart';
import 'auth_storage.dart';

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final String? token;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.token,
    this.statusCode = 200,
  });
}

class ApiService {
  static String get defaultBaseUrl {
    final base = AppConstant.baseUrl.trim();
    if (base.endsWith('/api')) return base;
    return '$base/api';
  }

  static Future<String> getBaseUrl() async {
    final customUrl = await AuthStorage.getCustomBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      if (customUrl.endsWith('/api')) return customUrl;
      return '$customUrl/api';
    }
    return defaultBaseUrl;
  }

  static Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = <String, String>{
      ...AppConstant.jsonHeaders,
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await AuthStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Auth: Register
  static Future<ApiResponse> register(Map<String, dynamic> businessData) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/auth/register');

      final response = await http
          .post(url, headers: await _getHeaders(), body: jsonEncode(businessData))
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = body['token'] as String?;
        final businessJson = body['business'] as Map<String, dynamic>?;

        BusinessModel? business;
        if (businessJson != null) {
          business = BusinessModel.fromJson(businessJson);
          if (token != null) {
            await AuthStorage.saveAuth(token: token, business: business);
          }
        }

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Business registered successfully!',
          data: business,
          token: token,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Registration failed. (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 0,
      );
    }
  }

  // Auth: Login
  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/auth/login');

      final response = await http
          .post(
            url,
            headers: await _getHeaders(),
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = body['token'] as String?;
        final businessJson = body['business'] as Map<String, dynamic>?;

        BusinessModel? business;
        if (businessJson != null) {
          business = BusinessModel.fromJson(businessJson);
          if (token != null) {
            await AuthStorage.saveAuth(token: token, business: business);
          }
        }

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Login successful!',
          data: business,
          token: token,
          statusCode: 200,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Invalid email or password.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Cannot reach server ($e).',
        statusCode: 0,
      );
    }
  }

  // Staff APIs
  static Future<List<StaffModel>> getStaff({String search = '', bool includeDeleted = false}) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/staff').replace(queryParameters: {
        if (search.isNotEmpty) 'search': search,
        if (includeDeleted) 'include_deleted': 'true',
      });
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => StaffModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting staff: $e');
    }
    return [];
  }

  static Future<bool> createStaff(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/staff'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteStaff(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.delete(
        Uri.parse('$baseUrl/staff/$id'),
        headers: await _getHeaders(),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Customer APIs
  static Future<List<CustomerModel>> getCustomers({String search = ''}) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/customers').replace(queryParameters: {
        if (search.isNotEmpty) 'search': search,
      });
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => CustomerModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting customers: $e');
    }
    return [];
  }

  static Future<CustomerModel?> createCustomer(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/customers'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return CustomerModel.fromJson(body['data']);
      }
    } catch (_) {}
    return null;
  }

  // Category APIs
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.get(Uri.parse('$baseUrl/categories'), headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => CategoryModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting categories: $e');
    }
    return [];
  }

  static Future<bool> createCategory(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteCategory(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.delete(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _getHeaders(),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Product APIs
  static Future<List<ProductModel>> getProducts({int? categoryId, String? productType, String search = ''}) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (categoryId != null) params['category_id'] = categoryId.toString();
      if (productType != null && productType.isNotEmpty) params['product_type'] = productType;
      if (search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => ProductModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting products: $e');
    }
    return [];
  }

  static Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteProduct(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _getHeaders(),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Appointment APIs
  static Future<List<AppointmentModel>> getAppointments({String? date}) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (date != null && date.isNotEmpty) params['date'] = date;

      final uri = Uri.parse('$baseUrl/appointments').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => AppointmentModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting appointments: $e');
    }
    return [];
  }

  static Future<Map<String, int>> getAppointmentStats({String? date}) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (date != null && date.isNotEmpty) params['date'] = date;

      final uri = Uri.parse('$baseUrl/appointments/stats/overview').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};
        return {
          'total': (data['total'] as num?)?.toInt() ?? 0,
          'booked': (data['booked'] as num?)?.toInt() ?? 0,
          'in_service': (data['in_service'] as num?)?.toInt() ?? 0,
          'completed': (data['completed'] as num?)?.toInt() ?? 0,
          'no_show': (data['no_show'] as num?)?.toInt() ?? 0,
          'cancelled': (data['cancelled'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error getting appointment stats: $e');
    }
    return {
      'total': 0,
      'booked': 0,
      'in_service': 0,
      'completed': 0,
      'no_show': 0,
      'cancelled': 0,
    };
  }

  static Future<AppointmentModel?> createAppointment(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/appointments'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return AppointmentModel.fromJson(body['data']);
      }
    } catch (e) {
      debugPrint('Error creating appointment: $e');
    }
    return null;
  }

  static Future<bool> updateAppointmentStatus(int id, String status) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.put(
        Uri.parse('$baseUrl/appointments/$id/status'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating appointment status: $e');
      return false;
    }
  }

  static Future<bool> updateAppointment(int id, Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.put(
        Uri.parse('$baseUrl/appointments/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating appointment: $e');
      return false;
    }
  }

  static Future<bool> deleteAppointment(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.delete(
        Uri.parse('$baseUrl/appointments/$id'),
        headers: await _getHeaders(),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting appointment: $e');
      return false;
    }
  }

  // Sales APIs
  static Future<SaleModel?> createSale(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/sales'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return SaleModel.fromJson(body['data']);
      }
    } catch (e) {
      debugPrint('Error creating sale: $e');
    }
    return null;
  }

  static Future<List<SaleModel>> getSales({int? appointmentId}) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (appointmentId != null) params['appointment_id'] = appointmentId.toString();
      final uri = Uri.parse('$baseUrl/sales').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => SaleModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting sales: $e');
    }
    return [];
  }

  // Conflict Check
  static Future<Map<String, dynamic>> checkAppointmentConflict({
    required int staffId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int? excludeId,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
        final payload = <String, dynamic>{
          'staff_id': staffId,
          'appointment_date': appointmentDate,
          'start_time': startTime,
          'end_time': endTime,
        };
        if (excludeId != null) payload['exclude_id'] = excludeId;
        final res = await http.post(
          Uri.parse('$baseUrl/appointments/check-conflict'),
          headers: await _getHeaders(),
          body: jsonEncode(payload),
        );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error checking conflict: $e');
    }
    return {'has_conflict': false};
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/business_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
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
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static Future<String> getBaseUrl() async {
    final customUrl = await AuthStorage.getCustomBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    return defaultBaseUrl;
  }

  static Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
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
}

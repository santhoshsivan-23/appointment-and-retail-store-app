import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constant.dart';
import '../models/appointment_model.dart';
import '../models/business_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/refund_model.dart';
import '../models/sale_model.dart';
import '../models/staff_model.dart';
import '../models/printer_settings_model.dart';
import '../models/history_summary_model.dart';
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

  static Future<bool> updateStaff(int id, Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.put(
        Uri.parse('$baseUrl/staff/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 200;
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

  static Future<List<CustomerModel>> searchCustomers(String query) => getCustomers(search: query);

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
        return list
            .map((x) => CategoryModel.fromJson(Map<String, dynamic>.from(x)))
            .where((c) => !c.isDeleted && c.isActive)
            .toList();
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

  static Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.put(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 200;
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
        return list
            .map((x) => ProductModel.fromJson(Map<String, dynamic>.from(x)))
            .where((p) => !p.isDeleted && p.isActive)
            .toList();
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

  static Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return res.statusCode == 200;
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

  /// Dedicated search products / services endpoint with fallback to getProducts
  static Future<List<ProductModel>> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/products/search').replace(queryParameters: {'q': q});
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list
            .map((x) => ProductModel.fromJson(Map<String, dynamic>.from(x)))
            .where((p) => !p.isDeleted && p.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('Error in searchProducts, falling back: $e');
    }
    return getProducts(search: q);
  }

  // Appointment APIs
  static Future<List<AppointmentModel>> getAppointments({
    String? date,
    int? staffId,
    String? search,
    String? status,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (staffId != null) params['staff_id'] = staffId.toString();
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri = Uri.parse('$baseUrl/appointments').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
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

  /// Get paginated appointments by date range, search, and status (History Data API)
  static Future<PaginatedResult<AppointmentModel>> getAppointmentsPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri = Uri.parse('$baseUrl/appointments').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        final items = list.map((x) => AppointmentModel.fromJson(Map<String, dynamic>.from(x))).toList();
        final total = (body['total'] as num?)?.toInt() ?? items.length;
        final totalPages = (body['totalPages'] as num?)?.toInt() ?? ((total / limit).ceil().clamp(1, 999999));
        return PaginatedResult<AppointmentModel>(
          items: items,
          total: total,
          page: page,
          limit: limit,
          totalPages: totalPages,
        );
      }
    } catch (e) {
      debugPrint('Error getting paginated appointments: $e');
    }
    return PaginatedResult<AppointmentModel>(
      items: [],
      total: 0,
      page: page,
      limit: limit,
      totalPages: 1,
    );
  }

  /// Get fast summary aggregates for appointments in date range (Summary API)
  static Future<HistorySummaryModel> getAppointmentSummary({
    required String startDate,
    required String endDate,
    String? search,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{
        'start_date': startDate,
        'end_date': endDate,
      };
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final uri = Uri.parse('$baseUrl/appointments/summary').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null) {
          return HistorySummaryModel.fromJson(Map<String, dynamic>.from(body['data']));
        }
      }
    } catch (e) {
      debugPrint('Error getting appointment summary: $e');
    }
    return const HistorySummaryModel();
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
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting appointment: $e');
      return false;
    }
  }

  /// Get appointment by ID
  static Future<AppointmentModel?> getAppointmentById(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/appointments/$id'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null) {
          return AppointmentModel.fromJson(Map<String, dynamic>.from(body['data']));
        }
      }
    } catch (e) {
      debugPrint('Error getting appointment by id: $e');
    }
    return null;
  }

  /// Check appointment conflict against server database
  static Future<CheckConflictResult> checkConflict({
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
      if (excludeId != null) {
        payload['exclude_id'] = excludeId;
      }
      final res = await http.post(
        Uri.parse('$baseUrl/appointments/check-conflict'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return CheckConflictResult.fromJson(Map<String, dynamic>.from(body));
      } else {
        final body = jsonDecode(res.body);
        return CheckConflictResult(
          hasConflict: false,
          message: body['message'] ?? 'Conflict check returned status ${res.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error checking appointment conflict: $e');
      return CheckConflictResult(hasConflict: false, message: e.toString());
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

  static Future<List<SaleModel>> getSales({int? appointmentId, String? search}) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{};
      if (appointmentId != null) params['appointment_id'] = appointmentId.toString();
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
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

  /// Get paginated sales by date range, payment method, and search (History Data API)
  static Future<PaginatedResult<SaleModel>> getSalesPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? paymentMethod,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod != 'all') {
        params['payment_method'] = paymentMethod;
      }

      final uri = Uri.parse('$baseUrl/sales').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        final rawSales = list.map((x) => SaleModel.fromJson(Map<String, dynamic>.from(x))).toList();
        // Normal POS/Cart sales only (appointment_id null or 0)
        final items = rawSales.where((s) => s.appointmentId == null || s.appointmentId == 0).toList();
        final total = (body['total'] as num?)?.toInt() ?? items.length;
        final totalPages = (body['totalPages'] as num?)?.toInt() ?? ((total / limit).ceil().clamp(1, 999999));
        return PaginatedResult<SaleModel>(
          items: items,
          total: total,
          page: page,
          limit: limit,
          totalPages: totalPages,
        );
      }
    } catch (e) {
      debugPrint('Error getting paginated sales: $e');
    }
    return PaginatedResult<SaleModel>(
      items: [],
      total: 0,
      page: page,
      limit: limit,
      totalPages: 1,
    );
  }

  /// Get fast summary aggregates for sales in date range (Summary API)
  static Future<HistorySummaryModel> getSaleSummary({
    required String startDate,
    required String endDate,
    String? search,
    String? paymentMethod,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final params = <String, String>{
        'start_date': startDate,
        'end_date': endDate,
      };
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod != 'all') {
        params['payment_method'] = paymentMethod;
      }

      final uri = Uri.parse('$baseUrl/sales/summary').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null) {
          return HistorySummaryModel.fromJson(Map<String, dynamic>.from(body['data']));
        }
      }
    } catch (e) {
      debugPrint('Error getting sale summary: $e');
    }
    return const HistorySummaryModel();
  }

  // Refund API: Process Sale Refund
  static Future<ApiResponse> processSaleRefund(int saleId, Map<String, dynamic> payload) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/sales/$saleId/refund');
      final res = await http
          .post(url, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Refund processed successfully!',
          data: body,
          statusCode: res.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to process refund (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error processing sale refund: $e');
      return ApiResponse(
        success: false,
        message: 'Network error processing refund: $e',
        statusCode: 500,
      );
    }
  }

  // Refund API: Process Appointment Refund
  static Future<ApiResponse> processAppointmentRefund(int appointmentId, Map<String, dynamic> payload) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/appointments/$appointmentId/refund');
      final res = await http
          .post(url, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Refund processed successfully!',
          data: body,
          statusCode: res.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to process refund (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error processing appointment refund: $e');
      return ApiResponse(
        success: false,
        message: 'Network error processing refund: $e',
        statusCode: 500,
      );
    }
  }

  // Refund API: Get Sale Refunds
  static Future<List<RefundRecordModel>> getSaleRefunds(int saleId) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/sales/$saleId/refunds');
      final res = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => RefundRecordModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting sale refunds: $e');
    }
    return [];
  }

  // Refund API: Get Appointment Refunds
  static Future<List<RefundRecordModel>> getAppointmentRefunds(int appointmentId) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/appointments/$appointmentId/refunds');
      final res = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List? ?? []);
        return list.map((x) => RefundRecordModel.fromJson(Map<String, dynamic>.from(x))).toList();
      }
    } catch (e) {
      debugPrint('Error getting appointment refunds: $e');
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

  // Settings API: Get Settings
  static Future<ApiResponse> getSettings({int? businessId}) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/settings${businessId != null ? '?business_id=$businessId' : ''}');
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Settings retrieved successfully',
          data: body['data'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to retrieve settings (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return ApiResponse(
        success: false,
        message: 'Network error retrieving settings: $e',
        statusCode: 500,
      );
    }
  }

  // Settings API: Update Settings
  static Future<ApiResponse> updateSettings(Map<String, dynamic> settingsData) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/settings');
      final response = await http
          .put(uri, headers: await _getHeaders(), body: jsonEncode(settingsData))
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Settings updated successfully',
          data: body['data'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to update settings (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
      return ApiResponse(
        success: false,
        message: 'Network error updating settings: $e',
        statusCode: 500,
      );
    }
  }

  static Future<PrinterSettingsModel> getPrinterSettings({int? businessId}) async {
    try {
      final res = await getSettings(businessId: businessId);
      if (res.success && res.data != null) {
        final rawPrinter = res.data['printer_settings'];
        if (rawPrinter is Map) {
          return PrinterSettingsModel.fromJson(Map<String, dynamic>.from(rawPrinter));
        } else if (rawPrinter is String) {
          try {
            final parsed = jsonDecode(rawPrinter);
            if (parsed is Map) {
              return PrinterSettingsModel.fromJson(Map<String, dynamic>.from(parsed));
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error getting printer settings: $e');
    }
    return PrinterSettingsModel.defaultSettings();
  }

  static Future<ApiResponse> updatePrinterSettings(
    Map<String, dynamic> printerSettings, {
    int? businessId,
  }) async {
    return updateSettings({
      'business_id': businessId ?? 1,
      'printer_settings': printerSettings,
    });
  }

  // POST /api/settings/test-print
  static Future<ApiResponse> testPrint(Map<String, dynamic> payload) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/settings/test-print');
      final response = await http
          .post(uri, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && (body['success'] != false),
        message: body['message'] ??
            (response.statusCode == 200 ? 'Test print sent successfully.' : 'Failed to send test print.'),
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('Error executing test print: $e');
      return ApiResponse(
        success: false,
        message: 'Printer connection error: $e',
        statusCode: 500,
      );
    }
  }

  // POST /api/settings/print-receipt
  static Future<ApiResponse> printReceipt(Map<String, dynamic> payload) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/settings/print-receipt');
      final response = await http
          .post(uri, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && (body['success'] != false),
        message: body['message'] ??
            (response.statusCode == 200 ? 'Receipt printed successfully.' : 'Failed to print receipt.'),
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return ApiResponse(
        success: false,
        message: 'Printer connection error: $e',
        statusCode: 500,
      );
    }
  }
}



import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/business_model.dart';
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
  // Determine standard default URL depending on platform
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  // Get active Base URL (custom if configured, otherwise default)
  static Future<String> getBaseUrl() async {
    final customUrl = await AuthStorage.getCustomBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    return defaultBaseUrl;
  }

  // Helper headers
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

  // Register Business
  static Future<ApiResponse> register(Map<String, dynamic> businessData) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/auth/register');

      final response = await http
          .post(
            url,
            headers: await _getHeaders(),
            body: jsonEncode(businessData),
          )
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
        message: 'Network error: Unable to connect to server. Check your connection or server status.',
        statusCode: 0,
      );
    }
  }

  // Login Business
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
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
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
        message: 'Network error: Cannot reach server ($e). Make sure backend is running.',
        statusCode: 0,
      );
    }
  }

  // Get Current Business Profile
  static Future<ApiResponse> getProfile() async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/auth/me');

      final response = await http
          .get(
            url,
            headers: await _getHeaders(includeAuth: true),
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final businessJson = body['business'] as Map<String, dynamic>?;
        BusinessModel? business;
        if (businessJson != null) {
          business = BusinessModel.fromJson(businessJson);
        }
        return ApiResponse(
          success: true,
          message: 'Profile fetched',
          data: business,
          statusCode: 200,
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to load profile',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }

  // Test Server Connection
  static Future<bool> testConnection() async {
    try {
      final baseUrl = await getBaseUrl();
      // Replace /api with /api/health
      final uri = Uri.parse('$baseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_model.dart';

class AuthStorage {
  static const String _keyToken = 'auth_token';
  static const String _keyBusiness = 'auth_business';
  static const String _keyBaseUrl = 'custom_base_url';

  // Save auth data
  static Future<void> saveAuth({
    required String token,
    required BusinessModel business,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyBusiness, jsonEncode(business.toJson()));
  }

  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Get saved business profile
  static Future<BusinessModel?> getBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyBusiness);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr);
      return BusinessModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // Check if session exists
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Logout / clear session
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyBusiness);
  }

  // Custom API Base URL storage (allows switching between localhost, 10.0.2.2, LAN IP)
  static Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url.trim());
  }

  static Future<String?> getCustomBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl);
  }
}

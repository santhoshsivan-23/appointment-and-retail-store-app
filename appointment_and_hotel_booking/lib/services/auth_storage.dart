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

  static const String _keyHideHeader = 'hide_header';
  static const String _keyHideFooter = 'hide_footer';
  static const String _keyFullscreen = 'is_fullscreen';

  static Future<void> setHideHeader(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideHeader, val);
  }

  static Future<bool> getHideHeader() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHideHeader) ?? false;
  }

  static Future<void> setHideFooter(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideFooter, val);
  }

  static Future<bool> getHideFooter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHideFooter) ?? false;
  }

  static Future<void> setIsFullscreen(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullscreen, val);
  }

  static Future<bool> getIsFullscreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullscreen) ?? false;
  }

  // Appointment Configuration preferences
  static const String _keyTimeFormat = 'time_format';
  static const String _keyOpenTime = 'open_time';
  static const String _keyCloseTime = 'close_time';
  static const String _keySlotDuration = 'slot_duration';
  static const String _keyBufferTime = 'buffer_time';

  static Future<void> setTimeFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimeFormat, format);
  }

  static Future<String> getTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTimeFormat) ?? '12';
  }

  static Future<void> setOpenTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenTime, time);
  }

  static Future<String> getOpenTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOpenTime) ?? '08:00';
  }

  static Future<void> setCloseTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCloseTime, time);
  }

  static Future<String> getCloseTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCloseTime) ?? '20:00';
  }

  static Future<void> setSlotDuration(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySlotDuration, mins);
  }

  static Future<int> getSlotDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySlotDuration) ?? 30;
  }

  static Future<void> setBufferTime(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBufferTime, mins);
  }

  static Future<int> getBufferTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBufferTime) ?? 10;
  }

  static const String _keyAllowDeleteService = 'allow_delete_service';

  static Future<void> setAllowDeleteService(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowDeleteService, val);
  }

  static Future<bool> getAllowDeleteService() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowDeleteService) ?? false;
  }
}

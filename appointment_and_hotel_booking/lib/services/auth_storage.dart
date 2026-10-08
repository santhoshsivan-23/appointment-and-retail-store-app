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
  static const String _keyClockDisplay = 'clock_display';
  static const String _keyOpenTime = 'open_time';
  static const String _keyCloseTime = 'close_time';
  static const String _keySlotDuration = 'slot_duration';
  static const String _keyBufferTime = 'buffer_time';
  static const String _keyAllowWalkInQueue = 'allow_walk_in_queue';
  static const String _keyRequireDoctorNotes = 'require_doctor_notes';
  static const String _keyAllowDeleteService = 'allow_delete_service';

  static Future<void> setTimeFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimeFormat, format);
  }

  static Future<String> getTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTimeFormat) ?? '12';
  }

  static Future<void> setClockDisplay(String display) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClockDisplay, display);
  }

  static Future<String> getClockDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    final fmt = prefs.getString(_keyTimeFormat) ?? '12';
    return prefs.getString(_keyClockDisplay) ?? (fmt == '24' ? '24h' : '12h');
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

  static Future<void> setAllowWalkInQueue(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowWalkInQueue, val);
  }

  static Future<bool> getAllowWalkInQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowWalkInQueue) ?? true;
  }

  static Future<void> setRequireDoctorNotes(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRequireDoctorNotes, val);
  }

  static Future<bool> getRequireDoctorNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRequireDoctorNotes) ?? true;
  }

  static Future<void> setAllowDeleteService(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowDeleteService, val);
  }

  static Future<bool> getAllowDeleteService() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowDeleteService) ?? false;
  }

  // Save retrieved settings map directly to SharedPreferences
  static Future<void> saveSettingsFromMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data['time_format'] != null) {
      await prefs.setString(_keyTimeFormat, data['time_format'].toString());
    }

    if (data['clock_display'] != null) {
      await prefs.setString(_keyClockDisplay, data['clock_display'].toString());
    } else if (data['time_format'] != null) {
      await prefs.setString(_keyClockDisplay, data['time_format'].toString() == '24' ? '24h' : '12h');
    }

    final slotInterval = data['booking_slot_interval'] ?? data['slot_duration'];
    if (slotInterval != null) {
      final val = slotInterval is int ? slotInterval : int.tryParse(slotInterval.toString()) ?? 30;
      await prefs.setInt(_keySlotDuration, val);
    }

    final buffer = data['buffer_time_between_sessions'] ?? data['buffer_time'];
    if (buffer != null) {
      final val = buffer is int ? buffer : int.tryParse(buffer.toString()) ?? 10;
      await prefs.setInt(_keyBufferTime, val);
    }

    final openTime = data['open_time'] ?? data['operating_business_hours']?['open_time'];
    if (openTime != null) {
      await prefs.setString(_keyOpenTime, openTime.toString().trim());
    }

    final closeTime = data['close_time'] ?? data['operating_business_hours']?['close_time'];
    if (closeTime != null) {
      await prefs.setString(_keyCloseTime, closeTime.toString().trim());
    }

    if (data['allow_walk_in_queue'] != null) {
      await prefs.setBool(_keyAllowWalkInQueue, data['allow_walk_in_queue'] == true || data['allow_walk_in_queue'] == 1);
    }

    if (data['require_doctor_notes'] != null) {
      await prefs.setBool(_keyRequireDoctorNotes, data['require_doctor_notes'] == true || data['require_doctor_notes'] == 1);
    }

    if (data['allow_delete_service'] != null) {
      await prefs.setBool(_keyAllowDeleteService, data['allow_delete_service'] == true || data['allow_delete_service'] == 1);
    }
  }
}

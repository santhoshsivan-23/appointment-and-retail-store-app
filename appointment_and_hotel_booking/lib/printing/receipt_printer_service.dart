import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_settings_model.dart';
import '../services/api_service.dart';
import 'esc_pos.dart';
import 'lan_printer.dart';
import 'usb_printer.dart';

class PrintResult {
  final bool success;
  final String message;

  const PrintResult({required this.success, required this.message});
}

class ReceiptPrinterService {
  ReceiptPrinterService._();

  static const String _prefSelectedPrinterKey = 'pos_active_selected_printer'; // 'lan' | 'usb'
  static String? _inMemorySelectedPrinter;
  static PrinterSettingsModel? _cachedSettings;

  /// Synchronously returns the user-selected printer interface ('lan' or 'usb').
  static String getSelectedPrinterTypeSync() {
    if (_inMemorySelectedPrinter != null && _inMemorySelectedPrinter!.isNotEmpty) {
      return _inMemorySelectedPrinter!;
    }
    if (_cachedSettings != null) {
      return _cachedSettings!.selectedPrinter;
    }
    return 'usb';
  }

  /// Retrieves the user-selected printer interface ('lan' or 'usb').
  static Future<String> getSelectedPrinterType() async {
    if (_inMemorySelectedPrinter != null && _inMemorySelectedPrinter!.isNotEmpty) {
      return _inMemorySelectedPrinter!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefSelectedPrinterKey);
      if (saved != null && saved.isNotEmpty) {
        _inMemorySelectedPrinter = saved.toLowerCase().trim();
        return _inMemorySelectedPrinter!;
      }
    } catch (_) {}

    if (_cachedSettings != null) {
      return _cachedSettings!.selectedPrinter;
    }

    return 'usb';
  }

  /// Sets and persists the user-selected printer interface ('lan' or 'usb').
  static Future<void> setSelectedPrinterType(String type) async {
    final normalized = type.toLowerCase().trim() == 'usb' ? 'usb' : 'lan';
    _inMemorySelectedPrinter = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSelectedPrinterKey, normalized);
    } catch (_) {}

    if (_cachedSettings != null) {
      _cachedSettings = _cachedSettings!.copyWith(
        connectionType: normalized,
        selectedPrinter: normalized,
      );
    }
  }

  /// Stores settings in memory and updates persistent printer selection.
  static Future<void> saveActiveSettings(PrinterSettingsModel settings) async {
    _cachedSettings = settings;
    await setSelectedPrinterType(settings.selectedPrinter);
  }

  /// Fetches current active printer settings from backend / local cache.
  static Future<PrinterSettingsModel> getActiveSettings({int? businessId}) async {
    PrinterSettingsModel model;
    if (_cachedSettings != null) {
      model = _cachedSettings!;
    } else {
      model = await ApiService.getPrinterSettings(businessId: businessId);
      _cachedSettings = model;
    }

    final localPref = await getSelectedPrinterType();
    if (localPref.isNotEmpty && model.selectedPrinter != localPref) {
      model = model.copyWith(
        connectionType: localPref,
        selectedPrinter: localPref,
      );
      _cachedSettings = model;
    }

    return model;
  }

  /// Lists available USB or Spooler printers on Android or Windows.
  static Future<List<UsbPrinterDevice>> getUsbPrintersList() async {
    return await getUsbPrinters();
  }

  /// Executes a test print using strictly the chosen printer destination.
  static Future<PrintResult> testPrint(
    PrinterSettingsModel settings, {
    String? targetPrinter,
  }) async {
    try {
      final effectiveTarget = (targetPrinter ?? settings.selectedPrinter).toLowerCase().trim();
      final buffer = buildEscPosTestPrint(settings, testText: 'Test Printing');

      if (effectiveTarget == 'usb') {
        var targetDevice = settings.usbDeviceKey ?? settings.usbDeviceName ?? '';
        if (targetDevice.isEmpty) {
          final attached = await getUsbPrinters();
          if (attached.isNotEmpty) {
            targetDevice = attached.first.deviceKey;
          } else {
            return const PrintResult(
              success: false,
              message: 'No USB printer device selected or connected. Please select a USB printer in settings.',
            );
          }
        }

        await sendRawToUsb(deviceName: targetDevice, bytes: buffer);
        return PrintResult(
          success: true,
          message: 'Successfully printed "Test Printing" to USB printer ($targetDevice)!',
        );
      } else {
        // LAN Printer: Strictly LAN
        final ip = settings.ipAddress.trim();
        if (ip.isEmpty) {
          return const PrintResult(
            success: false,
            message: 'LAN printer IP address is not configured.',
          );
        }

        try {
          await sendToLanPrinter(ip, settings.port, buffer);
          return PrintResult(
            success: true,
            message: 'Successfully printed "Test Printing" to LAN printer at $ip:${settings.port}!',
          );
        } catch (socketErr) {
          debugPrint('Direct LAN test print error, trying backend proxy: $socketErr');
          final apiRes = await ApiService.testPrint(settings.toJson());
          return PrintResult(
            success: apiRes.success,
            message: apiRes.message,
          );
        }
      }
    } catch (e) {
      debugPrint('Error during test print: $e');
      return PrintResult(
        success: false,
        message: 'Test print failed: $e',
      );
    }
  }

  /// Prints a Customer Order Receipt for a Sale or Appointment.
  ///
  /// Guarantees that only the selected printer (LAN or USB) is used,
  /// even if both printers are connected simultaneously.
  static Future<PrintResult> printReceipt({
    required dynamic transaction,
    PrinterSettingsModel? settings,
    String? targetPrinter, // 'lan' | 'usb' (explicit selection override)
    bool isReprint = false,
    String? type,
  }) async {
    try {
      final config = settings ?? await getActiveSettings();

      if (!config.isEnabled) {
        return const PrintResult(
          success: false,
          message: 'Printer is disabled in settings. Print skipped.',
        );
      }

      if (!config.orderReceiptEnabled) {
        return const PrintResult(
          success: false,
          message: 'Customer Order Receipt is disabled in settings. Print skipped.',
        );
      }

      // Determine strictly selected target printer
      final effectiveTarget = (targetPrinter ?? (await getSelectedPrinterType())).toLowerCase().trim();

      final Uint8List buffer = buildEscPosReceipt(
        settings: config,
        transaction: transaction,
        isReprint: isReprint,
        type: type,
      );

      if (effectiveTarget == 'usb') {
        // STRICT USB ROUTE: Only prints to USB
        var targetDevice = config.usbDeviceKey ?? config.usbDeviceName ?? '';
        if (targetDevice.isEmpty) {
          final attached = await getUsbPrinters();
          if (attached.isNotEmpty) {
            targetDevice = attached.first.deviceKey;
          } else {
            return const PrintResult(
              success: false,
              message: 'USB printer is selected, but no USB device was detected. Please connect your USB printer.',
            );
          }
        }

        await sendRawToUsb(deviceName: targetDevice, bytes: buffer);
        return PrintResult(
          success: true,
          message: isReprint
              ? 'Reprinted receipt via USB printer ($targetDevice).'
              : 'Printed receipt via USB printer ($targetDevice).',
        );
      } else {
        // STRICT LAN ROUTE: Only prints to LAN
        final ip = config.ipAddress.trim();
        if (ip.isEmpty) {
          return const PrintResult(
            success: false,
            message: 'LAN printer is selected, but LAN IP address is not configured.',
          );
        }

        try {
          await sendToLanPrinter(ip, config.port, buffer);
          return PrintResult(
            success: true,
            message: isReprint
                ? 'Reprinted receipt via LAN printer ($ip:${config.port}).'
                : 'Printed receipt via LAN printer ($ip:${config.port}).',
          );
        } catch (socketErr) {
          debugPrint('Direct LAN print error, trying backend proxy: $socketErr');
          final payload = <String, dynamic>{
            'printer_settings': config.toJson(),
            'is_reprint': isReprint,
            'type': type,
          };
          if (type == 'appointment' || (transaction is Map && transaction['appointment_date'] != null)) {
            payload['appointment'] = (transaction is Map) ? transaction : transaction.toJson();
          } else {
            payload['sale'] = (transaction is Map) ? transaction : transaction.toJson();
          }

          final apiRes = await ApiService.printReceipt(payload);
          return PrintResult(
            success: apiRes.success,
            message: apiRes.message,
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return PrintResult(
        success: false,
        message: 'Printing failed: $e',
      );
    }
  }
}

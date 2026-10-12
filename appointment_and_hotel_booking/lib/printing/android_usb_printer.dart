import 'package:flutter/services.dart';

const MethodChannel _methods = MethodChannel('pos/usb_printer');
const EventChannel _events = EventChannel('pos/usb_printer/events');

/// A printer currently attached to the device's USB port on Android.
class AndroidUsbPrinter {
  /// Stable identity: `usb:<vendor>:<product>`
  final String deviceKey;

  /// Manufacturer and product display name for selection.
  final String displayName;

  /// Whether the user has already granted USB access to this device.
  final bool hasPermission;

  const AndroidUsbPrinter({
    required this.deviceKey,
    required this.displayName,
    required this.hasPermission,
  });
}

/// Enumerates attached printers via Android USB Host API.
Future<List<AndroidUsbPrinter>> listAndroidUsbPrinters() async {
  try {
    final raw = await _methods.invokeListMethod<Map<dynamic, dynamic>>('list');
    if (raw == null) return const [];
    return raw
        .map((row) => AndroidUsbPrinter(
              deviceKey: row['deviceKey'] as String? ?? '',
              displayName: row['displayName'] as String? ?? 'USB Printer',
              hasPermission: row['hasPermission'] == true,
            ))
        .where((p) => p.deviceKey.isNotEmpty)
        .toList();
  } on PlatformException {
    return const [];
  } on MissingPluginException {
    return const [];
  } catch (_) {
    return const [];
  }
}

/// Requests USB runtime permission for [deviceKey].
Future<bool> requestAndroidUsbPermission(String deviceKey) async {
  try {
    final granted = await _methods.invokeMethod<bool>(
      'requestPermission',
      {'deviceKey': deviceKey},
    );
    return granted ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  } catch (_) {
    return false;
  }
}

/// Sends ESC/POS raw bytes directly to Android USB printer bulk endpoint.
Future<void> printViaAndroidUsb({
  required String deviceKey,
  required Uint8List bytes,
}) async {
  try {
    await _methods.invokeMethod<bool>('write', {
      'deviceKey': deviceKey,
      'bytes': bytes,
    });
  } on PlatformException catch (err) {
    throw Exception(err.message ?? 'USB printing failed.');
  } on MissingPluginException {
    throw Exception('USB printing is not available on this device.');
  }
}

Stream<String>? _hotplug;

/// Emits when a USB device is attached or detached on Android.
Stream<String> androidUsbHotplug() {
  return _hotplug ??= _events
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .handleError((_) {});
}

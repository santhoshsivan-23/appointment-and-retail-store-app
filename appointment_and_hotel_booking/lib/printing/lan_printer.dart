import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Sends ESC/POS raw bytes over TCP socket to a network/LAN printer.
///
/// Typically uses port 9100 (standard raw ESC/POS port).
Future<void> sendToLanPrinter(
  String? ipAddress,
  int? port,
  Uint8List buffer,
) async {
  final ip = ipAddress?.trim() ?? '';
  if (ip.isEmpty) {
    throw Exception('LAN printer IP address is not configured.');
  }

  final targetPort = (port != null && port > 0) ? port : 9100;
  Socket? socket;

  try {
    socket = await Socket.connect(
      ip,
      targetPort,
      timeout: const Duration(seconds: 5),
    );
  } on TimeoutException {
    throw Exception('Connection timed out. LAN printer at $ip:$targetPort did not answer within 5 seconds.');
  } catch (e) {
    throw Exception('Failed to connect to LAN printer at $ip:$targetPort ($e)');
  }

  try {
    socket.add(buffer);
    await socket.flush().timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Timed out while sending data to printer.'),
    );
    await socket.close();
  } catch (e) {
    socket.destroy();
    rethrow;
  }
}

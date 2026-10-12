import 'dart:io';
import 'dart:typed_data';

import 'android_usb_printer.dart';

/// Descriptor for a USB or spooler printer on Android or Windows.
class UsbPrinterDevice {
  final String deviceKey;
  final String displayName;
  final bool hasPermission;

  const UsbPrinterDevice({
    required this.deviceKey,
    required this.displayName,
    this.hasPermission = true,
  });
}

const String _psScriptContent = r'''
$code = @"
using System;
using System.Runtime.InteropServices;

public class RawPrinterHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDataType;
    }

    [DllImport("winspool.drv", EntryPoint = "OpenPrinterA", CharSet = CharSet.Ansi, SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "StartDocPrinterA", CharSet = CharSet.Ansi, SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);

    public static bool SendBytesToPrinter(string szPrinterName, byte[] bytes) {
        IntPtr hPrinter = IntPtr.Zero;
        DOCINFOA di = new DOCINFOA();
        bool bSuccess = false;

        di.pDocName = "POS Receipt";
        di.pDataType = "RAW";

        if (OpenPrinter(szPrinterName.Normalize(), out hPrinter, IntPtr.Zero)) {
            if (StartDocPrinter(hPrinter, 1, di)) {
                if (StartPagePrinter(hPrinter)) {
                    IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
                    Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);
                    Int32 dwWritten = 0;
                    bSuccess = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out dwWritten);
                    Marshal.FreeCoTaskMem(pUnmanagedBytes);
                    EndPagePrinter(hPrinter);
                }
                EndDocPrinter(hPrinter);
            }
            ClosePrinter(hPrinter);
        }
        return bSuccess;
    }
}
"@

Add-Type -TypeDefinition $code
$bytes = [System.IO.File]::ReadAllBytes($args[0])
$success = [RawPrinterHelper]::SendBytesToPrinter($args[1], $bytes)
if (-not $success) {
    throw "Failed to send bytes to printer spooler."
}
''';

/// Enumerates attached USB printers across platforms.
Future<List<UsbPrinterDevice>> getUsbPrinters() async {
  if (Platform.isAndroid) {
    final androidPrinters = await listAndroidUsbPrinters();
    return androidPrinters
        .map((p) => UsbPrinterDevice(
              deviceKey: p.deviceKey,
              displayName: p.displayName,
              hasPermission: p.hasPermission,
            ))
        .toList();
  }

  if (Platform.isWindows) {
    try {
      final res = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-Command',
          'Get-CimInstance Win32_Printer | Select-Object -ExpandProperty Name',
        ],
        runInShell: false,
      );
      if (res.exitCode == 0 && res.stdout != null) {
        final lines = (res.stdout as String)
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return lines
            .map((name) => UsbPrinterDevice(
                  deviceKey: name,
                  displayName: name,
                  hasPermission: true,
                ))
            .toList();
      }
    } catch (_) {}
  }

  return const [];
}

/// Sends raw ESC/POS bytes to a USB or Spooler printer.
///
/// Dispatches directly to [printViaAndroidUsb] on Android or Windows spooler P/Invoke on Windows.
Future<void> sendRawToUsb({
  required String deviceName,
  required Uint8List bytes,
}) async {
  if (Platform.isAndroid) {
    await printViaAndroidUsb(deviceKey: deviceName, bytes: bytes);
    return;
  }

  if (!Platform.isWindows) {
    throw Exception(
        'USB printing is only supported on Android and Windows platforms. '
        'For other platforms, please connect the printer as a LAN printer.');
  }

  // Windows Spooler Execution
  final tempDir = Directory.systemTemp.path;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final binPath = '$tempDir${Platform.pathSeparator}receipt-$stamp.bin';
  final scriptPath = '$tempDir${Platform.pathSeparator}print-raw-$stamp.ps1';

  try {
    await File(binPath).writeAsBytes(bytes, flush: true);
    await File(scriptPath).writeAsString(_psScriptContent, flush: true);

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        binPath,
        deviceName,
      ],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr ?? '').toString().trim();
      throw Exception(
          'USB printing failed: ${stderr.isNotEmpty ? stderr : 'exit code ${result.exitCode}'}');
    }
  } finally {
    try {
      await File(binPath).delete();
    } catch (_) {}
    try {
      await File(scriptPath).delete();
    } catch (_) {}
  }
}

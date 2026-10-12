package com.example.appointment_and_hotel_booking

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register USB thermal printer channel
        val usbPrinter = UsbPrinterChannel(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UsbPrinterChannel.METHOD_CHANNEL
        ).setMethodCallHandler(usbPrinter)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UsbPrinterChannel.EVENT_CHANNEL
        ).setStreamHandler(usbPrinter)
    }
}

package com.example.appointment_and_hotel_booking

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * USB host support for directly-attached ESC/POS thermal printers.
 *
 * Windows builds reach USB printers through the Windows spooler (winspool.drv RAW datatype).
 * Android has no print spooler, so the app talks directly to the printer over the Android USB host API.
 * This channel enumerates attached printers, requests permissions, and writes ESC/POS bytes to the bulk endpoint.
 */
class UsbPrinterChannel(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "pos/usb_printer"
        const val EVENT_CHANNEL = "pos/usb_printer/events"

        private const val ACTION_USB_PERMISSION =
            "com.example.appointment_and_hotel_booking.USB_PERMISSION"

        /** Per-transfer ceiling. Larger receipts are split into multiple chunks. */
        private const val CHUNK_BYTES = 4096

        /** Milliseconds allowed for one bulk transfer. */
        private const val TRANSFER_TIMEOUT_MS = 5000

        /**
         * Vendors whose thermal printers announce themselves as
         * vendor-specific (0xFF) rather than as USB class 7 (Printers).
         */
        private val PRINTER_VENDOR_IDS = setOf(
            0x04b8, // Epson
            0x0519, // Star Micronics
            0x1504, // Bixolon
            0x1d90, // Citizen
            0x0dd4, // Custom / Bematech
            0x0416, // Winbond - Xprinter, POS-58, POS-80
            0x0483, // STMicro - Generic ESC/POS boards
            0x20d1, // Rongta
            0x6868, // Zjiang / Goojprt
            0x0fe6, // ICS Advent - Generic POS58
            0x28e9, // GD32 - Generic ESC/POS boards
        )
    }

    private val usbManager: UsbManager
        get() = context.getSystemService(Context.USB_SERVICE) as UsbManager

    /** Bulk transfers must not block the Flutter platform thread. */
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var events: EventChannel.EventSink? = null
    private var hotplugReceiver: BroadcastReceiver? = null

    // -- Method Channel Handlers --

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "list" -> result.success(listPrinters())

            "hasPermission" -> {
                val device = findDevice(call.argument("deviceKey"))
                result.success(device != null && usbManager.hasPermission(device))
            }

            "requestPermission" -> {
                val device = findDevice(call.argument("deviceKey"))
                if (device == null) {
                    result.success(false)
                } else {
                    requestPermission(device) { granted -> result.success(granted) }
                }
            }

            "write" -> {
                val device = findDevice(call.argument("deviceKey"))
                val bytes = call.argument<ByteArray>("bytes")
                if (device == null) {
                    result.error(
                        "not_found",
                        "That USB printer is no longer connected.",
                        null
                    )
                    return
                }
                if (bytes == null || bytes.isEmpty()) {
                    result.error("bad_args", "Nothing to print.", null)
                    return
                }
                requestPermission(device) { granted ->
                    if (!granted) {
                        result.error(
                            "permission_denied",
                            "USB permission was refused for this printer.",
                            null
                        )
                    } else {
                        writeAsync(device, bytes, result)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    // -- Discovery & Helpers --

    private fun listPrinters(): List<Map<String, Any?>> =
        usbManager.deviceList.values
            .filter { isPrinter(it) }
            .map { device ->
                mapOf(
                    "deviceKey" to deviceKey(device),
                    "displayName" to displayName(device),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "hasPermission" to usbManager.hasPermission(device),
                )
            }

    private fun isPrinter(device: UsbDevice): Boolean {
        if (device.vendorId in PRINTER_VENDOR_IDS) return true
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                return true
            }
        }
        return false
    }

    private fun deviceKey(device: UsbDevice): String =
        "usb:%04x:%04x".format(device.vendorId, device.productId)

    private fun displayName(device: UsbDevice): String {
        val product = device.productName?.trim().orEmpty()
        val maker = device.manufacturerName?.trim().orEmpty()
        val label = listOf(maker, product).filter { it.isNotEmpty() }.joinToString(" ")
        return if (label.isEmpty()) {
            "USB printer (%04x:%04x)".format(device.vendorId, device.productId)
        } else {
            "$label (USB)"
        }
    }

    private fun findDevice(key: String?): UsbDevice? {
        if (key.isNullOrEmpty()) return null
        return usbManager.deviceList.values.firstOrNull {
            deviceKey(it).equals(key, ignoreCase = true)
        }
    }

    // -- Permissions --

    private fun requestPermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        if (usbManager.hasPermission(device)) {
            onResult(true)
            return
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != ACTION_USB_PERMISSION) return
                try {
                    ctx.unregisterReceiver(this)
                } catch (_: IllegalArgumentException) {
                }
                onResult(
                    intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                )
            }
        }

        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        registerReceiverCompat(receiver, IntentFilter(ACTION_USB_PERMISSION), exported = false)
        usbManager.requestPermission(
            device,
            PendingIntent.getBroadcast(context, 0, intent, flags)
        )
    }

    // -- Writing to USB Bulk Endpoint --

    private fun writeAsync(
        device: UsbDevice,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        io.execute {
            val error = try {
                write(device, bytes)
                null
            } catch (err: Exception) {
                err.message ?: err.toString()
            }
            main.post {
                if (error == null) result.success(true)
                else result.error("print_failed", error, null)
            }
        }
    }

    private fun write(device: UsbDevice, bytes: ByteArray) {
        val (iface, endpoint) = bulkOut(device)
            ?: throw IllegalStateException(
                "This USB device has no printer endpoint to send data to."
            )

        val connection: UsbDeviceConnection = usbManager.openDevice(device)
            ?: throw IllegalStateException("Could not open the USB printer.")

        try {
            if (!connection.claimInterface(iface, true)) {
                throw IllegalStateException(
                    "The USB printer is busy - another app is holding it."
                )
            }

            var offset = 0
            while (offset < bytes.size) {
                val size = minOf(CHUNK_BYTES, bytes.size - offset)
                val chunk = bytes.copyOfRange(offset, offset + size)
                val sent = connection.bulkTransfer(
                    endpoint, chunk, chunk.size, TRANSFER_TIMEOUT_MS
                )
                if (sent < 0) {
                    throw IllegalStateException(
                        "The USB printer stopped accepting data after $offset bytes."
                    )
                }
                offset += if (sent == 0) size else sent
            }
        } finally {
            try {
                connection.releaseInterface(iface)
            } catch (_: Exception) {
            }
            connection.close()
        }
    }

    private fun bulkOut(device: UsbDevice): Pair<UsbInterface, UsbEndpoint>? {
        var fallback: Pair<UsbInterface, UsbEndpoint>? = null

        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            for (e in 0 until iface.endpointCount) {
                val endpoint = iface.getEndpoint(e)
                if (endpoint.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
                if (endpoint.direction != UsbConstants.USB_DIR_OUT) continue

                val pair = iface to endpoint
                if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return pair
                if (fallback == null) fallback = pair
            }
        }
        return fallback
    }

    // -- Hot-plug events --

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED ->
                        main.post { events?.success("attached") }
                    UsbManager.ACTION_USB_DEVICE_DETACHED ->
                        main.post { events?.success("detached") }
                }
            }
        }
        hotplugReceiver = receiver

        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        registerReceiverCompat(receiver, filter, exported = true)
    }

    override fun onCancel(arguments: Any?) {
        hotplugReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        hotplugReceiver = null
        events = null
    }

    private fun registerReceiverCompat(
        receiver: BroadcastReceiver,
        filter: IntentFilter,
        exported: Boolean
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val flag =
                if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED
            context.registerReceiver(receiver, filter, flag)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
    }
}

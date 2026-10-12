class PrinterSettingsModel {
  final String printerName;
  final String connectionType; // 'lan' | 'usb'
  final String selectedPrinter; // 'lan' | 'usb' (explicit user selection)
  final String ipAddress;
  final int port;
  final String paperSize; // 'mm80' | 'mm58'
  final String businessName;
  final String phoneNumber;
  final String addrLine1;
  final String addrLine2;
  final String addrLine3;
  final String addrLine4;
  final String headerNote;
  final String footerNote;
  final bool isDefault;
  final bool isEnabled;
  final bool orderReceiptEnabled;
  final bool autoCut;
  final bool openCashDrawer;
  // USB attributes
  final String? usbDeviceName;
  final String? usbDeviceKey; // 'usb:<vendorId>:<productId>' or Windows device name

  bool get isUsbSelected => (selectedPrinter.toLowerCase() == 'usb' || connectionType.toLowerCase() == 'usb');
  bool get isLanSelected => !isUsbSelected;
  String get effectiveTargetPrinter => isUsbSelected ? 'usb' : 'lan';

  const PrinterSettingsModel({
    this.printerName = 'Main Counter ESC/POS Printer',
    this.connectionType = 'lan',
    String? selectedPrinter,
    this.ipAddress = '192.168.1.51',
    this.port = 9100,
    this.paperSize = 'mm80',
    this.businessName = 'IQ RESTAURANT & POS',
    this.phoneNumber = '',
    this.addrLine1 = '',
    this.addrLine2 = '',
    this.addrLine3 = '',
    this.addrLine4 = '',
    this.headerNote = 'Thank you for your visit!',
    this.footerNote = 'Thank you for your visit! Please come again.',
    this.isDefault = true,
    this.isEnabled = true,
    this.orderReceiptEnabled = true,
    this.autoCut = true,
    this.openCashDrawer = false,
    this.usbDeviceName,
    this.usbDeviceKey,
  }) : selectedPrinter = selectedPrinter ?? connectionType;

  factory PrinterSettingsModel.defaultSettings({String? businessName}) {
    return PrinterSettingsModel(
      businessName: businessName ?? 'IQ RESTAURANT & POS',
    );
  }

  factory PrinterSettingsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PrinterSettingsModel.defaultSettings();

    final rawType = (json['selected_printer'] ?? json['connection_type'])
        ?.toString()
        .toLowerCase()
        .trim();
    final connType = (rawType == 'usb') ? 'usb' : 'lan';

    return PrinterSettingsModel(
      printerName: json['printer_name']?.toString() ?? 'Main Counter ESC/POS Printer',
      connectionType: connType,
      selectedPrinter: connType,
      ipAddress: json['ip_address']?.toString() ?? '192.168.1.51',
      port: int.tryParse(json['port']?.toString() ?? '9100') ?? 9100,
      paperSize: (json['paper_size']?.toString().toLowerCase() == 'mm58') ? 'mm58' : 'mm80',
      businessName: json['business_name']?.toString() ?? 'IQ RESTAURANT & POS',
      phoneNumber: json['phone_number']?.toString() ?? '',
      addrLine1: json['addr_line1']?.toString() ?? '',
      addrLine2: json['addr_line2']?.toString() ?? '',
      addrLine3: json['addr_line3']?.toString() ?? '',
      addrLine4: json['addr_line4']?.toString() ?? '',
      headerNote: json['header_note']?.toString() ?? 'Thank you for your visit!',
      footerNote: json['footer_note']?.toString() ?? 'Thank you for your visit! Please come again.',
      isDefault: json['is_default'] != false,
      isEnabled: json['is_enabled'] != false,
      orderReceiptEnabled: json['order_receipt_enabled'] != false,
      autoCut: json['auto_cut'] != false,
      openCashDrawer: json['open_cash_drawer'] == true,
      usbDeviceName: json['usb_device_name']?.toString(),
      usbDeviceKey: json['usb_device_key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'printer_name': printerName,
      'connection_type': connectionType,
      'selected_printer': selectedPrinter,
      'ip_address': ipAddress,
      'port': port,
      'paper_size': paperSize,
      'business_name': businessName,
      'phone_number': phoneNumber,
      'addr_line1': addrLine1,
      'addr_line2': addrLine2,
      'addr_line3': addrLine3,
      'addr_line4': addrLine4,
      'header_note': headerNote,
      'footer_note': footerNote,
      'is_default': isDefault,
      'is_enabled': isEnabled,
      'order_receipt_enabled': orderReceiptEnabled,
      'auto_cut': autoCut,
      'open_cash_drawer': openCashDrawer,
      if (usbDeviceName != null) 'usb_device_name': usbDeviceName,
      if (usbDeviceKey != null) 'usb_device_key': usbDeviceKey,
    };
  }

  PrinterSettingsModel copyWith({
    String? printerName,
    String? connectionType,
    String? selectedPrinter,
    String? ipAddress,
    int? port,
    String? paperSize,
    String? businessName,
    String? phoneNumber,
    String? addrLine1,
    String? addrLine2,
    String? addrLine3,
    String? addrLine4,
    String? headerNote,
    String? footerNote,
    bool? isDefault,
    bool? isEnabled,
    bool? orderReceiptEnabled,
    bool? autoCut,
    bool? openCashDrawer,
    String? usbDeviceName,
    String? usbDeviceKey,
  }) {
    final finalConn = connectionType ?? this.connectionType;
    final finalSel = selectedPrinter ?? connectionType ?? this.selectedPrinter;
    return PrinterSettingsModel(
      printerName: printerName ?? this.printerName,
      connectionType: finalConn,
      selectedPrinter: finalSel,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      paperSize: paperSize ?? this.paperSize,
      businessName: businessName ?? this.businessName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addrLine1: addrLine1 ?? this.addrLine1,
      addrLine2: addrLine2 ?? this.addrLine2,
      addrLine3: addrLine3 ?? this.addrLine3,
      addrLine4: addrLine4 ?? this.addrLine4,
      headerNote: headerNote ?? this.headerNote,
      footerNote: footerNote ?? this.footerNote,
      isDefault: isDefault ?? this.isDefault,
      isEnabled: isEnabled ?? this.isEnabled,
      orderReceiptEnabled: orderReceiptEnabled ?? this.orderReceiptEnabled,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      usbDeviceName: usbDeviceName ?? this.usbDeviceName,
      usbDeviceKey: usbDeviceKey ?? this.usbDeviceKey,
    );
  }
}

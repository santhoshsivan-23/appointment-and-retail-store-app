import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/business_model.dart';
import '../models/printer_settings_model.dart';
import '../printing/android_usb_printer.dart';
import '../printing/receipt_printer_service.dart';
import '../printing/usb_printer.dart';
import '../services/api_service.dart';

class PrinterSettingsView extends StatefulWidget {
  final BusinessModel business;

  const PrinterSettingsView({super.key, required this.business});

  @override
  State<PrinterSettingsView> createState() => _PrinterSettingsViewState();
}

class _PrinterSettingsViewState extends State<PrinterSettingsView> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;

  // Controllers
  late TextEditingController _printerNameCtrl;
  late TextEditingController _ipAddressCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _businessNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addr1Ctrl;
  late TextEditingController _addr2Ctrl;
  late TextEditingController _addr3Ctrl;
  late TextEditingController _addr4Ctrl;
  late TextEditingController _headerNoteCtrl;
  late TextEditingController _footerNoteCtrl;

  // Form options
  String _connectionType = 'lan'; // 'lan' | 'usb'
  String _paperSize = 'mm80'; // 'mm80' | 'mm58'
  bool _isEnabled = true;
  bool _orderReceiptEnabled = true;
  bool _autoCut = true;
  bool _openCashDrawer = false;

  // USB Device state
  String? _selectedUsbKey;
  String? _selectedUsbName;
  List<UsbPrinterDevice> _availableUsbPrinters = [];
  bool _isLoadingUsbList = false;

  // Test print status banner
  String? _statusMessage;
  bool _statusSuccess = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPrinterSettings();
    _fetchUsbPrinters();
  }

  void _initControllers() {
    final bName = widget.business.businessName.trim().isNotEmpty
        ? widget.business.businessName.trim()
        : 'IQ Store';

    _printerNameCtrl = TextEditingController(text: 'Main Counter POS Printer');
    _ipAddressCtrl = TextEditingController(text: '192.168.1.51');
    _portCtrl = TextEditingController(text: '9100');
    _businessNameCtrl = TextEditingController(text: bName);
    _phoneCtrl = TextEditingController(text: '+1 (555) 019-2834');
    _addr1Ctrl = TextEditingController(text: '100 Terminal Boulevard');
    _addr2Ctrl = TextEditingController(text: 'Suite 400');
    _addr3Ctrl = TextEditingController(text: 'New York, NY 10001');
    _addr4Ctrl = TextEditingController(text: 'Tax ID: US-987654321');
    _headerNoteCtrl = TextEditingController(text: 'Tax Invoice / Official Receipt');
    _footerNoteCtrl = TextEditingController(text: 'Thank you for your visit! Please come again.');
  }

  @override
  void dispose() {
    _printerNameCtrl.dispose();
    _ipAddressCtrl.dispose();
    _portCtrl.dispose();
    _businessNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _addr3Ctrl.dispose();
    _addr4Ctrl.dispose();
    _headerNoteCtrl.dispose();
    _footerNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrinterSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ReceiptPrinterService.getActiveSettings(businessId: widget.business.id);

      _printerNameCtrl.text = settings.printerName;
      _connectionType = settings.selectedPrinter;
      _ipAddressCtrl.text = settings.ipAddress;
      _portCtrl.text = settings.port.toString();
      _paperSize = settings.paperSize;
      _businessNameCtrl.text = settings.businessName.isNotEmpty
          ? settings.businessName
          : (widget.business.businessName.isNotEmpty ? widget.business.businessName : 'IQ Store');
      _phoneCtrl.text = settings.phoneNumber;
      _addr1Ctrl.text = settings.addrLine1;
      _addr2Ctrl.text = settings.addrLine2;
      _addr3Ctrl.text = settings.addrLine3;
      _addr4Ctrl.text = settings.addrLine4;
      _headerNoteCtrl.text = settings.headerNote;
      _footerNoteCtrl.text = settings.footerNote;
      _isEnabled = settings.isEnabled;
      _orderReceiptEnabled = settings.orderReceiptEnabled;
      _autoCut = settings.autoCut;
      _openCashDrawer = settings.openCashDrawer;
      _selectedUsbKey = settings.usbDeviceKey;
      _selectedUsbName = settings.usbDeviceName;
    } catch (e) {
      debugPrint('Failed to load printer settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsbPrinters() async {
    setState(() => _isLoadingUsbList = true);
    try {
      final list = await ReceiptPrinterService.getUsbPrintersList();
      if (!mounted) return;
      setState(() {
        _availableUsbPrinters = list;
        if (_selectedUsbKey != null && list.any((p) => p.deviceKey == _selectedUsbKey)) {
          // Keep current selection
        } else if (list.isNotEmpty && (_selectedUsbKey == null || _selectedUsbKey!.isEmpty)) {
          _selectedUsbKey = list.first.deviceKey;
          _selectedUsbName = list.first.displayName;
        }
      });
    } catch (e) {
      debugPrint('Error listing USB printers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsbList = false);
    }
  }

  PrinterSettingsModel _getCurrentSettingsModel() {
    return PrinterSettingsModel(
      printerName: _printerNameCtrl.text.trim(),
      connectionType: _connectionType,
      selectedPrinter: _connectionType,
      ipAddress: _ipAddressCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 9100,
      paperSize: _paperSize,
      businessName: _businessNameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      addrLine1: _addr1Ctrl.text.trim(),
      addrLine2: _addr2Ctrl.text.trim(),
      addrLine3: _addr3Ctrl.text.trim(),
      addrLine4: _addr4Ctrl.text.trim(),
      headerNote: _headerNoteCtrl.text.trim(),
      footerNote: _footerNoteCtrl.text.trim(),
      isEnabled: _isEnabled,
      orderReceiptEnabled: _orderReceiptEnabled,
      autoCut: _autoCut,
      openCashDrawer: _openCashDrawer,
      usbDeviceKey: _selectedUsbKey,
      usbDeviceName: _selectedUsbName,
    );
  }

  Future<void> _saveSettings() async {
    final name = _printerNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Printer name cannot be blank.', isError: true);
      return;
    }

    if (_connectionType == 'lan') {
      final ip = _ipAddressCtrl.text.trim();
      if (ip.isEmpty) {
        _showSnack('LAN IP address is required for LAN printer.', isError: true);
        return;
      }
    } else if (_connectionType == 'usb') {
      if (_selectedUsbKey == null || _selectedUsbKey!.isEmpty) {
        _showSnack('Please select a USB printer device.', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    final model = _getCurrentSettingsModel();

    try {
      // 1. Immediately persist locally in memory and SharedPreferences
      await ReceiptPrinterService.saveActiveSettings(model);

      // 2. Persist to backend database
      final res = await ApiService.updatePrinterSettings(
        model.toJson(),
        businessId: widget.business.id,
      );

      final label = _connectionType == 'usb'
          ? 'USB (${_selectedUsbName ?? _selectedUsbKey ?? 'Printer'})'
          : 'LAN (${_ipAddressCtrl.text.trim()}:${_portCtrl.text.trim()})';

      if (res.success) {
        setState(() {
          _statusMessage = 'Active printer set to $label. Settings saved and applied successfully!';
          _statusSuccess = true;
        });
        _showSnack('Active printer set to $label. Settings saved!');
      } else {
        setState(() {
          _statusMessage = 'Active printer set to $label locally.';
          _statusSuccess = true;
        });
        _showSnack('Active printer set to $label!');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Settings applied locally. Server notice: $e';
        _statusSuccess = true;
      });
      _showSnack('Active printer updated locally.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _runTestPrint({String? targetOverride}) async {
    final target = targetOverride ?? _connectionType;
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final model = _getCurrentSettingsModel().copyWith(
      selectedPrinter: target,
      connectionType: target,
    );

    // On Android, if USB, ensure permission first
    if (target == 'usb' && Platform.isAndroid && _selectedUsbKey != null) {
      final hasPerm = await requestAndroidUsbPermission(_selectedUsbKey!);
      if (!hasPerm) {
        setState(() {
          _isTesting = false;
          _statusMessage = 'USB permission was refused for this printer on Android.';
          _statusSuccess = false;
        });
        _showSnack('USB permission denied on Android', isError: true);
        return;
      }
    }

    try {
      final result = await ReceiptPrinterService.testPrint(model, targetPrinter: target);
      setState(() {
        _statusMessage = result.message;
        _statusSuccess = result.success;
      });
      if (result.success) {
        _showSnack(result.message);
      } else {
        _showSnack(result.message, isError: true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Test print error: $e';
        _statusSuccess = false;
      });
      _showSnack('Test print failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                ],
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 950) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildFormSections()),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: _buildLiveReceiptPreview()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildFormSections(),
                          const SizedBox(height: 24),
                          _buildLiveReceiptPreview(),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final themeColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.withValues(alpha: 0.12),
                      themeColor.withValues(alpha: 0.24),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.print_rounded, color: themeColor, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Printer Configuration',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure ESC/POS thermal printing via LAN (TCP:9100) or USB cable',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isTesting ? null : _runTestPrint,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(_isTesting ? 'Printing...' : 'Test Print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isSuccess = _statusSuccess;
    final bg = isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final border = isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final text = isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: text),
            onPressed: () => setState(() => _statusMessage = null),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildFormSections() {
    return Column(
      children: [
        _buildConnectionCard(),
        const SizedBox(height: 20),
        _buildStoreDetailsCard(),
        const SizedBox(height: 20),
        _buildHardwareTogglesCard(),
      ],
    );
  }

  Widget _buildConnectionCard() {
    final themeColor = Theme.of(context).primaryColor;

    return _cardContainer(
      title: 'Connection & Active Printer Selection',
      icon: Icons.hub_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Printer Friendly Name'),
          TextField(
            controller: _printerNameCtrl,
            decoration: _inputDecoration('e.g. Main Counter Receipt Printer'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // 1. ACTIVE PRINTER SELECTION SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fieldLabel('Active Receipt Printer (Destination for All Receipts)'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _connectionType == 'usb' ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _connectionType == 'usb' ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  _connectionType == 'usb' ? 'ACTIVE: USB PRINTER' : 'ACTIVE: LAN PRINTER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _connectionType == 'usb' ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select which printer should print sales and appointment receipts when both are connected.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _selectionTile(
                  title: 'LAN / Network Printer',
                  subtitle: _ipAddressCtrl.text.trim().isNotEmpty
                      ? 'IP: ${_ipAddressCtrl.text.trim()}:${_portCtrl.text.trim()}'
                      : 'TCP Port 9100',
                  icon: Icons.wifi_rounded,
                  isSelected: _connectionType == 'lan',
                  onTap: () {
                    setState(() => _connectionType = 'lan');
                    ReceiptPrinterService.setSelectedPrinterType('lan');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectionTile(
                  title: 'Direct USB Printer',
                  subtitle: _selectedUsbName != null && _selectedUsbName!.isNotEmpty
                      ? _selectedUsbName!
                      : 'USB Cable (Windows/Android)',
                  icon: Icons.usb_rounded,
                  isSelected: _connectionType == 'usb',
                  onTap: () {
                    setState(() => _connectionType = 'usb');
                    ReceiptPrinterService.setSelectedPrinterType('usb');
                    _fetchUsbPrinters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. LAN CONFIGURATION BLOCK
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _connectionType == 'lan' ? const Color(0xFFF8FAFC) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _connectionType == 'lan' ? themeColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                width: _connectionType == 'lan' ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi_rounded, size: 18, color: _connectionType == 'lan' ? themeColor : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          'LAN Printer Setup',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _connectionType == 'lan' ? const Color(0xFF0F172A) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : () => _runTestPrint(targetOverride: 'lan'),
                      icon: const Icon(Icons.print_outlined, size: 14),
                      label: const Text('Test LAN', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Printer IP Address (Static recommended)'),
                          TextField(
                            controller: _ipAddressCtrl,
                            decoration: _inputDecoration('192.168.1.51'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Raw Port'),
                          TextField(
                            controller: _portCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('9100'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. USB CONFIGURATION BLOCK
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _connectionType == 'usb' ? const Color(0xFFF8FAFC) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _connectionType == 'usb' ? themeColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                width: _connectionType == 'usb' ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.usb_rounded, size: 18, color: _connectionType == 'usb' ? themeColor : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          'Direct USB Printer Setup',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _connectionType == 'usb' ? const Color(0xFF0F172A) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isLoadingUsbList ? null : _fetchUsbPrinters,
                          icon: _isLoadingUsbList
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _isTesting ? null : () => _runTestPrint(targetOverride: 'usb'),
                          icon: const Icon(Icons.print_outlined, size: 14),
                          label: const Text('Test USB', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _fieldLabel('Attached USB Printer Device'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _availableUsbPrinters.any((p) => p.deviceKey == _selectedUsbKey)
                          ? _selectedUsbKey
                          : null,
                      hint: Text(
                        _availableUsbPrinters.isEmpty
                            ? 'No USB printers detected. Connect USB printer and click Refresh.'
                            : 'Select attached USB printer',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                      items: _availableUsbPrinters.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.deviceKey,
                          child: Row(
                            children: [
                              Icon(Icons.print_rounded, size: 18, color: themeColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${p.displayName} (${p.deviceKey})',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p.hasPermission)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('READY', style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final item = _availableUsbPrinters.firstWhere((p) => p.deviceKey == val);
                          setState(() {
                            _selectedUsbKey = item.deviceKey;
                            _selectedUsbName = item.displayName;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _fieldLabel('Thermal Paper Roll Width'),
          Row(
            children: [
              Expanded(
                child: _selectionTile(
                  title: '80mm Roll (48 Columns)',
                  subtitle: 'Standard full-size receipt',
                  icon: Icons.receipt_rounded,
                  isSelected: _paperSize == 'mm80',
                  onTap: () => setState(() => _paperSize = 'mm80'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectionTile(
                  title: '58mm Roll (32 Columns)',
                  subtitle: 'Compact roll format',
                  icon: Icons.description_outlined,
                  isSelected: _paperSize == 'mm58',
                  onTap: () => setState(() => _paperSize = 'mm58'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetailsCard() {
    return _cardContainer(
      title: 'Receipt Header & Store Details',
      icon: Icons.storefront_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Business / Store Name'),
                    TextField(
                      controller: _businessNameCtrl,
                      decoration: _inputDecoration('Store Name'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Contact Phone'),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: _inputDecoration('+1 (555) 000-0000'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Address Line 1'),
                    TextField(
                      controller: _addr1Ctrl,
                      decoration: _inputDecoration('Street address'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Address Line 2 (Suite / Unit)'),
                    TextField(
                      controller: _addr2Ctrl,
                      decoration: _inputDecoration('Suite, floor, etc.'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Address Line 3 (City, State, Zip)'),
                    TextField(
                      controller: _addr3Ctrl,
                      decoration: _inputDecoration('City, State, Zip'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Address Line 4 (Tax ID / GST)'),
                    TextField(
                      controller: _addr4Ctrl,
                      decoration: _inputDecoration('e.g. GSTIN: 29AAAAA0000A1Z5'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Receipt Header Note / Invoice Title'),
          TextField(
            controller: _headerNoteCtrl,
            decoration: _inputDecoration('e.g. Official Tax Receipt'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareTogglesCard() {
    return _cardContainer(
      title: 'Footer & Hardware Actions',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Receipt Footer Message'),
          TextField(
            controller: _footerNoteCtrl,
            decoration: _inputDecoration('Thank you for visiting!'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          _switchTile(
            title: 'Auto Paper Cut',
            subtitle: 'Trigger full thermal paper cut (GS V) at end of receipt',
            value: _autoCut,
            onChanged: (v) => setState(() => _autoCut = v),
          ),
          const Divider(height: 1),
          _switchTile(
            title: 'Open Cash Drawer',
            subtitle: 'Send electric pulse (ESC p) to trigger cash drawer for cash sales',
            value: _openCashDrawer,
            onChanged: (v) => setState(() => _openCashDrawer = v),
          ),
          const Divider(height: 1),
          _switchTile(
            title: 'Customer Order Receipt',
            subtitle: 'Automatically print Customer Order Receipt upon payment completion',
            value: _orderReceiptEnabled,
            onChanged: (v) => setState(() => _orderReceiptEnabled = v),
          ),
          const Divider(height: 1),
          _switchTile(
            title: 'Master Printer Enable',
            subtitle: 'Toggle master printing state across the entire POS terminal',
            value: _isEnabled,
            onChanged: (v) => setState(() => _isEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveReceiptPreview() {
    final previewWidth = _paperSize == 'mm58' ? 280.0 : 360.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, size: 20, color: Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Text(
                    'Thermal Paper Preview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _paperSize == 'mm58' ? '58mm (32 Col)' : '80mm (48 Col)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: previewWidth,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF7), // Classic thermal paper tint
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store Header
                  Center(
                    child: Text(
                      _businessNameCtrl.text.trim().isNotEmpty
                          ? _businessNameCtrl.text.trim().toUpperCase()
                          : 'IQ RESTAURANT & POS',
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_addr1Ctrl.text.trim().isNotEmpty)
                    Text(
                      _addr1Ctrl.text.trim(),
                      style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  if (_phoneCtrl.text.trim().isNotEmpty)
                    Text(
                      'Tel: ${_phoneCtrl.text.trim()}',
                      style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  if (_headerNoteCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _headerNoteCtrl.text.trim(),
                      style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _previewDashedLine(),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: 12/10/2026', style: GoogleFonts.spaceMono(fontSize: 11)),
                      Text('Time: 17:30:00', style: GoogleFonts.spaceMono(fontSize: 11)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt: #REC-0084', style: GoogleFonts.spaceMono(fontSize: 11)),
                      Text('Pay: CASH', style: GoogleFonts.spaceMono(fontSize: 11)),
                    ],
                  ),
                  Text('Cashier: Alex Morgan', style: GoogleFonts.spaceMono(fontSize: 11)),
                  Text('Customer: John Doe (+1 555-1234)', style: GoogleFonts.spaceMono(fontSize: 11)),
                  const SizedBox(height: 4),
                  _previewDashedLine(),
                  const SizedBox(height: 4),
                  // Table Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Qty Item', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('Price', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _previewDashedLine(),
                  const SizedBox(height: 4),
                  // Sample Item 1
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('2x Deluxe Spa Shampoo', style: GoogleFonts.spaceMono(fontSize: 11)),
                      Text('\$40.00', style: GoogleFonts.spaceMono(fontSize: 11)),
                    ],
                  ),
                  Text('  @ \$20.00', style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black54)),
                  // Refund row
                  Text(
                    '  Refunded: 1x',
                    style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  // Sample Item 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1x Hair Styling Treatment', style: GoogleFonts.spaceMono(fontSize: 11)),
                      Text('\$30.00', style: GoogleFonts.spaceMono(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _previewDashedLine(),
                  const SizedBox(height: 4),
                  // Financials (reconciled GST & Net)
                  _previewMoneyRow('Subtotal', '\$50.00'),
                  _previewMoneyRow('Tax (8%)', '\$4.00'),
                  const SizedBox(height: 4),
                  const Text('================================', style: TextStyle(fontSize: 10, letterSpacing: -1)),
                  const SizedBox(height: 4),
                  _previewMoneyRow('Original Total', '\$74.00'),
                  _previewMoneyRow('TOTAL REFUNDED', '-\$21.60', isBold: true),
                  _previewDashedLine(),
                  _previewMoneyRow('NET AMOUNT PAID', '\$52.40', isBold: true),
                  const SizedBox(height: 8),
                  _previewDashedLine(),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _footerNoteCtrl.text.trim().isNotEmpty
                          ? _footerNoteCtrl.text.trim()
                          : 'Thank you for your visit!',
                      style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Center(
                    child: Text(
                      'Powered by IQ POS',
                      style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_autoCut)
                    Center(
                      child: Text(
                        '✂ - - - - - - [ AUTO CUT ] - - - - - -',
                        style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewDashedLine() {
    return const Text(
      '----------------------------------------',
      style: TextStyle(fontSize: 10, color: Colors.black45, letterSpacing: -0.5),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }

  Widget _previewMoneyRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer({required String title, required IconData icon, required Widget child}) {
    final themeColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: themeColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _selectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final themeColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? themeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? themeColor : const Color(0xFF64748B), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? themeColor : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: themeColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: themeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
    );
  }
}

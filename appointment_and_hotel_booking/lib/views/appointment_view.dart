import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/appointment_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/staff_model.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../widgets/staff_avatar.dart';

class AppointmentView extends StatefulWidget {
  final void Function(CustomerModel customer, List<ProductModel> products, {AppointmentModel? appointment})? onStartService;

  const AppointmentView({super.key, this.onStartService});

  @override
  State<AppointmentView> createState() => _AppointmentViewState();
}

class _AppointmentViewState extends State<AppointmentView> with SingleTickerProviderStateMixin {
  late AnimationController _calendarAnimCtrl;
  late Animation<double> _calendarAnim;
  // Data
  List<AppointmentModel> _appointments = [];
  List<StaffModel> _staffList = [];
  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  bool _isLoading = true;

  // Overview Stats & Status Filter
  Map<String, int> _overviewStats = {
    'total': 0,
    'booked': 0,
    'in_service': 0,
    'completed': 0,
    'no_show': 0,
    'cancelled': 0,
  };
  String? _selectedStatusFilter;

  // Calendar State
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _selectedStaffFilter; // null = all
  final String _searchQuery = '';
  bool _isCalendarHidden = false;

  // Drag and Drop Rescheduling State
  int? _draggingAppointmentId;

  // Customer Search
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final FocusNode _customerSearchFocus = FocusNode();
  final LayerLink _customerSearchLayerLink = LayerLink();
  String _customerSearchQuery = '';

  // Scroll Controllers
  final ScrollController _timelineScrollCtrl = ScrollController();
  final ScrollController _headerHorizontalScrollCtrl = ScrollController();
  final ScrollController _bodyHorizontalScrollCtrl = ScrollController();
  bool _isSyncingHScroll = false;
  Timer? _timeUpdateTimer;
  final ValueNotifier<DateTime> _currentTimeNotifier = ValueNotifier<DateTime>(DateTime.now());

  // Colors for staff badges
  static const List<Color> _staffColors = [
    Color(0xFF7C3AED), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF0EA5E9), // Sky
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEF4444), // Red
    Color(0xFF06B6D4), // Cyan
  ];

  // Appointment Configuration loaded from AuthStorage
  String _timeFormat = '12'; // '12' or '24'
  String _configOpenTime = '08:00';
  String _configCloseTime = '20:00';
  int _configuredSlotDuration = 30; // minutes
  bool _allowDeleteService = false;

  // Calendar Date Constants
  static const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const List<String> _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // Timetable config
  static const double _slotHeight = 56.0; // 30-min slot = 56px (h-14)
  int _gridStartHour = 8; // Business hours (e.g. 08:00 - 22:00)
  int _gridEndHour = 22;
  final Map<int, GlobalKey> _staffLaneKeys = {};
  GlobalKey _getLaneKey(int staffId) => _staffLaneKeys.putIfAbsent(staffId, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _calendarAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _calendarAnim = CurvedAnimation(
      parent: _calendarAnimCtrl,
      curve: Curves.easeInOutCubic,
    );
    if (!_isCalendarHidden) {
      _calendarAnimCtrl.value = 1.0;
    }
    _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _loadConfig();
    _loadData();

    // Synchronize horizontal scrolling between Staff headers and Staff grid lanes
    _bodyHorizontalScrollCtrl.addListener(() {
      if (!_isSyncingHScroll && _headerHorizontalScrollCtrl.hasClients) {
        _isSyncingHScroll = true;
        _headerHorizontalScrollCtrl.jumpTo(_bodyHorizontalScrollCtrl.offset);
        _isSyncingHScroll = false;
      }
    });
    _headerHorizontalScrollCtrl.addListener(() {
      if (!_isSyncingHScroll && _bodyHorizontalScrollCtrl.hasClients) {
        _isSyncingHScroll = true;
        _bodyHorizontalScrollCtrl.jumpTo(_headerHorizontalScrollCtrl.offset);
        _isSyncingHScroll = false;
      }
    });

    // Timer updates the current time indicator continuously with running seconds
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _currentTimeNotifier.value = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _calendarAnimCtrl.dispose();
    _timelineScrollCtrl.dispose();
    _headerHorizontalScrollCtrl.dispose();
    _bodyHorizontalScrollCtrl.dispose();
    _timeUpdateTimer?.cancel();
    _currentTimeNotifier.dispose();
    _customerSearchCtrl.dispose();
    _customerSearchFocus.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    setState(() {
      _isCalendarHidden = !_isCalendarHidden;
      if (_isCalendarHidden) {
        _calendarAnimCtrl.reverse();
      } else {
        _calendarAnimCtrl.forward();
      }
    });
  }

  Future<void> _loadConfig() async {
    final format = await AuthStorage.getTimeFormat();
    final open = await AuthStorage.getOpenTime();
    final close = await AuthStorage.getCloseTime();
    final slot = await AuthStorage.getSlotDuration();
    final allowDelete = await AuthStorage.getAllowDeleteService();
    if (!mounted) return;
    setState(() {
      _timeFormat = format;
      _configOpenTime = open;
      _configCloseTime = close;
      _configuredSlotDuration = slot;
      _allowDeleteService = allowDelete;
    });
  }

  int _timeToMinutes(String time24) {
    final parts = time24.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return h * 60 + m;
  }

  String _minutesToTime24(int totalMinutes) {
    final h = ((totalMinutes ~/ 60) % 24).clamp(0, 23);
    final m = (totalMinutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _addMinutesTo24h(String time24, int minutesToAdd) {
    final mins = _timeToMinutes(time24) + minutesToAdd;
    return _minutesToTime24(mins);
  }

  Map<String, String> _split24To12(String time24) {
    int h = 9;
    int m = 0;
    final parts = time24.split(':');
    if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 9;
    if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    final timeStr = '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return {'time': timeStr, 'period': period};
  }

  String _convert12To24(String time12, String period) {
    int h = 9;
    int m = 0;
    final parts = time12.split(':');
    if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 9;
    if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
    if (period.toUpperCase() == 'AM') {
      if (h == 12) h = 0;
    } else {
      if (h < 12) h += 12;
    }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatSlotLabel(String time24) {
    if (_timeFormat == '12') {
      final map = _split24To12(time24);
      return '${map['time']} ${map['period']}';
    }
    return time24;
  }

  String _formatApptTimeRange(AppointmentModel appt) {
    if (_timeFormat == '12') {
      final s = _split24To12(appt.startTime);
      final e = _split24To12(appt.endTime);
      return '${s['time']} ${s['period']} - ${e['time']} ${e['period']}';
    }
    return appt.timeRange;
  }

  bool _isSlotOutsideBusinessHours(String time24) {
    final slotM = _timeToMinutes(time24);
    final openM = _timeToMinutes(_configOpenTime);
    final closeM = _timeToMinutes(_configCloseTime);
    return slotM < openM || slotM >= closeM;
  }

  String get _formattedDate {
    return '${_weekdays[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String get _calendarMonthTitle {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[_calendarMonth.month - 1]} ${_calendarMonth.year}';
  }

  List<DateTime> get _calendarDays {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final startOffset = firstDay.weekday % 7;
    final startDate = firstDay.subtract(Duration(days: startOffset));
    final days = <DateTime>[];
    for (int i = 0; i < 42; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    if (days[35].month != _calendarMonth.month) {
      return days.sublist(0, 35);
    }
    return days;
  }

  void _prevMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadConfig();
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final results = await Future.wait([
      ApiService.getAppointments(date: dateStr),
      ApiService.getStaff(),
      ApiService.getCategories(),
      ApiService.getProducts(),
      ApiService.getAppointmentStats(date: dateStr),
    ]);
    if (!mounted) return;
    setState(() {
      _appointments = results[0] as List<AppointmentModel>;
      _staffList = results[1] as List<StaffModel>;
      _categories = results[2] as List<CategoryModel>;
      _products = results[3] as List<ProductModel>;
      _overviewStats = results[4] as Map<String, int>;
      _computeGridBounds();
      _isLoading = false;
    });
  }

  void _computeGridBounds() {
    int openH = 8;
    int closeH = 20;
    final openParts = _configOpenTime.split(':');
    if (openParts.isNotEmpty) openH = int.tryParse(openParts[0]) ?? 8;
    final closeParts = _configCloseTime.split(':');
    if (closeParts.isNotEmpty) {
      final ch = int.tryParse(closeParts[0]) ?? 20;
      final cm = (closeParts.length > 1 ? int.tryParse(closeParts[1]) : 0) ?? 0;
      closeH = cm > 0 ? ch + 1 : ch;
    }

    int minHour = openH;
    int maxHour = closeH;
    for (final a in _appointments) {
      final startH = a.startMinutes ~/ 60;
      final endH = (a.endMinutes / 60).ceil();
      if (startH < minHour) minHour = startH;
      if (endH > maxHour) maxHour = endH;
    }
    _gridStartHour = minHour.clamp(0, 23);
    _gridEndHour = maxHour.clamp(_gridStartHour + 1, 24);
  }

  List<String> get _timeSlots {
    final slots = <String>[];
    for (int h = _gridStartHour; h < _gridEndHour; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  int get _gridBaseMinutes => _gridStartHour * 60;
  double get _gridTotalHeight => _timeSlots.length * _slotHeight;

  List<AppointmentModel> _appointmentsForStaff(int staffId) {
    var list = _appointments.where((a) => a.staffId == staffId);
    if (_selectedStatusFilter != null) {
      list = list.where((a) {
        final s = a.status.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
        final target = _selectedStatusFilter!.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
        return s == target;
      });
    }
    return list.toList();
  }

  int _countForStaff(int staffId) {
    return _appointments.where((a) => a.staffId == staffId).length;
  }

  List<StaffModel> get _displayedStaff {
    if (_selectedStaffFilter != null) {
      return _staffList.where((s) => s.id == _selectedStaffFilter).toList();
    }
    return _staffList.isNotEmpty ? _staffList : [];
  }

  Color _staffColor(int index) => _staffColors[index % _staffColors.length];

  void _goToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
    _loadData();
  }

  void _goPrevDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
    _loadData();
  }

  void _goNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _calendarMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadData();
    }
  }

  // =====================================================================
  // BUILD
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopHeader(),
              _buildStaffPillsBar(),
              // Main Body: Left (Staff & Time Slots) + Right (Calendar & Booking Overview)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final availableHeight = constraints.maxHeight;

                    return AnimatedBuilder(
                      animation: _calendarAnim,
                      builder: (context, child) {
                        final double openProgress = _calendarAnim.value;
                        final double targetCalendarWidth = totalWidth * 0.30;
                        final double currentCalendarWidth = targetCalendarWidth * openProgress;
                        final double currentTimelineWidth = totalWidth - currentCalendarWidth;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Staff and Time Slot section (smoothly transitions between 100% and 70%)
                            SizedBox(
                              width: currentTimelineWidth,
                              height: availableHeight,
                              child: _buildTimetableArea(currentTimelineWidth),
                            ),

                            // Right: Calendar and Booking Overview section (smoothly slides in/out from right)
                            if (openProgress > 0.0)
                              ClipRect(
                                child: SizedBox(
                                  width: currentCalendarWidth,
                                  height: availableHeight,
                                  child: OverflowBox(
                                    minWidth: targetCalendarWidth,
                                    maxWidth: targetCalendarWidth,
                                    minHeight: availableHeight,
                                    maxHeight: availableHeight,
                                    alignment: Alignment.topRight,
                                    child: Transform.translate(
                                      offset: Offset(targetCalendarWidth * (1.0 - openProgress), 0),
                                      child: _buildRightCalendarAndBookingSection(targetCalendarWidth),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Customer Search Results Overlay
          if (_customerSearchQuery.isNotEmpty)
            _buildCustomerSearchResults(),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchResults() {
    final q = _customerSearchQuery.toLowerCase();
    final matchedAppts = _appointments.where((a) {
      return a.customerName.toLowerCase().contains(q) ||
          a.customerPhone.toLowerCase().contains(q);
    }).toList();

    if (matchedAppts.isEmpty) {
      return Positioned(
        child: CompositedTransformFollower(
          link: _customerSearchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_off, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text('No matching appointments found', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      child: CompositedTransformFollower(
        link: _customerSearchLayerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 40),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      Text('${matchedAppts.length} result${matchedAppts.length == 1 ? '' : 's'}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: matchedAppts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 14, endIndent: 14),
                  itemBuilder: (ctx, idx) {
                    final appt = matchedAppts[idx];
                    final serviceName = appt.services.isNotEmpty
                        ? appt.services.first['name']?.toString() ?? 'Service'
                        : 'General';
                    return InkWell(
                      onTap: () {
                        _customerSearchCtrl.clear();
                        setState(() => _customerSearchQuery = '');
                        _customerSearchFocus.unfocus();
                        _showAppointmentDetails(appt);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFE11D48).withValues(alpha: 0.1),
                              child: Text(
                                appt.customerName.isNotEmpty ? appt.customerName[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appt.customerName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Text(appt.customerPhone, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFFE4E6)),
                              ),
                              child: Text(serviceName, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48))),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // =====================================================================
  // TOP HEADER
  // =====================================================================
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Row(
        children: [
          // Left Side: Date nav + Refresh button
          Row(
            children: [
              // Date controls
              _buildDateBtn('Today', _goToday),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildNavArrow(Icons.chevron_left, _goPrevDay),
                    _buildNavArrow(Icons.chevron_right, _goNextDay),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      Text(_formattedDate, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(height: 24, width: 1, color: Colors.grey.shade200),
              const SizedBox(width: 16),
              // Refresh Button positioned on the LEFT side header section only!
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 15, color: Color(0xFFE11D48)),
                label: Text('Refresh', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Customer Search Bar
          CompositedTransformTarget(
            link: _customerSearchLayerLink,
            child: SizedBox(
              width: 260,
              height: 36,
              child: Focus(
                onFocusChange: (hasFocus) => setState(() {}),
                child: TextField(
                  controller: _customerSearchCtrl,
                  focusNode: _customerSearchFocus,
                  onChanged: (val) => setState(() => _customerSearchQuery = val.trim()),
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search customer name or phone...',
                    hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFFE11D48)),
                    suffixIcon: _customerSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              _customerSearchCtrl.clear();
                              setState(() => _customerSearchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Right Side: New Appointment button only!
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 1,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text('New Appointment', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
            onPressed: () => _showNewAppointmentDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
      ),
    );
  }

  Widget _buildNavArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: Colors.grey.shade600),
      ),
    );
  }

  // =====================================================================
  // STAFF PILLS BAR
  // =====================================================================
  Widget _buildStaffPillsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text('Filter Staff:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          // All Staff pill
          _buildStaffPill(
            label: 'All Staff',
            count: _appointments.length,
            isActive: _selectedStaffFilter == null,
            color: const Color(0xFF1E293B),
            onTap: () => setState(() => _selectedStaffFilter = null),
          ),
          const SizedBox(width: 8),
          // Individual staff pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _staffList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final staff = entry.value;
                  final color = _staffColor(idx);
                  final count = _countForStaff(staff.id);
                  final isActive = _selectedStaffFilter == staff.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildStaffPill(
                      label: staff.name,
                      count: count,
                      isActive: isActive,
                      color: color,
                      onTap: () => setState(() => _selectedStaffFilter = isActive ? null : staff.id),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Hide Calendar toggle button
          InkWell(
            onTap: _toggleCalendar,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _isCalendarHidden ? const Color(0xFFE11D48).withValues(alpha: 0.1) : Colors.transparent,
                border: Border.all(color: _isCalendarHidden ? const Color(0xFFE11D48) : Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCalendarHidden ? Icons.calendar_month : Icons.visibility_off_outlined,
                    size: 14,
                    color: _isCalendarHidden ? const Color(0xFFE11D48) : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isCalendarHidden ? 'Show Calendar' : 'Hide Calendar',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: _isCalendarHidden ? FontWeight.w600 : FontWeight.normal,
                      color: _isCalendarHidden ? const Color(0xFFE11D48) : Colors.grey.shade500,
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

  Widget _buildStaffPill({
    required String label,
    required int count,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    if (isActive && label == 'All Staff') {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: GoogleFonts.inter(fontSize: 10, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: color.withValues(alpha: 0.3), width: 2))),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.9))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // TIMETABLE AREA (75% of available width)
  // =====================================================================
  Widget _buildTimetableArea(double leftWidth) {
    final staff = _displayedStaff;
    if (staff.isEmpty) {
      return const Center(child: Text('No staff found'));
    }

    const double timeColWidth = 84.0;
    final double staffAreaWidth = math.max(200.0, leftWidth - timeColWidth);
    // User requirement: each Staff column uses approximately 30% width
    final double staffColWidth = math.max(180.0, staffAreaWidth * 0.30);
    final double totalStaffWidth = math.max(staffAreaWidth, staff.length * staffColWidth);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. Staff Lane Headers (Pinned at top of timetable)
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC).withValues(alpha: 0.95),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Corner "TIME" spacer (Pinned left)
                Container(
                  width: timeColWidth,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          'TIME',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF334155),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Horizontally scrollable Staff headers (synchronized with body)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalStaffWidth,
                      height: 60,
                      child: Row(
                        children: staff.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final s = entry.value;
                          return SizedBox(
                            width: staffColWidth,
                            height: 60,
                            child: _buildSingleStaffHeader(s, idx),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Scrollable Timetable Body (Vertical scroll)
          Expanded(
            child: SingleChildScrollView(
              controller: _timelineScrollCtrl,
              child: SizedBox(
                height: _gridTotalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pinned Time column on left (Never overlaps staff)
                    SizedBox(
                      width: timeColWidth,
                      height: _gridTotalHeight,
                      child: _buildTimeColumn(timeColWidth),
                    ),

                    // Horizontally scrollable Staff lanes (Never overlap each other or time slot)
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _bodyHorizontalScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: totalStaffWidth,
                          height: _gridTotalHeight,
                          child: Stack(
                            children: [
                              // Grid lanes for each staff with fixed 20% width
                              Row(
                                children: staff.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final s = entry.value;
                                  return SizedBox(
                                    width: staffColWidth,
                                    height: _gridTotalHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: idx > 0 ? BorderSide(color: Colors.grey.shade200) : BorderSide.none,
                                        ),
                                      ),
                                      child: _buildStaffLane(s, idx, staffColWidth),
                                    ),
                                  );
                                }).toList(),
                              ),

                              // Current time red line indicator across full width
                              ListenableBuilder(
                                listenable: Listenable.merge([_bodyHorizontalScrollCtrl, _currentTimeNotifier]),
                                builder: (context, _) => _buildCurrentTimeIndicator(staffAreaWidth, totalStaffWidth),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStaffHeader(StaffModel s, int idx) {
    final color = _staffColor(idx);
    return InkWell(
      onTap: () => _showStaffInfoPopup(s, idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: idx > 0 ? BorderSide(color: Colors.grey.shade200) : BorderSide.none),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                StaffAvatar(
                  staff: s,
                  radius: 16,
                  backgroundColor: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      s.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_countForStaff(s.id)} slots',
                    style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffInfoPopup(StaffModel s, int idx) {
    final color = _staffColor(idx);
    final staffAppts = _appointments.where((a) => a.staffId == s.id).toList();
    final bookedCount = staffAppts.where((a) => a.status == 'booked').length;
    final inServiceCount = staffAppts.where((a) => a.status == 'in_service').length;
    final completedCount = staffAppts.where((a) => a.status == 'completed').length;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StaffAvatar(
                    staff: s,
                    radius: 32,
                    backgroundColor: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 12),
                  Text(s.name, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.role.isNotEmpty ? s.role : 'Staff', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (s.email.isNotEmpty)
                    _staffInfoRow(Icons.email_outlined, 'Email', s.email),
                  if (s.phone.isNotEmpty)
                    _staffInfoRow(Icons.phone_outlined, 'Phone', s.phone),
                  _staffInfoRow(Icons.event_available, 'Booked Today', '$bookedCount'),
                  _staffInfoRow(Icons.play_circle_outline, 'In Service', '$inServiceCount'),
                  _staffInfoRow(Icons.check_circle_outline, 'Completed', '$completedCount'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedStaffFilter = s.id);
                          },
                          child: Text('View Schedule', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
      ),
      child: Column(
        children: _timeSlots.map((slot) {
          final isOutside = _isSlotOutsideBusinessHours(slot);
          return Container(
            height: _slotHeight,
            decoration: BoxDecoration(
              color: isOutside ? const Color(0xFFF1F5F9).withValues(alpha: 0.6) : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid,
                  strokeAlign: BorderSide.strokeAlignCenter,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatSlotLabel(slot),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: _timeFormat == '12' ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: isOutside ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =====================================================================
  // RIGHT CALENDAR & BOOKING OVERVIEW SECTION (25% of available width)
  // =====================================================================
  Widget _buildRightCalendarAndBookingSection(double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Month Calendar Header & Days Grid
            _buildMonthCalendarWidget(),

            // Subtle divider between Calendar and Overview
            Container(
              height: 1,
              color: const Color(0xFFF1F5F9),
              margin: const EdgeInsets.symmetric(vertical: 16),
            ),

            // 2. OVERVIEW Header & Count Badge
            _buildOverviewHeader(),

            const SizedBox(height: 12),

            // 3. The 5 Status Cards (Booked, In service, Completed, No-show, Cancelled)
            _buildStatusCard(
              label: 'Booked',
              count: _overviewStats['booked'] ?? 0,
              dotColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
              statusKey: 'booked',
            ),
            const SizedBox(height: 8),
            _buildStatusCard(
              label: 'In service',
              count: _overviewStats['in_service'] ?? 0,
              dotColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFEF3C7),
              statusKey: 'in_service',
            ),
            const SizedBox(height: 8),
            _buildStatusCard(
              label: 'Completed',
              count: _overviewStats['completed'] ?? 0,
              dotColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFDCFCE7),
              statusKey: 'completed',
            ),
            const SizedBox(height: 8),
            _buildStatusCard(
              label: 'No-show',
              count: _overviewStats['no_show'] ?? 0,
              dotColor: const Color(0xFFF43F5E),
              bgColor: const Color(0xFFFFF1F2),
              borderColor: const Color(0xFFFFE4E6),
              statusKey: 'no_show',
            ),
            const SizedBox(height: 8),
            _buildStatusCard(
              label: 'Cancelled',
              count: _overviewStats['cancelled'] ?? 0,
              dotColor: const Color(0xFF64748B),
              bgColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
              statusKey: 'cancelled',
            ),
          ],
        ),
      ),
    );
  }

  // Month Calendar Widget (Top of Right Section)
  Widget _buildMonthCalendarWidget() {
    final days = _calendarDays;
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Title + Navigation Arrows (< >)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _calendarMonthTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                InkWell(
                  onTap: _prevMonth,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, size: 20, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _nextMonth,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right, size: 20, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _toggleCalendar,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Weekday column headers (S M T W T F S)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((w) {
            return SizedBox(
              width: 30,
              child: Center(
                child: Text(
                  w,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Calendar Days Grid (7 columns)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, idx) {
            final day = days[idx];
            final isCurrentMonth = day.month == _calendarMonth.month;
            final isSelected = day.year == _selectedDate.year &&
                day.month == _selectedDate.month &&
                day.day == _selectedDate.day;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _calendarMonth = DateTime(day.year, day.month, 1);
                });
                _loadData();
              },
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : (isCurrentMonth ? FontWeight.w500 : FontWeight.w400),
                        color: isSelected
                            ? Colors.white
                            : (isCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // OVERVIEW Header with Total Count Badge
  Widget _buildOverviewHeader() {
    final total = _overviewStats['total'] ?? _appointments.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'OVERVIEW',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '$total total',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  // Individual Status Card matching the design image
  Widget _buildStatusCard({
    required String label,
    required int count,
    required Color dotColor,
    required Color bgColor,
    required Color borderColor,
    required String statusKey,
  }) {
    final bool isFiltered = _selectedStatusFilter == statusKey;

    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedStatusFilter == statusKey) {
            _selectedStatusFilter = null; // Toggle off filter
          } else {
            _selectedStatusFilter = statusKey; // Apply filter
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered ? dotColor : borderColor,
            width: isFiltered ? 1.8 : 1.0,
          ),
          boxShadow: isFiltered
              ? [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFiltered ? dotColor.withValues(alpha: 0.5) : borderColor,
                ),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDragDropReschedule(
    AppointmentModel appt,
    StaffModel targetStaff,
    String targetSlot,
  ) async {
    // 0. Only allow rescheduling for 'booked' and 'in_service' appointments
    if (appt.status != 'booked' && appt.status != 'in_service') {
      return;
    }

    // 1. Calculate duration and new end time
    final durationM = appt.durationMinutes > 0 ? appt.durationMinutes : _configuredSlotDuration;
    final newEndTime = _addMinutesTo24h(targetSlot, durationM);

    // 2. Check if anything actually changed
    final isSameStaff = appt.staffId == targetStaff.id;
    final isSameTime = appt.startTime == targetSlot;
    if (isSameStaff && isSameTime) {
      return; // Dropped on the exact same slot; nothing to do
    }

    // 3. Business hours check
    final isOutside = _isSlotOutsideBusinessHours(targetSlot);
    final targetStartM = _timeToMinutes(targetSlot);
    final targetEndM = _timeToMinutes(newEndTime);
    final closeM = _timeToMinutes(_configCloseTime);
    final openM = _timeToMinutes(_configOpenTime);

    if (isOutside || targetStartM < openM) {
      final openLabel = _formatSlotLabel(_configOpenTime);
      final closeLabel = _formatSlotLabel(_configCloseTime);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE11D48),
          content: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot reschedule: Time slot ${_formatSlotLabel(targetSlot)} is outside business hours ($openLabel - $closeLabel).',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (targetEndM > closeM) {
      final closeLabel = _formatSlotLabel(_configCloseTime);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE11D48),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot reschedule: Appointment duration ends at ${_formatSlotLabel(newEndTime)}, which exceeds closing time ($closeLabel).',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // 3b. In-memory local conflict pre-check (prevents optimistic-update jitter)
    final hasLocalConflict = _appointments.any((a) {
      if (a.id == appt.id || a.staffId != targetStaff.id) return false;
      // Cancelled and no_show appointments don't block slots
      if (a.status == 'cancelled' || a.status == 'no_show') return false;
      // Overlap: [targetStart, targetEnd) ∩ [aStart, aEnd) != ∅
      return targetStartM < a.endMinutes && a.startMinutes < targetEndM;
    });

    if (hasLocalConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE11D48),
          content: Row(
            children: [
              const Icon(Icons.event_busy_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Booking Conflict: ${targetStaff.name} already has an appointment at ${_formatSlotLabel(targetSlot)}.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // 4. Save original appointment state for rollback if needed
    final originalAppt = appt;
    // Normalize date string — strip any ISO timestamp suffix (e.g. '2026-10-04T00:00:00.000Z' → '2026-10-04')
    final selectedDateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final dateStr = appt.appointmentDate.isNotEmpty
        ? appt.appointmentDate.split('T')[0]
        : selectedDateStr;

    // 5. Construct updated appointment preserving all customer, services, notes, totalAmount
    final updatedAppt = appt.copyWith(
      staffId: targetStaff.id,
      staffName: targetStaff.name,
      appointmentDate: dateStr,
      startTime: targetSlot,
      endTime: newEndTime,
    );

    // 6. Immediate optimistic UI update (zero delay reflection!)
    setState(() {
      final idx = _appointments.indexWhere((a) => a.id == appt.id);
      if (idx != -1) {
        _appointments[idx] = updatedAppt;
      }
      _computeGridBounds();
    });

    // 7. Update in backend database (preserves customer & services)
    final updatePayload = <String, dynamic>{
      'staff_id': targetStaff.id,
      'staff_name': targetStaff.name,
      'appointment_date': dateStr,
      'start_time': targetSlot,
      'end_time': newEndTime,
    };

    final success = await ApiService.updateAppointment(appt.id, updatePayload);

    if (!mounted) return;

    if (success) {
      final startLabel = _formatSlotLabel(targetSlot);
      final endLabel = _formatSlotLabel(newEndTime);
      final changeDesc = isSameStaff
          ? 'time to $startLabel - $endLabel'
          : 'to ${targetStaff.name} at $startLabel - $endLabel';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rescheduled "${appt.customerName}" $changeDesc',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Silently refresh in background without full loading spinner
      final refreshed = await ApiService.getAppointments(date: dateStr);
      final stats = await ApiService.getAppointmentStats(date: dateStr);
      if (mounted) {
        setState(() {
          _appointments = refreshed;
          _overviewStats = stats;
          _computeGridBounds();
        });
      }
    } else {
      // Rollback optimistic update
      setState(() {
        final idx = _appointments.indexWhere((a) => a.id == appt.id);
        if (idx != -1) {
          _appointments[idx] = originalAppt;
        }
        _computeGridBounds();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE11D48),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to reschedule appointment on server. Reverted back to previous slot.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  bool _isSlotBlockedForDrag(AppointmentModel draggedAppt, StaffModel targetStaff, String slot) {
    final slotStartM = _timeToMinutes(slot);
    final dragDuration = draggedAppt.durationMinutes > 0 ? draggedAppt.durationMinutes : _configuredSlotDuration;
    final slotEndM = slotStartM + dragDuration;

    // Block if slot is outside business hours or if appointment ends after closing time
    if (_isSlotOutsideBusinessHours(slot)) return true;
    if (slotEndM > _timeToMinutes(_configCloseTime)) return true;

    // Block if overlaps with another active appointment for this staff (excluding itself)
    return _appointments.any((a) {
      if (a.id == draggedAppt.id || a.staffId != targetStaff.id) return false;
      if (a.status == 'cancelled' || a.status == 'no_show') return false;
      return slotStartM < a.endMinutes && a.startMinutes < slotEndM;
    });
  }

  Widget _buildStaffLane(StaffModel staff, int staffIndex, [double staffColWidth = 200.0]) {
    final appts = _appointmentsForStaff(staff.id);
    final filteredAppts = _searchQuery.isEmpty
        ? appts
        : appts.where((a) {
            final q = _searchQuery.toLowerCase();
            return a.customerName.toLowerCase().contains(q) ||
                a.services.any((s) => (s['name'] ?? '').toString().toLowerCase().contains(q));
          }).toList();

    // Sort: cancelled & no_show first so they form the background.
    // Active appointments (booked, in_service, completed) are drawn on top in foreground.
    final sortedAppts = List<AppointmentModel>.from(filteredAppts);
    sortedAppts.sort((a, b) {
      final aInactive = (a.status == 'cancelled' || a.status == 'no_show') ? 0 : 1;
      final bInactive = (b.status == 'cancelled' || b.status == 'no_show') ? 0 : 1;
      if (aInactive != bInactive) {
        return aInactive.compareTo(bInactive);
      }
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return Container(
      key: _getLaneKey(staff.id),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SizedBox(
        height: _gridTotalHeight,
        child: Stack(
          children: [
            // Clickable & Drag-droppable time slots with business hours validation
            Column(
              children: _timeSlots.map((slot) {
                final isOutside = _isSlotOutsideBusinessHours(slot);
                final endSlot = _addMinutesTo24h(slot, _configuredSlotDuration);
                final slotLabel = _formatSlotLabel(slot);

                return DragTarget<AppointmentModel>(
                  onWillAcceptWithDetails: (details) {
                    final d = details.data;
                    // Only accept 'booked' or 'in_service' appointments for drag-and-drop rescheduling
                    if (d.id == 0 || (d.status != 'booked' && d.status != 'in_service')) {
                      return false;
                    }
                    // Reject drop if slot is occupied or outside business hours (not allowed!)
                    if (_isSlotBlockedForDrag(d, staff, slot)) {
                      return false;
                    }
                    return true;
                  },
                  onAcceptWithDetails: (details) {
                    _handleDragDropReschedule(details.data, staff, slot);
                  },
                  builder: (context, candidateData, rejectedData) {
                    // Extract dragged appointment from candidateData or rejectedData
                    final draggedAppt = candidateData.isNotEmpty
                        ? candidateData.first
                        : (rejectedData.isNotEmpty && rejectedData.first is AppointmentModel
                            ? rejectedData.first as AppointmentModel
                            : null);
                    final isHovered = draggedAppt != null;

                    // Check if this slot is occupied or invalid for this staff
                    final isSlotOccupied = isHovered && _isSlotBlockedForDrag(draggedAppt, staff, slot);

                    // Blue for available, red for occupied / not allowed
                    final highlightColor = isSlotOccupied
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF3B82F6);

                    return Material(
                      color: isHovered
                          ? highlightColor.withValues(alpha: isSlotOccupied ? 0.20 : 0.15)
                          : (isOutside ? const Color(0xFFF8FAFC).withValues(alpha: 0.5) : Colors.transparent),
                      child: InkWell(
                        onTap: () {
                          if (isOutside) {
                            final openLabel = _formatSlotLabel(_configOpenTime);
                            final closeLabel = _formatSlotLabel(_configCloseTime);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFFE11D48),
                                content: Row(
                                  children: [
                                    const Icon(Icons.schedule, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Time slot $slotLabel is outside business hours ($openLabel - $closeLabel). Only business hour slots are selectable.',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          // Directly opens Add Appointment Popup with Staff, Date, and Time Slot pre-selected!
                          _showNewAppointmentDialog(
                            initialStaff: staff,
                            initialStartTime: slot,
                            initialEndTime: endSlot,
                            initialDate: _selectedDate,
                          );
                        },
                        hoverColor: isOutside
                            ? Colors.black.withValues(alpha: 0.02)
                            : const Color(0xFFE11D48).withValues(alpha: 0.08),
                        splashColor: const Color(0xFFE11D48).withValues(alpha: 0.15),
                        child: Container(
                          height: _slotHeight,
                          decoration: BoxDecoration(
                            border: isHovered
                                ? Border.all(
                                    color: highlightColor,
                                    width: 2.0,
                                    strokeAlign: BorderSide.strokeAlignInside,
                                  )
                                : Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200.withValues(alpha: 0.7),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                          ),
                          child: isHovered
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: highlightColor,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: highlightColor.withValues(alpha: 0.35),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSlotOccupied ? Icons.block : Icons.file_download_outlined,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSlotOccupied ? 'Not Allowed' : 'Drop at $slotLabel',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: isOutside
                                        ? const Icon(Icons.lock_clock_outlined, size: 12, color: Color(0xFFCBD5E1))
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            // Appointment cards (rendered with inactive cards first, active on top)
            ...sortedAppts.map((appt) => _buildAppointmentCard(appt, staffColWidth)),
          ],
        ),
      ),
    );
  }


  Widget _buildAppointmentCard(AppointmentModel appt, [double cardWidth = 200.0]) {
    final top = ((appt.startMinutes - _gridBaseMinutes) / 30.0) * _slotHeight;
    final height = ((appt.endMinutes - appt.startMinutes) / 30.0) * _slotHeight;

    // Status colors
    Color bgColor, borderColor, textColor, badgeBg, badgeText;
    bool strikethrough = false;

    switch (appt.status) {
      case 'booked':
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFF3B82F6);
        textColor = const Color(0xFF1E3A5F);
        badgeBg = const Color(0xFF3B82F6);
        badgeText = Colors.white;
        break;
      case 'in_service':
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFF78350F);
        badgeBg = const Color(0xFFF59E0B);
        badgeText = Colors.white;
        break;
      case 'completed':
        bgColor = const Color(0xFFF0FDF4).withValues(alpha: 0.9);
        borderColor = const Color(0xFF10B981);
        textColor = const Color(0xFF064E3B);
        badgeBg = const Color(0xFF10B981);
        badgeText = Colors.white;
        break;
      case 'no_show':
        bgColor = const Color(0xFFFFF1F2).withValues(alpha: 0.9);
        borderColor = const Color(0xFFF43F5E);
        textColor = const Color(0xFF881337);
        badgeBg = const Color(0xFFF43F5E);
        badgeText = Colors.white;
        break;
      case 'cancelled':
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFF94A3B8);
        textColor = const Color(0xFF475569);
        badgeBg = const Color(0xFFE2E8F0);
        badgeText = const Color(0xFF475569);
        strikethrough = true;
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFF94A3B8);
        textColor = const Color(0xFF475569);
        badgeBg = const Color(0xFFE2E8F0);
        badgeText = const Color(0xFF475569);
    }

    final serviceName = appt.services.isNotEmpty
        ? appt.services.first['name']?.toString() ?? appt.customerName
        : appt.customerName;

    // Check if this active card overlays a cancelled/no_show card
    final hasUnderlyingInactive = (appt.status == 'booked' || appt.status == 'in_service') &&
        _appointments.any((a) =>
            a.id != appt.id &&
            a.staffId == appt.staffId &&
            (a.status == 'cancelled' || a.status == 'no_show') &&
            appt.startMinutes < a.endMinutes &&
            a.startMinutes < appt.endMinutes);

    // Build the visual card content
    Widget cardBody = Container(
      padding: EdgeInsets.all(height > 60 ? 10 : 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.schedule, size: 11, color: textColor.withValues(alpha: 0.7)),
                    ),
                    Flexible(
                      child: Text(
                        _formatApptTimeRange(appt),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUnderlyingInactive)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('OVERLAY', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: textColor)),
                    ),
                  GestureDetector(
                    onTap: () {
                      if (appt.status == 'in_service') {
                        _continueServiceInCart(appt);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (appt.status == 'in_service') ...[
                            const Icon(Icons.play_circle_fill, size: 9, color: Colors.white),
                            const SizedBox(width: 3),
                          ],
                          Text(appt.statusLabel, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: badgeText, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (height > 50) ...[
            const SizedBox(height: 2),
            Text(
              serviceName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: strikethrough ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                decoration: strikethrough ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (height > 80 && appt.notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              appt.status == 'no_show' ? '⚠️ ${appt.notes}' : appt.notes,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (height > 90 && appt.totalAmount > 0 && appt.status == 'completed') ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(appt.notes.isNotEmpty ? appt.notes : 'Paid', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: textColor)),
                Text('\$${appt.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          ],
        ],
      ),
    );

    // Only 'booked' and 'in_service' appointments can be rescheduled via drag & drop
    final canDrag = appt.status == 'booked' || appt.status == 'in_service';
    final isDraggingAny = _draggingAppointmentId != null;

    Widget cardWidget;
    if (canDrag) {
      cardWidget = LongPressDraggable<AppointmentModel>(
        data: appt,
        delay: const Duration(milliseconds: 200),
        hapticFeedbackOnStart: true,
        onDragStarted: () {
          setState(() {
            _draggingAppointmentId = appt.id;
          });
        },
        onDragEnd: (_) {
          if (_draggingAppointmentId != null) {
            setState(() {
              _draggingAppointmentId = null;
            });
          }
        },
        onDraggableCanceled: (velocity, offset) {
          if (_draggingAppointmentId != null) {
            setState(() {
              _draggingAppointmentId = null;
            });
          }
        },
        onDragCompleted: () {
          if (_draggingAppointmentId != null) {
            setState(() {
              _draggingAppointmentId = null;
            });
          }
        },
        feedback: Material(
          color: Colors.transparent,
          elevation: 12,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: (cardWidth - 12).clamp(140.0, 340.0),
            height: (height - 6).clamp(36.0, 160.0),
            child: Opacity(
              opacity: 0.95,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: cardBody,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: cardBody,
        ),
        child: GestureDetector(
          onTap: () => _showAppointmentDetails(appt),
          child: cardBody,
        ),
      );
    } else {
      cardWidget = GestureDetector(
        onTap: () => _showAppointmentDetails(appt),
        child: cardBody,
      );
    }

    return Positioned(
      left: 6,
      right: 6,
      top: top + 2,
      height: (height - 6).clamp(30.0, double.infinity),
      child: IgnorePointer(
        // When ANY drag is active, ALL cards (including the dragged card's placeholder)
        // MUST ignore pointer events so DragTargets beneath receive 100% of hit tests.
        ignoring: isDraggingAny,
        child: cardWidget,
      ),
    );

  }

  Widget _buildCurrentTimeIndicator(double visibleStaffWidth, double totalWidth) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute + (now.second / 60.0);
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    if (!isToday || nowMinutes < _gridBaseMinutes || nowMinutes > _gridEndHour * 60) {
      return const SizedBox.shrink();
    }

    final top = ((nowMinutes - _gridBaseMinutes) / 30.0) * _slotHeight;
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final String timeDigits;
    if (_timeFormat == '24') {
      timeDigits = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    } else {
      timeDigits = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    }

    final double scrollX = _bodyHorizontalScrollCtrl.hasClients ? _bodyHorizontalScrollCtrl.offset : 0.0;
    final double badgeWidth = _timeFormat == '12' ? 134.0 : 100.0;
    // Position the badge so it stays visible within the current visible screen view:
    // It hugs the right edge of the visible viewport (e.g. 4th column area),
    // but never goes past totalWidth, never goes behind the calendar, and never jumps to the last column.
    final double badgeX = (scrollX + visibleStaffWidth - badgeWidth - 14).clamp(scrollX + 6, totalWidth - badgeWidth - 8);

    return Positioned(
      left: 0,
      right: 0,
      top: top - 5,
      child: SizedBox(
        width: totalWidth,
        height: 22,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 1. Full continuous red line across entire grid
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFFDA4AF)],
                  ),
                ),
              ),
            ),
            // 2. Left anchor pulse dot
            Positioned(
              left: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
            ),
            // 3. Floating current-time badge with proper AM/PM alignment on the right side
            Positioned(
              left: badgeX,
              child: Container(
                width: badgeWidth,
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_filled, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        timeDigits,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (_timeFormat == '12') ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            ampm,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // DIALOGS
  // =====================================================================

  /// Phase 5: New Appointment Dialog with Staff Pre-selection & 12h/24h Formats
  void _showNewAppointmentDialog({
    StaffModel? initialStaff,
    String? initialStartTime,
    String? initialEndTime,
    DateTime? initialDate,
  }) {
    StaffModel? selStaff;
    if (initialStaff != null) {
      selStaff = _staffList.firstWhere((s) => s.id == initialStaff.id, orElse: () => initialStaff);
    } else if (_staffList.isNotEmpty) {
      selStaff = _staffList.first;
    }

    CustomerModel? selCustomer;
    final customerSearchCtrl = TextEditingController();
    List<CustomerModel> searchCustomers = [];
    bool isSearchingCustomers = false;
    bool showCustomerDropdown = false;
    Timer? customerSearchDebounce;

    bool isWalkIn = false;
    final walkInNameCtrl = TextEditingController();
    final walkInPhoneCtrl = TextEditingController();
    DateTime appointmentDate = initialDate ?? _selectedDate;

    final String rawStart = initialStartTime ?? '09:00';
    final String rawEnd = initialEndTime ?? _addMinutesTo24h(rawStart, _configuredSlotDuration);

    late final TextEditingController startCtrl;
    late final TextEditingController endCtrl;
    String startPeriod = 'AM';
    String endPeriod = 'AM';

    if (_timeFormat == '12') {
      final startMap = _split24To12(rawStart);
      startCtrl = TextEditingController(text: startMap['time']);
      startPeriod = startMap['period'] ?? 'AM';

      final endMap = _split24To12(rawEnd);
      endCtrl = TextEditingController(text: endMap['time']);
      endPeriod = endMap['period'] ?? 'AM';
    } else {
      startCtrl = TextEditingController(text: rawStart);
      endCtrl = TextEditingController(text: rawEnd);
    }

    final selectedProducts = <ProductModel>[];
    int? selectedCategoryId;
    String? validationOrConflictError;
    final categoryScrollCtrl = ScrollController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allowedCategories = _categories.where((c) => c.showInAppointment).toList();
          final allowedCategoryIds = allowedCategories.map((c) => c.id).toSet();

          final filteredProds = selectedCategoryId == null
              ? _products.where((p) => p.categoryId != null && allowedCategoryIds.contains(p.categoryId)).toList()
              : (allowedCategoryIds.contains(selectedCategoryId)
                  ? _products.where((p) => p.categoryId == selectedCategoryId).toList()
                  : <ProductModel>[]);
          final totalPrice = selectedProducts.fold<double>(0, (sum, p) => sum + p.price);

          void onCustomerSearchChanged(String val) {
            customerSearchDebounce?.cancel();
            final query = val.trim();
            if (query.isEmpty) {
              setDialogState(() {
                isSearchingCustomers = false;
                searchCustomers = [];
                showCustomerDropdown = false;
                selCustomer = null;
              });
              return;
            }

            setDialogState(() {
              isSearchingCustomers = true;
              showCustomerDropdown = true;
            });

            customerSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
              try {
                final results = await ApiService.getCustomers(search: query);
                setDialogState(() {
                  searchCustomers = results;
                  isSearchingCustomers = false;
                });
              } catch (_) {
                setDialogState(() {
                  searchCustomers = [];
                  isSearchingCustomers = false;
                });
              }
            });
          }

          void selectCustomer(CustomerModel c) {
            setDialogState(() {
              selCustomer = c;
              customerSearchCtrl.text = c.name;
              showCustomerDropdown = false;
              validationOrConflictError = null;
            });
          }

          void clearSelectedCustomer() {
            setDialogState(() {
              selCustomer = null;
              customerSearchCtrl.clear();
              searchCustomers = [];
              showCustomerDropdown = false;
            });
          }

          Future<void> pickTime({required bool isStart}) async {
            TimeOfDay initial;
            final curText = isStart ? startCtrl.text.trim() : endCtrl.text.trim();
            final p = curText.split(':');
            int h = int.tryParse(p.isNotEmpty ? p[0] : '9') ?? 9;
            final int m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;

            if (_timeFormat == '12') {
              final curPeriod = isStart ? startPeriod : endPeriod;
              if (curPeriod == 'PM' && h < 12) h += 12;
              if (curPeriod == 'AM' && h == 12) h = 0;
            }
            initial = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));

            final picked = await showTimePicker(
              context: context,
              initialTime: initial,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFFE11D48),
                      onPrimary: Colors.white,
                      onSurface: Color(0xFF0F172A),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setDialogState(() {
                validationOrConflictError = null;
                if (_timeFormat == '12') {
                  final int h12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
                  final String formatted = '${h12.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  final String period = picked.period == DayPeriod.am ? 'AM' : 'PM';
                  if (isStart) {
                    startCtrl.text = formatted;
                    startPeriod = period;
                  } else {
                    endCtrl.text = formatted;
                    endPeriod = period;
                  }
                } else {
                  final String formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  if (isStart) {
                    startCtrl.text = formatted;
                  } else {
                    endCtrl.text = formatted;
                  }
                }
              });
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 980,
              constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 650),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Book New Appointment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Two-column layout
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Staff, Customer, Date, Time (flex: 12 for ample field width)
                        Expanded(
                          flex: 12,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Staff Member', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<StaffModel>(
                                  initialValue: selStaff,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true, fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: _staffList.map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        StaffAvatar(staff: s, radius: 11, fontSize: 10),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('${s.name} (${s.role})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                  onChanged: (v) => setDialogState(() {
                                    selStaff = v;
                                    validationOrConflictError = null;
                                  }),
                                ),
                                const SizedBox(height: 16),

                                // Customer / Walk-in toggle
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Customer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Row(
                                      children: [
                                        Text('Walk-in', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
                                        Switch(
                                          value: isWalkIn,
                                          activeThumbColor: const Color(0xFFE11D48),
                                          onChanged: (v) {
                                            setDialogState(() {
                                              isWalkIn = v;
                                              showCustomerDropdown = false;
                                              validationOrConflictError = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isWalkIn) ...[
                                  TextField(
                                    controller: walkInNameCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Walk-in Name',
                                      filled: true, fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: walkInPhoneCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      filled: true, fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ] else ...[
                                  // API-based Customer Search Field
                                  TextField(
                                    controller: customerSearchCtrl,
                                    onChanged: onCustomerSearchChanged,
                                    onTap: () {
                                      if (customerSearchCtrl.text.trim().isNotEmpty && searchCustomers.isNotEmpty) {
                                        setDialogState(() => showCustomerDropdown = true);
                                      }
                                    },
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Search customer by name...',
                                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                                      suffixIcon: isSearchingCustomers
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE11D48)),
                                              ),
                                            )
                                          : (customerSearchCtrl.text.isNotEmpty || selCustomer != null
                                              ? IconButton(
                                                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                                  onPressed: clearSelectedCustomer,
                                                )
                                              : null),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                                      ),
                                    ),
                                  ),
                                  // Scrollable Dropdown for Customer Search Results (Max 5 items visible at a time)
                                  if (showCustomerDropdown && customerSearchCtrl.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 220),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: isSearchingCustomers && searchCustomers.isEmpty
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(vertical: 20),
                                                alignment: Alignment.center,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE11D48)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Searching customers...',
                                                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : searchCustomers.isEmpty
                                                ? Container(
                                                    padding: const EdgeInsets.all(14),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'No customers found matching "${customerSearchCtrl.text.trim()}"',
                                                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                                                    ),
                                                  )
                                                : Scrollbar(
                                                    thumbVisibility: searchCustomers.length > 5,
                                                    child: ListView.separated(
                                                      shrinkWrap: true,
                                                      padding: EdgeInsets.zero,
                                                      itemCount: searchCustomers.length,
                                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                      itemBuilder: (context, index) {
                                                        final cust = searchCustomers[index];
                                                        final isSel = selCustomer?.id == cust.id;
                                                        return InkWell(
                                                          onTap: () => selectCustomer(cust),
                                                          child: Container(
                                                            height: 44,
                                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                                            color: isSel ? const Color(0xFFFFF1F2) : Colors.transparent,
                                                            child: Row(
                                                              children: [
                                                                CircleAvatar(
                                                                  radius: 13,
                                                                  backgroundColor: isSel ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                                                                  child: Text(
                                                                    cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'C',
                                                                    style: GoogleFonts.inter(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: isSel ? Colors.white : const Color(0xFF334155),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 10),
                                                                Expanded(
                                                                  child: Column(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(
                                                                        cust.name,
                                                                        style: GoogleFonts.inter(
                                                                          fontSize: 12.5,
                                                                          fontWeight: FontWeight.w600,
                                                                          color: const Color(0xFF0F172A),
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                      if (cust.phone.isNotEmpty)
                                                                        Text(
                                                                          cust.phone,
                                                                          style: GoogleFonts.inter(
                                                                            fontSize: 11,
                                                                            color: const Color(0xFF64748B),
                                                                          ),
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                if (isSel)
                                                                  const Icon(Icons.check, size: 16, color: Color(0xFFE11D48)),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                      ),
                                    ),
                                  ],
                                  // Selected Customer confirmation badge
                                  if (selCustomer != null && !showCustomerDropdown) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Selected: ${selCustomer!.name}${selCustomer!.phone.isNotEmpty ? ' (${selCustomer!.phone})' : ''}',
                                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: clearSelectedCustomer,
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.close, size: 14, color: Color(0xFF15803D)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 16),

                                Text('Appointment Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: appointmentDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => appointmentDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_weekdays[appointmentDate.weekday - 1]}, ${appointmentDate.day} ${_monthNames[appointmentDate.month - 1]} ${appointmentDate.year}',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Start & End Time (Neat red clock icon on left side - select time clock instead of typing)
                                Row(
                                  children: [
                                    // START TIME
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('Start Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _timeFormat == '12' ? '(12h AM/PM)' : '(24h)',
                                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                // Neat Red Clock Icon on the left side of the time
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(6),
                                                    onTap: () => pickTime(isStart: true),
                                                    child: Container(
                                                      width: 34,
                                                      height: 34,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEE2E2),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.access_time_filled,
                                                          color: Color(0xFFE11D48),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Click to select time on clock instead of typing
                                                Expanded(
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(6),
                                                    onTap: () => pickTime(isStart: true),
                                                    child: Container(
                                                      height: 34,
                                                      alignment: Alignment.centerLeft,
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      child: Text(
                                                        startCtrl.text.isNotEmpty ? startCtrl.text : 'Select time',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                          color: startCtrl.text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                          letterSpacing: 0.5,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (_timeFormat == '12') ...[
                                                  const SizedBox(width: 8),
                                                  Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                                                  const SizedBox(width: 8),
                                                  Theme(
                                                    data: Theme.of(context).copyWith(
                                                      popupMenuTheme: PopupMenuThemeData(
                                                        color: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          side: BorderSide(color: Colors.grey.shade200),
                                                        ),
                                                        elevation: 8,
                                                      ),
                                                    ),
                                                    child: PopupMenuButton<String>(
                                                      tooltip: 'Select AM or PM',
                                                      offset: const Offset(0, 38),
                                                      padding: EdgeInsets.zero,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        side: BorderSide(color: Colors.grey.shade200),
                                                      ),
                                                      elevation: 8,
                                                      onSelected: (val) {
                                                        setDialogState(() {
                                                          startPeriod = val;
                                                          validationOrConflictError = null;
                                                        });
                                                      },
                                                      itemBuilder: (context) => [
                                                        PopupMenuItem<String>(
                                                          value: 'AM',
                                                          height: 38,
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 26,
                                                                height: 26,
                                                                decoration: BoxDecoration(
                                                                  color: startPeriod == 'AM'
                                                                      ? const Color(0xFFE11D48).withValues(alpha: 0.1)
                                                                      : const Color(0xFFF1F5F9),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons.wb_sunny_rounded,
                                                                    size: 14,
                                                                    color: startPeriod == 'AM'
                                                                        ? const Color(0xFFE11D48)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                'AM',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  fontWeight: startPeriod == 'AM' ? FontWeight.w700 : FontWeight.w500,
                                                                  color: startPeriod == 'AM' ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              if (startPeriod == 'AM')
                                                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFFE11D48)),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'PM',
                                                          height: 38,
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 26,
                                                                height: 26,
                                                                decoration: BoxDecoration(
                                                                  color: startPeriod == 'PM'
                                                                      ? const Color(0xFFE11D48).withValues(alpha: 0.1)
                                                                      : const Color(0xFFF1F5F9),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons.nightlight_round,
                                                                    size: 14,
                                                                    color: startPeriod == 'PM'
                                                                        ? const Color(0xFFE11D48)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                'PM',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  fontWeight: startPeriod == 'PM' ? FontWeight.w700 : FontWeight.w500,
                                                                  color: startPeriod == 'PM' ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              if (startPeriod == 'PM')
                                                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFFE11D48)),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      child: Container(
                                                        height: 34,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.04),
                                                              blurRadius: 2,
                                                              offset: const Offset(0, 1),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              startPeriod,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w700,
                                                                color: const Color(0xFF0F172A),
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // END TIME
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('End Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _timeFormat == '12' ? '(12h AM/PM)' : '(24h)',
                                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              children: [
                                                // Neat Red Clock Icon on the left side of the time
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(6),
                                                    onTap: () => pickTime(isStart: false),
                                                    child: Container(
                                                      width: 34,
                                                      height: 34,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEE2E2),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.access_time_filled,
                                                          color: Color(0xFFE11D48),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Click to select time on clock instead of typing
                                                Expanded(
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(6),
                                                    onTap: () => pickTime(isStart: false),
                                                    child: Container(
                                                      height: 34,
                                                      alignment: Alignment.centerLeft,
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      child: Text(
                                                        endCtrl.text.isNotEmpty ? endCtrl.text : 'Select time',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                          color: endCtrl.text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                          letterSpacing: 0.5,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (_timeFormat == '12') ...[
                                                  const SizedBox(width: 8),
                                                  Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                                                  const SizedBox(width: 8),
                                                  Theme(
                                                    data: Theme.of(context).copyWith(
                                                      popupMenuTheme: PopupMenuThemeData(
                                                        color: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          side: BorderSide(color: Colors.grey.shade200),
                                                        ),
                                                        elevation: 8,
                                                      ),
                                                    ),
                                                    child: PopupMenuButton<String>(
                                                      tooltip: 'Select AM or PM',
                                                      offset: const Offset(0, 38),
                                                      padding: EdgeInsets.zero,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        side: BorderSide(color: Colors.grey.shade200),
                                                      ),
                                                      elevation: 8,
                                                      onSelected: (val) {
                                                        setDialogState(() {
                                                          endPeriod = val;
                                                          validationOrConflictError = null;
                                                        });
                                                      },
                                                      itemBuilder: (context) => [
                                                        PopupMenuItem<String>(
                                                          value: 'AM',
                                                          height: 38,
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 26,
                                                                height: 26,
                                                                decoration: BoxDecoration(
                                                                  color: endPeriod == 'AM'
                                                                      ? const Color(0xFFE11D48).withValues(alpha: 0.1)
                                                                      : const Color(0xFFF1F5F9),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons.wb_sunny_rounded,
                                                                    size: 14,
                                                                    color: endPeriod == 'AM'
                                                                        ? const Color(0xFFE11D48)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                'AM',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  fontWeight: endPeriod == 'AM' ? FontWeight.w700 : FontWeight.w500,
                                                                  color: endPeriod == 'AM' ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              if (endPeriod == 'AM')
                                                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFFE11D48)),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'PM',
                                                          height: 38,
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 26,
                                                                height: 26,
                                                                decoration: BoxDecoration(
                                                                  color: endPeriod == 'PM'
                                                                      ? const Color(0xFFE11D48).withValues(alpha: 0.1)
                                                                      : const Color(0xFFF1F5F9),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons.nightlight_round,
                                                                    size: 14,
                                                                    color: endPeriod == 'PM'
                                                                        ? const Color(0xFFE11D48)
                                                                        : const Color(0xFF64748B),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                'PM',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  fontWeight: endPeriod == 'PM' ? FontWeight.w700 : FontWeight.w500,
                                                                  color: endPeriod == 'PM' ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              if (endPeriod == 'PM')
                                                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFFE11D48)),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      child: Container(
                                                        height: 34,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.04),
                                                              blurRadius: 2,
                                                              offset: const Offset(0, 1),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              endPeriod,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w700,
                                                                color: const Color(0xFF0F172A),
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Business hours: ${_formatSlotLabel(_configOpenTime)} - ${_formatSlotLabel(_configCloseTime)}',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(width: 1, color: Colors.grey.shade200),
                        const SizedBox(width: 24),

                        // RIGHT: Categories + Products
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 110),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Scrollbar(
                                  controller: categoryScrollCtrl,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: categoryScrollCtrl,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _buildCategoryChip('All', selectedCategoryId == null, () => setDialogState(() => selectedCategoryId = null)),
                                        ...allowedCategories.map((c) => _buildCategoryChip(c.name, selectedCategoryId == c.id, () => setDialogState(() => selectedCategoryId = c.id))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('Products & Services', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filteredProds.length,
                                  itemBuilder: (_, idx) {
                                    final p = filteredProds[idx];
                                    final isSelected = selectedProducts.any((sp) => sp.id == p.id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      activeColor: const Color(0xFFE11D48),
                                      title: Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                      subtitle: Text('\$${p.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedProducts.add(p);
                                          } else {
                                            selectedProducts.removeWhere((sp) => sp.id == p.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total:', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                                  Text('\$${totalPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Validation & Conflict Error Alert
                  if (validationOrConflictError != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFE11D48)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              validationOrConflictError!,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9F1239), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Submit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          if (selStaff == null) {
                            setDialogState(() => validationOrConflictError = 'Please select a staff member.');
                            return;
                          }

                          if (!isWalkIn && selCustomer == null) {
                            setDialogState(() => validationOrConflictError = 'Please search and select a customer, or switch to Walk-in.');
                            return;
                          }

                          if (isWalkIn && walkInNameCtrl.text.trim().isEmpty) {
                            setDialogState(() => validationOrConflictError = 'Please enter a name for the walk-in customer.');
                            return;
                          }

                          final rawStartInput = startCtrl.text.trim();
                          final rawEndInput = endCtrl.text.trim();

                          // 1. Validate format
                          final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
                          if (!timeRegex.hasMatch(rawStartInput) || !timeRegex.hasMatch(rawEndInput)) {
                            setDialogState(() {
                              validationOrConflictError = 'Please enter valid times in ${_timeFormat == '12' ? 'hh:mm (e.g. 09:30)' : 'HH:mm (e.g. 14:30)'} format.';
                            });
                            return;
                          }

                          // 2. Convert to standard 24-hr format for business validation & DB
                          final String effStartTime24 = _timeFormat == '12'
                              ? _convert12To24(rawStartInput, startPeriod)
                              : rawStartInput;
                          final String effEndTime24 = _timeFormat == '12'
                              ? _convert12To24(rawEndInput, endPeriod)
                              : rawEndInput;

                          final int startM = _timeToMinutes(effStartTime24);
                          final int endM = _timeToMinutes(effEndTime24);
                          final int openM = _timeToMinutes(_configOpenTime);
                          final int closeM = _timeToMinutes(_configCloseTime);

                          // 3. Validate duration
                          if (endM <= startM) {
                            setDialogState(() {
                              validationOrConflictError = 'End time must be later than start time.';
                            });
                            return;
                          }

                          final int durationMinutes = endM - startM;
                          if (durationMinutes < 15) {
                            setDialogState(() {
                              validationOrConflictError = 'Appointment duration must be at least 15 minutes (currently $durationMinutes min).';
                            });
                            return;
                          }

                          // 4. Validate business hours
                          final String displayOpen = _formatSlotLabel(_configOpenTime);
                          final String displayClose = _formatSlotLabel(_configCloseTime);
                          final String displayStart = _formatSlotLabel(effStartTime24);
                          final String displayEnd = _formatSlotLabel(effEndTime24);

                          if (startM < openM) {
                            setDialogState(() {
                              validationOrConflictError = 'Start time ($displayStart) is before business opening time ($displayOpen).';
                            });
                            return;
                          }

                          if (endM > closeM) {
                            setDialogState(() {
                              validationOrConflictError = 'End time ($displayEnd) exceeds business closing time ($displayClose).';
                            });
                            return;
                          }

                          final dateStr = '${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}';

                          // 5. Active conflict check (cancelled / no_show slots are treated as free!)
                          final conflict = await ApiService.checkAppointmentConflict(
                            staffId: selStaff!.id,
                            appointmentDate: dateStr,
                            startTime: effStartTime24,
                            endTime: effEndTime24,
                          );

                          if (conflict['has_conflict'] == true) {
                            final confAppt = conflict['conflicting_appointment'];
                            String confRange = '';
                            if (confAppt != null) {
                              final cs = _formatSlotLabel(confAppt['start_time'] ?? '');
                              final ce = _formatSlotLabel(confAppt['end_time'] ?? '');
                              confRange = ' ($cs - $ce)';
                            }
                            setDialogState(() {
                              validationOrConflictError = 'Collision: ${selStaff!.name} is already booked$confRange.';
                            });
                            return;
                          }

                          final custName = isWalkIn ? walkInNameCtrl.text.trim() : (selCustomer?.name ?? '');
                          final custPhone = isWalkIn ? walkInPhoneCtrl.text.trim() : (selCustomer?.phone ?? '');

                          final result = await ApiService.createAppointment({
                            'staff_id': selStaff!.id,
                            'customer_id': isWalkIn ? null : selCustomer?.id,
                            'customer_name': custName,
                            'customer_phone': custPhone,
                            'staff_name': selStaff!.name,
                            'appointment_date': dateStr,
                            'start_time': effStartTime24,
                            'end_time': effEndTime24,
                            'total_amount': totalPrice,
                            'services': selectedProducts.map((p) => {'product_id': p.id, 'name': p.name, 'price': p.price}).toList(),
                          });

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (result != null) {
                            _selectedDate = appointmentDate;
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Booked appointment for $custName with ${selStaff!.name} at $displayStart - $displayEnd',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: Text('Confirm Booking', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      categoryScrollCtrl.dispose();
      customerSearchDebounce?.cancel();
      customerSearchCtrl.dispose();
      walkInNameCtrl.dispose();
      walkInPhoneCtrl.dispose();
      startCtrl.dispose();
      endCtrl.dispose();
    });
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE11D48).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFE11D48) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFFE11D48) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  void _continueServiceInCart(AppointmentModel appt) {
    if (widget.onStartService == null) return;
    final customer = CustomerModel(
      id: appt.customerId ?? 0,
      businessId: appt.businessId,
      name: appt.customerName,
      phone: appt.customerPhone,
    );
    final List<ProductModel> products = [];
    for (final s in appt.services) {
      final pid = int.tryParse(s['product_id']?.toString() ?? s['id']?.toString() ?? '');
      final price = (s['price'] as num?)?.toDouble() ?? 0.0;
      final name = s['name']?.toString() ?? s['product_name']?.toString() ?? 'Service';
      final existing = _products.where((p) => (pid != null && p.id == pid) || p.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
      final ProductModel prodToAdd;
      if (existing != null) {
        prodToAdd = ProductModel(
          id: existing.id,
          businessId: existing.businessId,
          categoryId: existing.categoryId,
          name: existing.name,
          sku: existing.sku,
          productType: existing.productType,
          price: price > 0 ? price : existing.price,
          description: existing.description,
          modifiers: existing.modifiers,
          comboItems: existing.comboItems,
          isActive: existing.isActive,
          createdAt: existing.createdAt,
        );
      } else {
        prodToAdd = ProductModel(
          id: pid ?? (math.Random().nextInt(900000) + 10000),
          businessId: appt.businessId,
          name: name,
          price: price,
        );
      }
      final qty = (s['quantity'] as num?)?.toInt() ?? 1;
      for (int i = 0; i < (qty > 0 ? qty : 1); i++) {
        products.add(prodToAdd);
      }
    }
    widget.onStartService!(customer, products, appointment: appt);
  }

  void _confirmDeleteAppointment(BuildContext dialogCtx, AppointmentModel appt) {
    showDialog(
      context: context,
      builder: (confirmCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Service',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this appointment for "${appt.customerName}"? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(confirmCtx);
                Navigator.pop(dialogCtx);
                final success = await ApiService.deleteAppointment(appt.id);
                if (success) {
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFE11D48),
                        content: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Appointment deleted successfully.',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete appointment.'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Phase 6, 8, 9: Appointment Details & Actions Dialog
  void _showAppointmentDetails(AppointmentModel appt) {
    // Check if this active card overlays a previously cancelled/no-show card
    final underlyingInactive = _appointments.where((a) =>
        a.id != appt.id &&
        a.staffId == appt.staffId &&
        (a.status == 'cancelled' || a.status == 'no_show') &&
        appt.startMinutes < a.endMinutes &&
        a.startMinutes < appt.endMinutes).firstOrNull;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 485,
            constraints: BoxConstraints(
              maxWidth: 485,
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Appointment Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                // Scrollable Body (Ensures content stays completely inside popup)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details
                        _detailRow(Icons.person, 'Customer', appt.customerName),
                        _detailRow(Icons.phone, 'Phone', appt.customerPhone),
                        _detailRow(Icons.badge, 'Staff', appt.staffName),
                        _detailRow(Icons.calendar_today, 'Date', appt.appointmentDate),
                        _detailRow(Icons.schedule, 'Time', _formatApptTimeRange(appt)),
                        _detailRow(Icons.info_outline, 'Status', appt.statusLabel),
                        // Services section: Fixed height displaying up to 4 services with internal scrollbar
                        if (appt.services.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Services (${appt.services.length}):',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                              if (appt.services.length > 4)
                                Text(
                                  'Scroll to view all',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: appt.services.length >= 4 ? 140 : null,
                            constraints: const BoxConstraints(maxHeight: 140),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Scrollbar(
                              thumbVisibility: appt.services.length > 4,
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                itemCount: appt.services.length,
                                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                                itemBuilder: (ctx, idx) {
                                  final s = appt.services[idx];
                                  final sName = (s['name'] ?? s['product_name'] ?? 'Service').toString();
                                  final sPrice = s['price'] != null ? (s['price'] as num).toDouble() : null;
                                  return Container(
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE11D48),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            sName,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (sPrice != null)
                                          Text(
                                            '\$${sPrice.toStringAsFixed(2)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        if (appt.totalAmount > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Amount:',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF9F1239)),
                                ),
                                Text(
                                  '\$${appt.totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Non-destructive Layering Notice (Phase 9)
                        if (underlyingInactive != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Slot Layering: Booked over previously ${underlyingInactive.statusLabel.toLowerCase()} slot (${underlyingInactive.customerName} - ${underlyingInactive.timeRange}). The cancelled record remains safely preserved in DB.',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Duration Extension Section (Phase 9)
                        if (appt.status == 'booked' || appt.status == 'in_service') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.more_time, size: 16, color: Color(0xFFE11D48)),
                                        const SizedBox(width: 6),
                                        Text('Extend Duration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      ],
                                    ),
                                    Text('${appt.endMinutes - appt.startMinutes}m currently', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Preset increment options
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _extendDurationBtn(ctx, appt, 15),
                                      _extendDurationBtn(ctx, appt, 30),
                                      _extendDurationBtn(ctx, appt, 45),
                                      _extendDurationBtn(ctx, appt, 60),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Horizontally centered Custom button
                                Center(
                                  child: _customExtendDurationBtn(ctx, appt),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (appt.status == 'booked') ...[
                      _actionBtn('Start Service', Icons.play_arrow, const Color(0xFFF59E0B), () async {
                        Navigator.pop(ctx);
                        final success = await ApiService.updateAppointmentStatus(appt.id, 'in_service');
                        if (success) {
                          _loadData();
                          // Trigger cart preload via callback
                          _continueServiceInCart(appt);
                        }
                      }),
                      _actionBtn('Reschedule', Icons.edit_calendar, const Color(0xFF3B82F6), () {
                        Navigator.pop(ctx);
                        _showExactRescheduleDialog(appt);
                      }),
                      _actionBtn('Mark No Show', Icons.person_off, const Color(0xFFF43F5E), () async {
                        Navigator.pop(ctx);
                        await ApiService.updateAppointmentStatus(appt.id, 'no_show');
                        _loadData();
                      }),
                      _actionBtn('Cancel Booking', Icons.cancel, const Color(0xFF64748B), () async {
                        Navigator.pop(ctx);
                        await ApiService.updateAppointmentStatus(appt.id, 'cancelled');
                        _loadData();
                      }),
                      if (_allowDeleteService)
                        _actionBtn('Delete', Icons.delete_outline, const Color(0xFFE11D48), () {
                          _confirmDeleteAppointment(ctx, appt);
                        }),
                    ],
                    if (appt.status == 'in_service') ...[
                      _actionBtn('Continue Service', Icons.play_arrow_rounded, const Color(0xFF0D9488), () {
                        Navigator.pop(ctx);
                        _continueServiceInCart(appt);
                      }),
                      _actionBtn('Reschedule', Icons.edit_calendar, const Color(0xFF3B82F6), () {
                        Navigator.pop(ctx);
                        _showExactRescheduleDialog(appt);
                      }),
                      _actionBtn('Stop Service', Icons.pause_circle_outline, const Color(0xFFD97706), () async {
                        Navigator.pop(ctx);
                        final ok = await ApiService.updateAppointmentStatus(appt.id, 'booked');
                        if (ok) {
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFFD97706),
                                content: Row(
                                  children: [
                                    const Icon(Icons.pause_circle_outline, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Service stopped. Status reverted to Booked.', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }),
                      _actionBtn('Cancelled', Icons.cancel_outlined, const Color(0xFF64748B), () async {
                        Navigator.pop(ctx);
                        final ok = await ApiService.updateAppointmentStatus(appt.id, 'cancelled');
                        if (ok) {
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF64748B),
                                content: Row(
                                  children: [
                                    const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Appointment cancelled.', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }),
                      if (_allowDeleteService)
                        _actionBtn('Delete', Icons.delete_outline, const Color(0xFFE11D48), () {
                          _confirmDeleteAppointment(ctx, appt);
                        }),
                    ],
                    if (appt.status == 'completed') ...[
                      _actionBtn('View Receipt', Icons.receipt, const Color(0xFF10B981), () => Navigator.pop(ctx)),
                    ],
                    if (appt.status == 'cancelled' || appt.status == 'no_show') ...[
                      _actionBtn('Rebook', Icons.replay, const Color(0xFF3B82F6), () {
                        Navigator.pop(ctx);
                        _showNewAppointmentDialog();
                      }),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Quick duration extension button
  Widget _extendDurationBtn(BuildContext dialogCtx, AppointmentModel appt, int addMinutes) {
    return InkWell(
      onTap: () => _handleExtendAppointment(dialogCtx, appt, addMinutes),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
        ),
        child: Text(
          '+$addMinutes min',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE11D48)),
        ),
      ),
    );
  }

  // Custom time extension button (Light blue background, blue border, black text, clean card appearance)
  Widget _customExtendDurationBtn(BuildContext dialogCtx, AppointmentModel appt) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final initialH = (appt.endMinutes ~/ 60) % 24;
          final initialM = appt.endMinutes % 60;
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: initialH, minute: initialM),
          );
          if (picked != null) {
            final newEndMinutes = picked.hour * 60 + picked.minute;
            final addM = newEndMinutes - appt.endMinutes;
            if (addM <= 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New end time must be after current end time.'),
                    backgroundColor: Color(0xFFE11D48),
                  ),
                );
              }
              return;
            }
            if (dialogCtx.mounted) {
              await _handleExtendAppointment(dialogCtx, appt, addM);
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8.5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF), // Light blue background
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2563EB), width: 1.5), // Blue border
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 14, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Custom Duration',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black, // Black text
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle duration extension with conflict validation
  Future<void> _handleExtendAppointment(BuildContext dialogCtx, AppointmentModel appt, int addMinutes) async {
    final newEndMinutes = appt.endMinutes + addMinutes;
    if (newEndMinutes > 24 * 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot extend past midnight.'), backgroundColor: Color(0xFFE11D48)),
      );
      return;
    }
    final newEndH = (newEndMinutes ~/ 60) % 24;
    final newEndM = newEndMinutes % 60;
    final newEndTime = '${newEndH.toString().padLeft(2, '0')}:${newEndM.toString().padLeft(2, '0')}';

    // Conflict check for the extended window
    final conflict = await ApiService.checkAppointmentConflict(
      staffId: appt.staffId,
      appointmentDate: appt.appointmentDate,
      startTime: appt.endTime,
      endTime: newEndTime,
      excludeId: appt.id,
    );

    if (conflict['has_conflict'] == true) {
      final conf = conflict['conflicting_appointment'];
      final range = conf != null ? ' (${conf['start_time']} - ${conf['end_time']})' : '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            content: Text('Cannot extend: ${appt.staffName} already has an active appointment$range.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await ApiService.updateAppointment(appt.id, {'end_time': newEndTime});
    if (success) {
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Appointment extended to $newEndTime (+${addMinutes}m) successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    }
  }

  /// Phase 9: Exact Time Reschedule Dialog (minute-accurate e.g. 11:43 -> 12:57)
  void _showExactRescheduleDialog(AppointmentModel appt) {
    StaffModel targetStaff = _staffList.firstWhere(
      (s) => s.id == appt.staffId,
      orElse: () => _staffList.isNotEmpty
          ? _staffList.first
          : StaffModel(id: appt.staffId, businessId: 1, name: appt.staffName, email: '', phone: '', role: 'Specialist', isActive: true),
    );
    DateTime targetDate = DateTime.tryParse(appt.appointmentDate) ?? _selectedDate;
    final startCtrl = TextEditingController(text: appt.startTime);
    final endCtrl = TextEditingController(text: appt.endTime);
    String? errorMessage;
    bool isSaving = false;

    int timeToMinutes(String t) {
      final p = t.trim().split(':');
      if (p.length < 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    String minutesToTime(int m) {
      final h = (m ~/ 60) % 24;
      final min = m % 60;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final startM = timeToMinutes(startCtrl.text);
          final endM = timeToMinutes(endCtrl.text);
          final dur = endM - startM;
          final isValidRange = dur > 0;
          final durStr = isValidRange ? '$dur minutes (${dur ~/ 60}h ${dur % 60}m)' : 'Invalid duration';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_calendar, color: Color(0xFF3B82F6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exact Reschedule', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                              Text(appt.customerName, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 24),

                  // Staff Reassignment
                  Text('Staff Member', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<StaffModel>(
                    initialValue: targetStaff,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _staffList.map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          StaffAvatar(staff: s, radius: 11, fontSize: 10),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${s.name} (${s.role})', style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() { targetStaff = v; errorMessage = null; });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  Text('Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          targetDate = picked;
                          errorMessage = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.calendar_month, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start & End Time (minute-accurate input!)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Time (HH:mm)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: startCtrl,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'e.g. 11:43',
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.access_time_filled, size: 18, color: Color(0xFFE11D48)),
                                  onPressed: () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: startM ~/ 60, minute: startM % 60),
                                    );
                                    if (t != null) {
                                      startCtrl.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                      setModalState(() { errorMessage = null; });
                                    }
                                  },
                                ),
                              ),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              onChanged: (_) => setModalState(() { errorMessage = null; }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End Time (HH:mm)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: endCtrl,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'e.g. 12:57',
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.access_time_filled, size: 18, color: Color(0xFFE11D48)),
                                  onPressed: () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: endM ~/ 60, minute: endM % 60),
                                    );
                                    if (t != null) {
                                      endCtrl.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                      setModalState(() { errorMessage = null; });
                                    }
                                  },
                                ),
                              ),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              onChanged: (_) => setModalState(() { errorMessage = null; }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Duration Shortcuts
                  Row(
                    children: [
                      Text('Quick Duration:', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      ...[30, 45, 60, 90].map((d) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              final curStart = timeToMinutes(startCtrl.text);
                              endCtrl.text = minutesToTime(curStart + d);
                              setModalState(() { errorMessage = null; });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text('${d}m', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Calculated Duration banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isValidRange ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isValidRange ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        Icon(isValidRange ? Icons.timer_outlined : Icons.warning_amber_rounded, size: 16, color: isValidRange ? const Color(0xFF16A34A) : const Color(0xFFE11D48)),
                        const SizedBox(width: 8),
                        Text(
                          'Total Slot: $durStr',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isValidRange ? const Color(0xFF15803D) : const Color(0xFFBE123C)),
                        ),
                      ],
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFE11D48)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(errorMessage!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9F1239), fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSaving ? null : () async {
                          if (!isValidRange) {
                            setModalState(() => errorMessage = 'End time must be after start time.');
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          setModalState(() { isSaving = true; errorMessage = null; });

                          final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

                          // Active conflict check (cancelled / no_show slots are treated as free!)
                          final conflict = await ApiService.checkAppointmentConflict(
                            staffId: targetStaff.id,
                            appointmentDate: dateStr,
                            startTime: startCtrl.text.trim(),
                            endTime: endCtrl.text.trim(),
                            excludeId: appt.id,
                          );

                          if (conflict['has_conflict'] == true) {
                            final conf = conflict['conflicting_appointment'];
                            final range = conf != null ? ' (${conf['start_time']} - ${conf['end_time']})' : '';
                            setModalState(() {
                              isSaving = false;
                              errorMessage = 'Collision: ${targetStaff.name} is already booked$range.';
                            });
                            return;
                          }

                          // Save update to backend
                          final success = await ApiService.updateAppointment(appt.id, {
                            'staff_id': targetStaff.id,
                            'staff_name': targetStaff.name,
                            'appointment_date': dateStr,
                            'start_time': startCtrl.text.trim(),
                            'end_time': endCtrl.text.trim(),
                          });

                          if (success) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text('Rescheduled to ${targetStaff.name} at ${startCtrl.text} - ${endCtrl.text} on $dateStr', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              _loadData();
                            }
                          } else {
                            setModalState(() {
                              isSaving = false;
                              errorMessage = 'Failed to update appointment. Please try again.';
                            });
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Save Reschedule', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }
}

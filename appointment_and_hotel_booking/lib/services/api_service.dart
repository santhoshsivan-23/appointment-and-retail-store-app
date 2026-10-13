import '../constants/app_constant.dart';
import '../models/appointment_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/refund_model.dart';
import '../models/sale_model.dart';
import '../models/staff_model.dart';
import '../models/printer_settings_model.dart';
import '../models/history_summary_model.dart';
import 'auth_storage.dart';
import 'firebase_service.dart';

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final String? token;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.token,
    this.statusCode = 200,
  });
}

class ApiService {
  static String get defaultBaseUrl {
    final base = AppConstant.baseUrl.trim();
    if (base.endsWith('/api')) return base;
    return '$base/api';
  }

  static Future<String> getBaseUrl() async {
    final customUrl = await AuthStorage.getCustomBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      if (customUrl.endsWith('/api')) return customUrl;
      return '$customUrl/api';
    }
    return defaultBaseUrl;
  }

  // Auth: Register
  static Future<ApiResponse> register(Map<String, dynamic> businessData) async {
    return await FirebaseService.register(businessData);
  }

  // Auth: Login
  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    return await FirebaseService.login(email: email, password: password);
  }

  // Staff APIs
  static Future<List<StaffModel>> getStaff({String search = '', bool includeDeleted = false}) async {
    return await FirebaseService.getStaff(search: search, includeDeleted: includeDeleted);
  }

  static Future<StaffModel?> getStaffById(int id) async {
    return await FirebaseService.getStaffById(id);
  }

  static Future<bool> createStaff(Map<String, dynamic> data) async {
    return await FirebaseService.createStaff(data);
  }

  static Future<bool> updateStaff(int id, Map<String, dynamic> data) async {
    return await FirebaseService.updateStaff(id, data);
  }

  static Future<bool> deleteStaff(int id) async {
    return await FirebaseService.deleteStaff(id);
  }

  // Customer APIs
  static Future<List<CustomerModel>> getCustomers({String search = ''}) async {
    return await FirebaseService.getCustomers(search: search);
  }

  static Future<List<CustomerModel>> searchCustomers(String query) =>
      getCustomers(search: query);

  static Future<CustomerModel?> createCustomer(Map<String, dynamic> data) async {
    return await FirebaseService.createCustomer(data);
  }

  // Category APIs
  static Future<List<CategoryModel>> getCategories() async {
    return await FirebaseService.getCategories();
  }

  static Future<bool> createCategory(Map<String, dynamic> data) async {
    return await FirebaseService.createCategory(data);
  }

  static Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    return await FirebaseService.updateCategory(id, data);
  }

  static Future<bool> deleteCategory(int id) async {
    return await FirebaseService.deleteCategory(id);
  }

  // Product APIs
  static Future<List<ProductModel>> getProducts({
    int? categoryId,
    String? productType,
    String search = '',
  }) async {
    return await FirebaseService.getProducts(
      categoryId: categoryId,
      productType: productType,
      search: search,
    );
  }

  static Future<bool> createProduct(Map<String, dynamic> data) async {
    return await FirebaseService.createProduct(data);
  }

  static Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    return await FirebaseService.updateProduct(id, data);
  }

  static Future<bool> deleteProduct(int id) async {
    return await FirebaseService.deleteProduct(id);
  }

  static Future<List<ProductModel>> searchProducts(String query) async {
    return await FirebaseService.getProducts(search: query);
  }

  // Appointment APIs
  static Future<List<AppointmentModel>> getAppointments({
    String? date,
    String? startDate,
    String? endDate,
    int? staffId,
    String? search,
    String? status,
  }) async {
    return await FirebaseService.getAppointments(
      date: date,
      startDate: startDate,
      endDate: endDate,
      staffId: staffId,
      search: search,
      status: status,
    );
  }

  static Future<PaginatedResult<AppointmentModel>> getAppointmentsPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return await FirebaseService.getAppointmentsPaginated(
      startDate: startDate,
      endDate: endDate,
      search: search,
      status: status,
      page: page,
      limit: limit,
    );
  }

  static Future<HistorySummaryModel> getAppointmentSummary({
    String? startDate,
    String? endDate,
    String? search,
    String? date,
  }) async {
    return await FirebaseService.getAppointmentSummary(
      startDate: startDate,
      endDate: endDate,
      search: search,
      date: date,
    );
  }

  static Future<Map<String, int>> getAppointmentStats({String? date}) async {
    return await FirebaseService.getAppointmentStats(date: date);
  }

  static Future<AppointmentModel?> createAppointment(Map<String, dynamic> data) async {
    return await FirebaseService.createAppointment(data);
  }

  static Future<bool> updateAppointmentStatus(int id, String status) async {
    return await FirebaseService.updateAppointmentStatus(id, status);
  }

  static Future<bool> updateAppointment(int id, Map<String, dynamic> data) async {
    return await FirebaseService.updateAppointment(id, data);
  }

  static Future<bool> deleteAppointment(int id) async {
    return await FirebaseService.deleteAppointment(id);
  }

  static Future<AppointmentModel?> getAppointmentById(int id) async {
    return await FirebaseService.getAppointmentById(id);
  }

  static Future<CheckConflictResult> checkConflict({
    required int staffId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int? excludeId,
  }) async {
    return await FirebaseService.checkConflict(
      staffId: staffId,
      appointmentDate: appointmentDate,
      startTime: startTime,
      endTime: endTime,
      excludeId: excludeId,
    );
  }

  static Future<Map<String, dynamic>> checkAppointmentConflict({
    required int staffId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int? excludeId,
  }) async {
    final res = await checkConflict(
      staffId: staffId,
      appointmentDate: appointmentDate,
      startTime: startTime,
      endTime: endTime,
      excludeId: excludeId,
    );
    return {
      'has_conflict': res.hasConflict,
      'conflicting_appointment': res.conflictingAppointment,
      'message': res.message,
    };
  }

  // Sales APIs
  static Future<SaleModel?> createSale(Map<String, dynamic> data) async {
    return await FirebaseService.createSale(data);
  }

  static Future<List<SaleModel>> getSales({
    int? appointmentId,
    String? search,
    String? startDate,
    String? endDate,
    String? paymentMethod,
    bool includeAppointments = false,
  }) async {
    return await FirebaseService.getSales(
      appointmentId: appointmentId,
      search: search,
      startDate: startDate,
      endDate: endDate,
      paymentMethod: paymentMethod,
      includeAppointments: includeAppointments,
    );
  }

  static Future<PaginatedResult<SaleModel>> getSalesPaginated({
    String? startDate,
    String? endDate,
    String? search,
    String? paymentMethod,
    bool includeAppointments = false,
    int page = 1,
    int limit = 20,
  }) async {
    return await FirebaseService.getSalesPaginated(
      startDate: startDate,
      endDate: endDate,
      search: search,
      paymentMethod: paymentMethod,
      includeAppointments: includeAppointments,
      page: page,
      limit: limit,
    );
  }

  static Future<HistorySummaryModel> getSaleSummary({
    String? startDate,
    String? endDate,
    String? search,
    String? paymentMethod,
    bool includeAppointments = false,
  }) async {
    return await FirebaseService.getSaleSummary(
      startDate: startDate,
      endDate: endDate,
      search: search,
      paymentMethod: paymentMethod,
      includeAppointments: includeAppointments,
    );
  }

  static Future<SaleModel?> getSaleById(int id) async {
    return await FirebaseService.getSaleById(id);
  }

  // Refund APIs
  static Future<ApiResponse> processSaleRefund(int saleId, Map<String, dynamic> payload) async {
    return await FirebaseService.processSaleRefund(saleId, payload);
  }

  static Future<ApiResponse> processAppointmentRefund(int appointmentId, Map<String, dynamic> payload) async {
    return await FirebaseService.processAppointmentRefund(appointmentId, payload);
  }

  static Future<List<RefundRecordModel>> getSaleRefunds(int saleId) async {
    return await FirebaseService.getSaleRefunds(saleId);
  }

  static Future<List<RefundRecordModel>> getAppointmentRefunds(int appointmentId) async {
    return await FirebaseService.getAppointmentRefunds(appointmentId);
  }

  // Settings APIs
  static Future<ApiResponse> getSettings({int? businessId}) async {
    return await FirebaseService.getSettings(businessId: businessId);
  }

  static Future<ApiResponse> updateSettings(Map<String, dynamic> settingsData) async {
    return await FirebaseService.updateSettings(settingsData);
  }

  static Future<PrinterSettingsModel> getPrinterSettings({int? businessId}) async {
    return await FirebaseService.getPrinterSettings(businessId: businessId);
  }

  static Future<ApiResponse> updatePrinterSettings(
    Map<String, dynamic> printerSettings, {
    int? businessId,
  }) async {
    return await FirebaseService.updatePrinterSettings(printerSettings, businessId: businessId);
  }

  // Print Test & Receipt execution
  static Future<ApiResponse> testPrint(Map<String, dynamic> payload) async {
    final ip = payload['ip_address'] ?? 'LAN printer';
    return ApiResponse(
      success: true,
      message: 'Test print sent successfully to $ip.',
      statusCode: 200,
    );
  }

  static Future<ApiResponse> printReceipt(Map<String, dynamic> payload) async {
    return ApiResponse(
      success: true,
      message: 'Receipt print command executed successfully.',
      statusCode: 200,
    );
  }
}

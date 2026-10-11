import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

class ParentProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  List<Invoice> _invoices = [];
  List<ChatThread> _chatThreads = [];
  VietQrPayment? _currentQr;
  bool _loading = false;
  String? _error;

  List<Invoice> get invoices => _invoices;
  List<ChatThread> get chatThreads => _chatThreads;
  VietQrPayment? get currentQr => _currentQr;
  bool get loading => _loading;
  String? get error => _error;

  // ── Invoices ──

  Future<void> loadInvoices(String studentId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.parentInvoices,
          queryParameters: {'studentId': studentId});
      _invoices = (res.data as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadVietQr(String invoiceId) async {
    _loading = true;
    notifyListeners();
    try {
      final res =
          await _dio.get(ApiEndpoints.parentInvoiceVietQr(invoiceId));
      _currentQr = VietQrPayment.fromJson(res.data);
      _error = null;
    } on DioException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  // ── Leave requests ──

  Future<bool> submitLeaveRequest(LeaveRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentLeaveRequests, data: req.toJson());
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] as String? ??
          'Không thể gửi đơn xin nghỉ';
      notifyListeners();
      return false;
    }
  }

  // ── Medications ──

  Future<bool> submitMedication(MedicationRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentMedications, data: req.toJson());
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] as String? ??
          'Không thể gửi dặn thuốc';
      notifyListeners();
      return false;
    }
  }

  // ── Chat ──

  Future<void> loadChatThreads() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.chatThreads);
      _chatThreads = (res.data as List)
          .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  Future<void> loadMessages(String threadId) async {
    try {
      final res = await _dio.get(ApiEndpoints.chatMessages(threadId));
      final content = res.data['content'] as List? ?? res.data as List;
      _messages = content
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String threadId, String content) async {
    try {
      await _dio.post(ApiEndpoints.chatMessages(threadId),
          data: {'content': content});
      await loadMessages(threadId);
      return true;
    } on DioException {
      return false;
    }
  }
}

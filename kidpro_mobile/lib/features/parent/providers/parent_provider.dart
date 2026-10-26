import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

class ParentProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  // ── 0. DYNAMIC STUDENTS CONTEXT (FROM DATABASE) ──
  List<StudentSummary> _students = [];
  String _selectedStudentId = '';
  String _selectedStudentName = '';
  String? _selectedParentId;

  List<StudentSummary> get students => _students;
  String get selectedStudentId => _selectedStudentId;
  String get selectedStudentName => _selectedStudentName;
  String? get selectedParentId => _selectedParentId;
  bool get hasStudents => _students.isNotEmpty;

  StudentSummary? get selectedStudent {
    if (_students.isEmpty) return null;
    return _students.firstWhere(
      (s) => s.studentId == _selectedStudentId,
      orElse: () => _students.first,
    );
  }

  void setSelectedStudent(String id, String name, [String? parentId]) {
    _selectedStudentId = id;
    _selectedStudentName = name;
    _selectedParentId = parentId;
    notifyListeners();
  }

  void selectStudent(StudentSummary student) {
    _selectedStudentId = student.studentId;
    _selectedStudentName = student.displayName;
    _selectedParentId = student.parentId;
    notifyListeners();
    loadStudentData(student.studentId);
  }

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  /// Loads all children associated with the currently authenticated parent account.
  Future<void> loadMyStudents() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.parentStudents);
      final list = res.data as List;
      _students = list
          .map((e) => StudentSummary.fromJson(e as Map<String, dynamic>))
          .toList();

      if (_students.isNotEmpty) {
        final currentValid =
            _students.any((s) => s.studentId == _selectedStudentId);
        if (!currentValid) {
          final first = _students.first;
          _selectedStudentId = first.studentId;
          _selectedStudentName = first.displayName;
          _selectedParentId = first.parentId;
        }
        await loadStudentData(_selectedStudentId);
      } else {
        _selectedStudentId = '';
        _selectedStudentName = 'Chưa có thông tin học sinh';
        _selectedParentId = null;
        _invoices = [];
        _leaveRequests = [];
        _emergencyPickups = [];
        _guardians = [];
        _medications = [];
        _allergies = [];
      }
      _error = null;
    } on DioException catch (e) {
      logError('loadMyStudents', e);
      _error = e.response?.data?['message']?.toString() ?? e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Automatically triggers real data loads for the chosen child across all modules.
  Future<void> loadStudentData(String studentId) async {
    if (studentId.isEmpty) return;
    await Future.wait([
      loadInvoices(studentId),
      loadLeaveRequests(studentId),
      loadEmergencyPickups(studentId),
      loadGuardians(studentId),
      loadMedications(studentId),
      loadAllergies(studentId),
      loadDailyActivities(studentId),
      loadAttendances(studentId),
      loadEvaluations(studentId),
      loadGrowthHistory(studentId),
      loadAllRequests(studentId),
    ]);
    if (selectedStudent?.classId != null && selectedStudent!.classId!.isNotEmpty) {
      loadJournalPosts(selectedStudent!.classId!);
    }
  }

  // ── 1. INVOICES & VIETQR (G8-UC-08, G8-UC-09) ──
  List<Invoice> _invoices = [];
  VietQrPayment? _currentQr;

  List<Invoice> get invoices => _invoices;
  VietQrPayment? get currentQr => _currentQr;

  Future<void> loadInvoices([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _invoices = [];
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.parentInvoices,
          queryParameters: {'studentId': targetId});
      _invoices = (res.data as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadInvoices', e);
      _invoices = [];
      _error = e.response?.data?['message']?.toString() ?? e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadVietQr(String invoiceId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.parentInvoiceVietQr(invoiceId));
      _currentQr = VietQrPayment.fromJson(res.data);
      _error = null;
    } on DioException catch (e) {
      logError('loadVietQr', e);
      _currentQr = null;
      _error = e.response?.data?['message']?.toString() ?? e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── 2. LEAVE REQUESTS (G10-UC-08) ──
  List<LeaveRequest> _leaveRequests = [];
  List<LeaveRequest> get leaveRequests => _leaveRequests;

  Future<void> loadLeaveRequests([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _leaveRequests = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentLeaveRequests,
          queryParameters: {'studentId': targetId});
      final rawData = res.data is Map<String, dynamic> && res.data['data'] != null
          ? res.data['data']
          : res.data;
      if (rawData is List) {
        _leaveRequests = rawData
            .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _leaveRequests = [];
      }
      _error = null;
    } on DioException catch (e) {
      logError('loadLeaveRequests', e);
      _leaveRequests = [];
    }
    notifyListeners();
  }

  Future<bool> submitLeaveRequest(LeaveRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentLeaveRequests, data: req.toJson());
      await loadLeaveRequests(req.studentId);
      return true;
    } on DioException catch (e) {
      logError('submitLeaveRequest', e);
      _error = e.response?.data?['message']?.toString() ?? 'Gửi đơn thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelLeaveRequest(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentLeaveRequestCancel(id));
      _leaveRequests.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('cancelLeaveRequest', e);
      return false;
    }
  }

  // ── 3. EMERGENCY PICKUPS (G5-UC-07) ──
  List<EmergencyPickup> _emergencyPickups = [];
  List<EmergencyPickup> get emergencyPickups => _emergencyPickups;

  Future<void> loadEmergencyPickups([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _emergencyPickups = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentEmergencyPickups,
          queryParameters: {'studentId': targetId});
      _emergencyPickups = (res.data as List)
          .map((e) => EmergencyPickup.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadEmergencyPickups', e);
      _emergencyPickups = [];
    }
    notifyListeners();
  }

  Future<EmergencyPickup?> createEmergencyPickup(
      EmergencyPickup req, String parentId) async {
    try {
      final effectiveParentId = parentId.isNotEmpty
          ? parentId
          : (_selectedParentId ?? '');
      final res = await _dio.post(ApiEndpoints.parentEmergencyPickups,
          data: req.toJson(effectiveParentId));
      final created = EmergencyPickup.fromJson(res.data);
      _emergencyPickups.insert(0, created);
      notifyListeners();
      return created;
    } on DioException catch (e) {
      logError('createEmergencyPickup', e);
      _error = e.response?.data?['message']?.toString() ?? 'Tạo mã ủy quyền thất bại';
      notifyListeners();
      return null;
    }
  }

  Future<bool> revokeEmergencyPickup(int id) async {
    try {
      await _dio.put(ApiEndpoints.parentEmergencyPickupRevoke(id));
      _emergencyPickups = _emergencyPickups
          .map((p) => p.authorizationId == id
              ? EmergencyPickup(
                  authorizationId: p.authorizationId,
                  studentId: p.studentId,
                  studentName: p.studentName,
                  pickupPersonName: p.pickupPersonName,
                  pickupPersonPhone: p.pickupPersonPhone,
                  otpCode: p.otpCode,
                  validUntil: p.validUntil,
                  status: 'EXPIRED',
                  qrData: p.qrData,
                )
              : p)
          .toList();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('revokeEmergencyPickup', e);
      return false;
    }
  }

  // ── 4. AUTHORIZED GUARDIANS (G4-UC-03) ──
  List<AuthorizedGuardian> _guardians = [];
  List<AuthorizedGuardian> get guardians => _guardians;

  Future<void> loadGuardians([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _guardians = [];
      notifyListeners();
      return;
    }

    try {
      final res =
          await _dio.get(ApiEndpoints.parentStudentGuardians(targetId));
      _guardians = (res.data as List)
          .map((e) => AuthorizedGuardian.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadGuardians', e);
      _guardians = [];
    }
    notifyListeners();
  }

  Future<bool> registerGuardian(AuthorizedGuardian guardian) async {
    try {
      final res =
          await _dio.post(ApiEndpoints.parentGuardians, data: guardian.toJson());
      final created = AuthorizedGuardian.fromJson(res.data);
      _guardians.add(created);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('registerGuardian', e);
      _error = e.response?.data?['message']?.toString() ?? 'Thêm người đón thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> revokeGuardian(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentGuardianRevoke(id));
      _guardians = _guardians.where((g) => g.guardianId != id).toList();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('revokeGuardian', e);
      return false;
    }
  }

  // ── 5. MEDICATION REQUESTS (G10-UC-01) ──
  List<MedicationRequest> _medications = [];
  List<MedicationRequest> get medications => _medications;

  Future<void> loadMedications([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _medications = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentMedications,
          queryParameters: {'studentId': targetId});
      _medications = (res.data as List)
          .map((e) => MedicationRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadMedications', e);
      _medications = [];
    }
    notifyListeners();
  }

  Future<bool> submitMedication(MedicationRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentMedications, data: req.toJson());
      await loadMedications(req.studentId);
      return true;
    } on DioException catch (e) {
      logError('submitMedication', e);
      _error = e.response?.data?['message']?.toString() ?? 'Gửi dặn thuốc thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelMedication(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentMedicationCancel(id));
      _medications.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('cancelMedication', e);
      return false;
    }
  }

  // ── 6. ALLERGIES & HEALTH PROFILE (G4-UC-06) ──
  List<AllergyAlert> _allergies = [];
  List<AllergyAlert> get allergies => _allergies;

  Future<void> loadAllergies([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _allergies = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentAllergies,
          queryParameters: {'studentId': targetId});
      _allergies = (res.data as List)
          .map((e) => AllergyAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadAllergies', e);
      _allergies = [];
    }
    notifyListeners();
  }

  Future<bool> createAllergy(AllergyAlert allergy) async {
    try {
      final res =
          await _dio.post(ApiEndpoints.parentAllergies, data: allergy.toJson());
      final created = AllergyAlert.fromJson(res.data);
      _allergies.add(created);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('createAllergy', e);
      _error = e.response?.data?['message']?.toString() ?? 'Thêm dị ứng thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAllergy(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentAllergyDelete(id));
      _allergies.removeWhere((a) => a.allergyId == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('deleteAllergy', e);
      return false;
    }
  }

  // ── 7. DECREE 13 BIOMETRIC PURGE (UC-Decree13) ──
  BiometricPurgeCertificate? _purgeCertificate;
  BiometricPurgeCertificate? get purgeCertificate => _purgeCertificate;

  Future<String?> requestPurgeOtp([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) return null;

    try {
      final res = await _dio.post(ApiEndpoints.parentBiometricPurgeOtp(targetId));
      return res.data['otp']?.toString();
    } on DioException catch (e) {
      logError('requestPurgeOtp', e);
      return null;
    }
  }

  Future<bool> confirmBiometricPurge(String otpCode, String reason,
      [String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) return false;

    try {
      final res = await _dio.post(
        ApiEndpoints.parentBiometricPurgeConfirm(targetId),
        data: {'otpCode': otpCode, 'reason': reason},
      );
      _purgeCertificate = BiometricPurgeCertificate.fromJson(res.data);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('confirmBiometricPurge', e);
      _purgeCertificate = null;
      _error = e.response?.data?['message']?.toString() ?? e.message;
      notifyListeners();
      return false;
    }
  }

  // ── 8. CHAT ──
  List<ChatThread> _chatThreads = [];
  List<ChatMessage> _messages = [];

  List<ChatThread> get chatThreads => _chatThreads;
  List<ChatMessage> get messages => _messages;

  Future<void> loadChatThreads() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.chatThreads);
      _chatThreads = (res.data as List)
          .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadChatThreads', e);
      _chatThreads = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String threadId) async {
    try {
      final res = await _dio.get(ApiEndpoints.chatMessages(threadId));
      final content = res.data['content'] as List? ?? res.data as List;
      _messages = content
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadMessages', e);
      _messages = [];
    }
    notifyListeners();
  }

  Future<bool> sendMessage(String threadId, String content) async {
    try {
      final res = await _dio.post(ApiEndpoints.chatMessages(threadId),
          data: {'content': content});
      final newMsg = ChatMessage.fromJson(res.data);
      _messages.add(newMsg);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      logError('sendMessage', e);
      return false;
    }
  }

  // ── 9. SỔ ĐIỆN TỬ: SỔ SINH HOẠT HẰNG NGÀY (student.daily_activities) ──
  List<DailyActivityModel> _dailyActivities = [];
  List<DailyActivityModel> get dailyActivities => _dailyActivities;

  Future<void> loadDailyActivities([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _dailyActivities = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentDailyActivities(targetId));
      _dailyActivities = (res.data as List)
          .map((e) => DailyActivityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadDailyActivities', e);
      _dailyActivities = [];
    }
    notifyListeners();
  }

  // ── 10. SỔ ĐIỆN TỬ: SỔ ĐIỂM DANH ĐIỆN TỬ (student.attendances) ──
  List<AttendanceRecordModel> _attendances = [];
  List<AttendanceRecordModel> get attendances => _attendances;

  Future<void> loadAttendances([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _attendances = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentAttendances(targetId));
      _attendances = (res.data as List)
          .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadAttendances', e);
      _attendances = [];
    }
    notifyListeners();
  }

  // ── 11. SỔ ĐIỆN TỬ: SỔ ĐÁNH GIÁ PHÁT TRIỂN ĐỊNH KỲ (student.development_evaluation) ──
  List<DevelopmentEvaluationModel> _evaluations = [];
  List<DevelopmentEvaluationModel> get evaluations => _evaluations;

  Future<void> loadEvaluations([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _evaluations = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentEvaluations(targetId));
      _evaluations = (res.data as List)
          .map((e) => DevelopmentEvaluationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadEvaluations', e);
      _evaluations = [];
    }
    notifyListeners();
  }

  // ── 12. SỔ ĐIỆN TỬ: SỔ Y TẾ & THỂ CHẤT WHO (health.health_metrics) ──
  List<HealthGrowthMetricModel> _growthHistory = [];
  List<HealthGrowthMetricModel> get growthHistory => _growthHistory;

  Future<void> loadGrowthHistory([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _growthHistory = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentGrowthHistory(targetId));
      final data = res.data;
      final list = (data is Map && data['data'] != null) ? data['data'] as List : (data as List? ?? []);
      _growthHistory = list
          .map((e) => HealthGrowthMetricModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadGrowthHistory', e);
      _growthHistory = [];
    }
    notifyListeners();
  }

  // ── 13. SỔ ĐIỆN TỬ: SỔ NHẬT KÝ LỚP HỌC (academic.classroom_journal_post) ──
  List<JournalPostModel> _journalPosts = [];
  List<JournalPostModel> get journalPosts => _journalPosts;

  Future<void> loadJournalPosts(String classId) async {
    if (classId.isEmpty) return;
    try {
      final res = await _dio.get(ApiEndpoints.parentJournalPosts(classId));
      final data = res.data;
      final list = (data is Map && data['data'] != null) ? data['data'] as List : (data as List? ?? []);
      _journalPosts = list
          .map((e) => JournalPostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadJournalPosts', e);
      _journalPosts = [];
    }
    notifyListeners();
  }

  // ── 14. TRUNG TÂM ĐƠN TỪ: TỔNG HỢP TOÀN BỘ 11 LOẠI ĐƠN TỪ ──
  List<ParentUnifiedRequest> _allRequests = [];
  List<ParentUnifiedRequest> get allRequests => _allRequests;

  Future<void> loadAllRequests([String? studentId]) async {
    final targetId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : _selectedStudentId;
    if (targetId.isEmpty) {
      _allRequests = [];
      notifyListeners();
      return;
    }

    try {
      final res = await _dio.get(ApiEndpoints.parentAllRequests(targetId));
      _allRequests = (res.data as List)
          .map((e) => ParentUnifiedRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadAllRequests', e);
      _allRequests = [];
    }
    notifyListeners();
  }

  // ── 15. DANH MỤC THAM CHIẾU CHO FORM NỘP ĐƠN ──
  List<AvailableOption> _availableClasses = [];
  List<AvailableOption> _availableBuses = [];
  List<AvailableOption> _availableExtracurricular = [];

  List<AvailableOption> get availableClasses => _availableClasses;
  List<AvailableOption> get availableBuses => _availableBuses;
  List<AvailableOption> get availableExtracurricular => _availableExtracurricular;

  Future<void> loadFormOptions() async {
    try {
      final resClasses = await _dio.get(ApiEndpoints.parentAvailableClasses);
      _availableClasses = (resClasses.data as List)
          .map((e) => AvailableOption.fromClassJson(e as Map<String, dynamic>))
          .toList();

      final resBuses = await _dio.get(ApiEndpoints.parentAvailableBuses);
      _availableBuses = (resBuses.data as List)
          .map((e) => AvailableOption.fromBusJson(e as Map<String, dynamic>))
          .toList();

      final resExtra = await _dio.get(ApiEndpoints.parentAvailableExtracurricular);
      _availableExtracurricular = (resExtra.data as List)
          .map((e) => AvailableOption.fromExtraJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('loadFormOptions error: $e');
    }
    notifyListeners();
  }

  Future<bool> submitClassTransfer({
    required String studentId,
    required String toClassId,
    required String reason,
    String? effectiveDate,
  }) async {
    try {
      await _dio.post(ApiEndpoints.parentClassTransfer, data: {
        'studentId': studentId,
        'toClassId': toClassId,
        'reason': reason,
        if (effectiveDate != null) 'effectiveDate': effectiveDate,
      });
      await loadAllRequests(studentId);
      return true;
    } on DioException catch (e) {
      logError('submitClassTransfer', e);
      _error = e.response?.data?['message']?.toString() ?? 'Nộp đơn chuyển lớp thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitBusRegister({
    required String studentId,
    required String busId,
    required String pickupAddress,
    required String pickupType,
    String? startDate,
    String? note,
  }) async {
    try {
      await _dio.post(ApiEndpoints.parentBusRegister, data: {
        'studentId': studentId,
        'busId': busId,
        'pickupAddress': pickupAddress,
        'pickupType': pickupType,
        if (startDate != null) 'startDate': startDate,
        if (note != null) 'note': note,
      });
      await loadAllRequests(studentId);
      return true;
    } on DioException catch (e) {
      logError('submitBusRegister', e);
      _error = e.response?.data?['message']?.toString() ?? 'Đăng ký xe buýt thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitExtracurricularRegister({
    required String studentId,
    required String extracurricularClassId,
    String? startDate,
    String? note,
  }) async {
    try {
      await _dio.post(ApiEndpoints.parentExtracurricularRegister, data: {
        'studentId': studentId,
        'extracurricularClassId': extracurricularClassId,
        if (startDate != null) 'startDate': startDate,
        if (note != null) 'note': note,
      });
      await loadAllRequests(studentId);
      return true;
    } on DioException catch (e) {
      logError('submitExtracurricularRegister', e);
      _error = e.response?.data?['message']?.toString() ?? 'Đăng ký ngoại khóa thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitOtherRequest({
    required String studentId,
    required String title,
    required String content,
  }) async {
    try {
      await _dio.post(ApiEndpoints.parentOtherRequest, data: {
        'studentId': studentId,
        'title': title,
        'content': content,
      });
      await loadAllRequests(studentId);
      return true;
    } on DioException catch (e) {
      logError('submitOtherRequest', e);
      _error = e.response?.data?['message']?.toString() ?? 'Gửi đơn thất bại';
      notifyListeners();
      return false;
    }
  }

  void logError(String action, DioException e) {
    if (kDebugMode) {
      print('[$action] Dio Error: ${e.response?.statusCode} -> ${e.message}');
    }
  }
}

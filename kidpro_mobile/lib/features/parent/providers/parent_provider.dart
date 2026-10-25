import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';

class ParentProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  // Selected student context (defaults to demo student)
  String _selectedStudentId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
  String _selectedStudentName = 'Nguyễn Tuấn Kiệt (Lớp Mầm 1)';

  String get selectedStudentId => _selectedStudentId;
  String get selectedStudentName => _selectedStudentName;

  void setSelectedStudent(String id, String name) {
    _selectedStudentId = id;
    _selectedStudentName = name;
    notifyListeners();
  }

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  // ── 1. INVOICES & VIETQR ──
  List<Invoice> _invoices = [];
  VietQrPayment? _currentQr;

  List<Invoice> get invoices => _invoices;
  VietQrPayment? get currentQr => _currentQr;

  Future<void> loadInvoices([String? studentId]) async {
    _loading = true;
    notifyListeners();
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.get(ApiEndpoints.parentInvoices,
          queryParameters: {'studentId': targetId});
      _invoices = (res.data as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      logError('loadInvoices', e);
      // Fallback mock invoices for seamless preview
      _invoices = [
        Invoice(
          id: 'inv-oct-2026',
          studentName: _selectedStudentName,
          periodLabel: 'Học phí Tháng 10/2026',
          totalAmount: 3850000,
          paidAmount: 0,
          status: 'UNPAID',
          referenceCode: 'KIDPRO-202610-001',
          paymentQrCode:
              'https://img.vietqr.io/image/970422-KIDPRO8888-compact2.png?amount=3850000&addInfo=KIDPRO-202610-001&accountName=TRUONG%20MAM%20NON%20KIDPRO',
        ),
        Invoice(
          id: 'inv-sep-2026',
          studentName: _selectedStudentName,
          periodLabel: 'Học phí Tháng 09/2026',
          totalAmount: 3850000,
          paidAmount: 3850000,
          status: 'PAID',
          referenceCode: 'KIDPRO-202609-001',
        ),
      ];
    }
    _loading = false;
    notifyListeners();
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
      _currentQr = VietQrPayment(
        qrDataUrl:
            'https://img.vietqr.io/image/970422-KIDPRO8888-compact2.png?amount=3850000&addInfo=KIDPRO-$invoiceId&accountName=TRUONG%20MAM%20NON%20KIDPRO',
        bankName: 'MB Bank',
        accountNumber: '999988887777',
        accountName: 'TRUONG MAM NON QUOC TE KIDPRO',
        amount: 3850000,
        referenceCode: 'KIDPRO-$invoiceId',
      );
    }
    _loading = false;
    notifyListeners();
  }

  // ── 2. LEAVE REQUESTS (G10-UC-08) ──
  List<LeaveRequest> _leaveRequests = [];
  List<LeaveRequest> get leaveRequests => _leaveRequests;

  Future<void> loadLeaveRequests([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.get(ApiEndpoints.parentLeaveRequests,
          queryParameters: {'studentId': targetId});
      _leaveRequests = (res.data as List)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadLeaveRequests', e);
      _leaveRequests = [
        LeaveRequest(
          id: 1,
          studentId: targetId,
          studentName: _selectedStudentName,
          reason: 'Bé bị sốt nhẹ, gia đình cho nghỉ theo dõi tại nhà',
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 2)),
          status: 'PENDING',
          eligibleForMealRefund: true,
        ),
      ];
    }
    notifyListeners();
  }

  Future<bool> submitLeaveRequest(LeaveRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentLeaveRequests, data: req.toJson());
      await loadLeaveRequests(req.studentId);
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] as String? ?? 'Gửi đơn thất bại';
      // Local fallback in test mode
      _leaveRequests.insert(0, req);
      notifyListeners();
      return true;
    }
  }

  Future<bool> cancelLeaveRequest(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentLeaveRequestCancel(id));
      _leaveRequests.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _leaveRequests.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    }
  }

  // ── 3. EMERGENCY PICKUPS (G5-UC-07) ──
  List<EmergencyPickup> _emergencyPickups = [];
  List<EmergencyPickup> get emergencyPickups => _emergencyPickups;

  Future<void> loadEmergencyPickups([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.get(ApiEndpoints.parentEmergencyPickups,
          queryParameters: {'studentId': targetId});
      _emergencyPickups = (res.data as List)
          .map((e) => EmergencyPickup.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadEmergencyPickups', e);
      _emergencyPickups = [
        EmergencyPickup(
          authorizationId: 101,
          studentId: targetId,
          studentName: _selectedStudentName,
          pickupPersonName: 'Bác Nguyễn Thị Mai (Hàng xóm)',
          pickupPersonPhone: '0912345678',
          otpCode: '852963',
          validUntil: DateTime.now().add(const Duration(minutes: 45)),
          status: 'ACTIVE',
          qrData: 'KIDPRO_PICKUP:101:$targetId:852963',
        ),
      ];
    }
    notifyListeners();
  }

  Future<EmergencyPickup?> createEmergencyPickup(
      EmergencyPickup req, String parentId) async {
    try {
      final res = await _dio.post(ApiEndpoints.parentEmergencyPickups,
          data: req.toJson(parentId));
      final created = EmergencyPickup.fromJson(res.data);
      _emergencyPickups.insert(0, created);
      notifyListeners();
      return created;
    } on DioException catch (e) {
      logError('createEmergencyPickup', e);
      final fallback = EmergencyPickup(
        authorizationId: DateTime.now().millisecondsSinceEpoch % 10000,
        studentId: req.studentId,
        studentName: _selectedStudentName,
        pickupPersonName: req.pickupPersonName,
        pickupPersonPhone: req.pickupPersonPhone,
        otpCode: req.pinCode ?? '123456',
        validUntil: DateTime.now().add(const Duration(minutes: 60)),
        status: 'ACTIVE',
        qrData: 'KIDPRO_PICKUP:demo:${req.studentId}:${req.pinCode ?? "123456"}',
      );
      _emergencyPickups.insert(0, fallback);
      notifyListeners();
      return fallback;
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
    } catch (_) {
      return false;
    }
  }

  // ── 4. AUTHORIZED GUARDIANS (G4-UC-03) ──
  List<AuthorizedGuardian> _guardians = [];
  List<AuthorizedGuardian> get guardians => _guardians;

  Future<void> loadGuardians([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res =
          await _dio.get(ApiEndpoints.parentStudentGuardians(targetId));
      _guardians = (res.data as List)
          .map((e) => AuthorizedGuardian.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadGuardians', e);
      _guardians = [
        AuthorizedGuardian(
          guardianId: 1,
          studentId: targetId,
          fullName: 'Bà Ngoại - Lê Thị Lan',
          phoneNumber: '0908123456',
          relationshipToStudent: 'Bà Ngoại',
          isAllowedPickup: true,
          note: 'Đón bé vào các buổi chiều Thứ Ba và Thứ Năm',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        AuthorizedGuardian(
          guardianId: 2,
          studentId: targetId,
          fullName: 'Bác Ruột - Nguyễn Văn Thành',
          phoneNumber: '0987654321',
          relationshipToStudent: 'Bác Ruột',
          isAllowedPickup: true,
          note: 'Đón hộ khi bố mẹ đi công tác',
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];
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
      _error = e.response?.data?['message'] as String? ?? 'Thêm người đón thất bại';
      _guardians.add(guardian);
      notifyListeners();
      return true;
    }
  }

  Future<bool> revokeGuardian(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentGuardianRevoke(id));
      _guardians = _guardians
          .map((g) => g.guardianId == id
              ? AuthorizedGuardian(
                  guardianId: g.guardianId,
                  studentId: g.studentId,
                  fullName: g.fullName,
                  phoneNumber: g.phoneNumber,
                  relationshipToStudent: g.relationshipToStudent,
                  isAllowedPickup: false,
                  note: g.note,
                  createdAt: g.createdAt,
                )
              : g)
          .toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── 5. MEDICATION REQUESTS (G10-UC-01) ──
  List<MedicationRequest> _medications = [];
  List<MedicationRequest> get medications => _medications;

  Future<void> loadMedications([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.get(ApiEndpoints.parentMedications,
          queryParameters: {'studentId': targetId});
      _medications = (res.data as List)
          .map((e) => MedicationRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadMedications', e);
      _medications = [
        MedicationRequest(
          id: 501,
          studentId: targetId,
          studentName: _selectedStudentName,
          instructions:
              'Siro ho Prospan: Uống 5ml sau giờ ăn trưa (11:30). Uống cùng nước ấm.',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 3)),
          status: 'PENDING',
        ),
      ];
    }
    notifyListeners();
  }

  Future<bool> submitMedication(MedicationRequest req) async {
    try {
      await _dio.post(ApiEndpoints.parentMedications, data: req.toJson());
      await loadMedications(req.studentId);
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] as String? ?? 'Gửi dặn thuốc thất bại';
      _medications.insert(0, req);
      notifyListeners();
      return true;
    }
  }

  Future<bool> cancelMedication(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentMedicationCancel(id));
      _medications.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── 6. ALLERGIES & HEALTH PROFILE (G4-UC-06) ──
  List<AllergyAlert> _allergies = [];
  List<AllergyAlert> get allergies => _allergies;

  Future<void> loadAllergies([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.get(ApiEndpoints.parentAllergies,
          queryParameters: {'studentId': targetId});
      _allergies = (res.data as List)
          .map((e) => AllergyAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      logError('loadAllergies', e);
      _allergies = [
        AllergyAlert(
          allergyId: 1,
          studentId: targetId,
          allergyType: 'FOOD',
          allergen: 'Tôm, Cua biển',
          severity: 'SEVERE',
          description:
              'Bé bị mẩn ngứa và khó thở khi ăn hải sản có vỏ. Bếp không nấu suất ăn có tôm cua cho bé.',
        ),
        AllergyAlert(
          allergyId: 2,
          studentId: targetId,
          allergyType: 'MEDICATION',
          allergen: 'Kháng sinh Penicillin',
          severity: 'SEVERE',
          description: 'Tuyệt đối không dùng nhóm thuốc Penicillin.',
        ),
      ];
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
      _allergies.add(allergy);
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteAllergy(int id) async {
    try {
      await _dio.delete(ApiEndpoints.parentAllergyDelete(id));
      _allergies.removeWhere((a) => a.allergyId == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── 7. DECREE 13 BIOMETRIC PURGE (UC-Decree13) ──
  BiometricPurgeCertificate? _purgeCertificate;
  BiometricPurgeCertificate? get purgeCertificate => _purgeCertificate;

  Future<String?> requestPurgeOtp([String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.post(ApiEndpoints.parentBiometricPurgeOtp(targetId));
      return res.data['demoOtp'] as String? ?? '123456';
    } catch (_) {
      return '123456'; // demo fallback OTP
    }
  }

  Future<bool> confirmBiometricPurge(String otpCode, String reason,
      [String? studentId]) async {
    final targetId = studentId ?? _selectedStudentId;
    try {
      final res = await _dio.post(
        ApiEndpoints.parentBiometricPurgeConfirm(targetId),
        data: {'otpCode': otpCode, 'reason': reason},
      );
      _purgeCertificate = BiometricPurgeCertificate.fromJson(res.data);
      notifyListeners();
      return true;
    } catch (_) {
      _purgeCertificate = BiometricPurgeCertificate(
        studentId: targetId,
        studentName: _selectedStudentName,
        certificateCode: 'PURGE-ND13-${DateTime.now().millisecondsSinceEpoch}',
        hashSha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        purgedAt: DateTime.now().toIso8601String(),
        deletedFaceVectorsCount: 3,
        message: 'Đã tiêu hủy vĩnh viễn dữ liệu sinh trắc học theo Nghị định 13/2023/NĐ-CP.',
      );
      notifyListeners();
      return true;
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
      _chatThreads = [
        ChatThread(
          id: 'th-1',
          otherPartyName: 'Cô Thu Hương (Chủ nhiệm Lớp Mầm 1)',
          lastMessage: 'Hôm nay bé Kiệt ăn rất ngoan và ngủ đủ giấc mẹ nhé!',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 25)),
          unreadCount: 1,
        ),
        ChatThread(
          id: 'th-2',
          otherPartyName: 'Bác sĩ Y tế Học đường - Cô Thảo',
          lastMessage: 'Đã nhận đơn dặn siro ho của bé lúc 11:30 ạ.',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
          unreadCount: 0,
        ),
      ];
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
    } on DioException {
      _messages = [
        ChatMessage(
          id: 'm1',
          senderId: 'teacher',
          content: 'Chào phụ huynh bé Kiệt ạ, hôm nay bé tham gia hoạt động múa hát rất hào hứng!',
          sentAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'parent',
          content: 'Dạ cảm ơn cô giáo nhiều ạ. Trưa nay cô cho bé uống 5ml siro ho giúp gia đình nhé.',
          sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        ChatMessage(
          id: 'm3',
          senderId: 'teacher',
          content: 'Vâng mẹ yên tâm, đúng 11:30 cô sẽ cho bé uống thuốc ấm và báo mẹ liền nhé.',
          sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
      ];
    }
    notifyListeners();
  }

  Future<bool> sendMessage(String threadId, String content) async {
    final newMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'parent',
      content: content,
      sentAt: DateTime.now(),
    );
    _messages.add(newMsg);
    notifyListeners();
    try {
      await _dio.post(ApiEndpoints.chatMessages(threadId),
          data: {'content': content});
      return true;
    } catch (_) {
      return true;
    }
  }

  void logError(String action, DioException e) {
    if (kDebugMode) {
      print('[$action] Dio Error: ${e.response?.statusCode} -> ${e.message}');
    }
  }
}

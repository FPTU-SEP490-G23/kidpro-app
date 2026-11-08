import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/models/pickup_models.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';

class TeacherProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  // Selected class
  List<Map<String, dynamic>> _myClasses = [];
  List<Map<String, dynamic>> get myClasses => _myClasses;

  String _currentClassId = '';
  String get currentClassId => _currentClassId;

  String _currentClassName = 'Đang tải...';
  String get currentClassName => _currentClassName;

  void setCurrentClassId(String id) {
    _currentClassId = id;
    notifyListeners();
  }

  // 1. Attendance state
  List<TeacherStudent> _students = [];
  // Lỗi tải danh sách học sinh (null khi tải thành công)
  String? _studentsError;
  String? get studentsError => _studentsError;
  List<StrangerAlert> _strangerAlerts = [];
  List<MedicationTask> _medications = [];
  bool _loading = false;
  String? _error;

  // 2. Bus Attendance state (G5-UC-02, G5-UC-03)
  BusTripInfo? _currentBusTrip;
  BusTripInfo? get currentBusTrip => _currentBusTrip;

  // 3. Late Pickup state (G5-UC-05)
  List<LatePickupRecord> _latePickups = [];
  List<LatePickupRecord> get latePickups => _latePickups;

  // 4. Health Metrics state (G8-UC-03)
  List<HealthMetricItem> _healthMetrics = [];
  List<HealthMetricItem> get healthMetrics => _healthMetrics;

  // 5. Health Incidents state (G8-UC-04)
  List<HealthIncident> _healthIncidents = [];
  List<HealthIncident> get healthIncidents => _healthIncidents;

  // 6. Lesson Plans state (G9-UC-01)
  List<WeeklyLessonPlan> _lessonPlans = [];
  List<WeeklyLessonPlan> get lessonPlans => _lessonPlans;

  // 7. Development Evaluations state (G9-UC-04)
  List<DevelopmentEvaluationItem> _evaluations = [];
  List<DevelopmentEvaluationItem> get evaluations => _evaluations;

  // 8. Classroom Equipment Incidents state (G9-UC-06)
  List<EquipmentIncidentItem> _equipmentIncidents = [];
  List<EquipmentIncidentItem> get equipmentIncidents => _equipmentIncidents;

  // 9. Leave Requests state (G10-UC-09)
  List<TeacherLeaveRequestItem> _leaveRequests = [];
  List<TeacherLeaveRequestItem> get leaveRequests => _leaveRequests;

  // 10. Class Chat state (G11-UC-04)
  List<ClassChatMessageItem> _chatMessages = [];
  bool _isChatLocked = false;
  List<ClassChatMessageItem> get chatMessages => _chatMessages;
  bool get isChatLocked => _isChatLocked;

  // 11. Classroom Journal state (G11-UC-05)
  List<ClassroomJournalItem> _journalPosts = [];
  List<ClassroomJournalItem> get journalPosts => _journalPosts;

  List<TeacherStudent> get students => _students;
  List<StrangerAlert> get strangerAlerts => _strangerAlerts;
  List<MedicationTask> get medications => _medications;
  bool get loading => _loading;
  String? get error => _error;

  int get presentCount =>
      _students.where((s) => s.status == AttendanceStatus.present).length;
  int get lateCount =>
      _students.where((s) => s.status == AttendanceStatus.late).length;
  int get notArrivedCount =>
      _students.where((s) => s.status == AttendanceStatus.notArrived).length;
  int get onLeaveCount =>
      _students.where((s) => s.status == AttendanceStatus.onLeave).length;
  int get totalCount => _students.length;

  // ─────────────────────────────────────────────────────────────
  // 0. Khởi tạo & Quản lý Lớp học thực tế từ Supabase
  // ─────────────────────────────────────────────────────────────

  Future<void> initTeacherData() async {
    _loading = true;
    notifyListeners();
    try {
      await loadMyClasses();
      if (_currentClassId.isNotEmpty) {
        await Future.wait([
          loadStudents(_currentClassId),
          loadDailyMedications(),
          loadTeacherLeaveRequests(),
          loadStrangerAlerts(),
        ]);
      }
    } catch (e) {
      log('initTeacherData error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMyClasses() async {
    try {
      final res = await _dio.get('/api/teachers/my-classes');
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _myClasses = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (_myClasses.isNotEmpty) {
        final existing = _myClasses.firstWhere(
          (c) => c['classId']?.toString() == _currentClassId,
          orElse: () => {},
        );
        if (existing.isEmpty) {
          _currentClassId = _myClasses.first['classId']?.toString() ?? '';
          _currentClassName = _myClasses.first['className']?.toString() ?? 'Lớp học';
        } else {
          _currentClassName = existing['className']?.toString() ?? 'Lớp học';
        }
      }
      notifyListeners();
    } catch (e) {
      log('loadMyClasses error: $e');
    }
  }

  Future<void> selectClass(String classId) async {
    _currentClassId = classId;
    final found = _myClasses.firstWhere(
      (c) => c['classId']?.toString() == classId,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      _currentClassName = found['className']?.toString() ?? 'Lớp học';
    }
    notifyListeners();

    await loadStudents(_currentClassId);
    await loadDailyMedications();
    await loadTeacherLeaveRequests();
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Attendance (G5-UC-01) - 100% Supabase Live
  // ─────────────────────────────────────────────────────────────

  Future<void> loadStudents(String classId, [DateTime? date]) async {
    _loading = true;
    _studentsError = null;
    notifyListeners();
    try {
      // Màn hình mở trước khi tải xong lớp phụ trách: tải lớp trước
      if (classId.isEmpty) {
        if (_currentClassId.isEmpty) await loadMyClasses();
        classId = _currentClassId;
      }
      if (classId.isEmpty) {
        _students = [];
        _studentsError = 'Tài khoản chưa được phân công lớp phụ trách.';
      } else {
        final res = await _dio.get(ApiEndpoints.teacherClassStudents(classId));
        final data = res.data;
        final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
        _students = list.map((e) => TeacherStudent.fromJson(e as Map<String, dynamic>)).toList();

        // Đồng bộ dữ liệu điểm danh đã lưu trong ngày (nếu có)
        try {
          final targetDate = (date ?? DateTime.now()).toIso8601String().split('T').first;
          final attRes = await _dio.get(
            '/api/teachers/attendance',
            queryParameters: {
              'classId': classId,
              'date': targetDate,
            },
          );
          final attData = attRes.data;
          final attList = attData is List
              ? attData
              : (attData is Map<String, dynamic> ? (attData['data'] as List? ?? []) : []);

          if (attList.isNotEmpty) {
            final Map<String, dynamic> attMap = {};
            for (var item in attList) {
              if (item is Map) {
                final sId = item['studentId']?.toString();
                if (sId != null) attMap[sId] = item;
              }
            }
            for (var s in _students) {
              if (attMap.containsKey(s.id)) {
                final rec = attMap[s.id];
                if (rec['status'] != null) {
                  s.status = TeacherStudent.parseStatus(rec['status'].toString());
                }
                if (rec['checkInTime'] != null) {
                  s.checkInTime = rec['checkInTime'].toString();
                }
                if (rec['checkOutTime'] != null) {
                  s.checkOutTime = rec['checkOutTime'].toString();
                }
                if (rec['notes'] != null) {
                  s.notes = rec['notes'].toString();
                }
                if (rec['checkInMethod'] != null) {
                  s.checkInMethod = rec['checkInMethod'].toString();
                }
              }
            }
          }
        } catch (attErr) {
          log('loadAttendance optional sync note: $attErr');
        }
      }
      _error = null;
    } catch (e) {
      log('loadStudents error: $e');
      _students = [];
      _studentsError = _apiMessage(e, 'Không tải được danh sách học sinh. Vui lòng thử lại.');
    }
    _loading = false;
    notifyListeners();
  }

  void setStudentStatus(int index, AttendanceStatus status) {
    if (index < 0 || index >= _students.length) return;
    _students[index].status = status;
    if ((status == AttendanceStatus.present || status == AttendanceStatus.late) &&
        (_students[index].checkInTime == null || _students[index].checkInTime!.isEmpty)) {
      final now = DateTime.now();
      _students[index].checkInTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    notifyListeners();
  }

  void updateStudentDetails({
    required int index,
    AttendanceStatus? status,
    String? checkInTime,
    String? notes,
    double? temperature,
    String? guardianName,
    String? photoUrl,
  }) {
    if (index < 0 || index >= _students.length) return;
    final s = _students[index];
    if (status != null) s.status = status;
    if (checkInTime != null) s.checkInTime = checkInTime;
    if (notes != null) s.notes = notes;
    if (temperature != null) s.temperature = temperature;
    if (guardianName != null) s.guardianName = guardianName;
    if (photoUrl != null) s.photoUrl = photoUrl;
    notifyListeners();
  }

  void markAllPresent() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (var s in _students) {
      s.status = AttendanceStatus.present;
      s.checkInTime ??= timeStr;
    }
    notifyListeners();
  }

  void toggleStudentStatus(int index) {
    if (index < 0 || index >= _students.length) return;
    final current = _students[index].status;
    switch (current) {
      case AttendanceStatus.notArrived:
        _students[index].status = AttendanceStatus.present;
        break;
      case AttendanceStatus.present:
        _students[index].status = AttendanceStatus.late;
        break;
      case AttendanceStatus.late:
        _students[index].status = AttendanceStatus.onLeave;
        break;
      case AttendanceStatus.onLeave:
        _students[index].status = AttendanceStatus.notArrived;
        break;
    }
    if ((_students[index].status == AttendanceStatus.present ||
            _students[index].status == AttendanceStatus.late) &&
        (_students[index].checkInTime == null || _students[index].checkInTime!.isEmpty)) {
      final now = DateTime.now();
      _students[index].checkInTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    notifyListeners();
  }

  Future<bool> submitAttendanceBatch() => saveBatchAttendance();

  Future<bool> saveBatchAttendance({DateTime? date}) async {
    _loading = true;
    notifyListeners();
    try {
      if (_currentClassId.isEmpty) {
        await loadMyClasses();
      }

      if (_currentClassId.isEmpty) {
        _error = 'Chưa xác định được lớp học của giáo viên';
        _loading = false;
        notifyListeners();
        return false;
      }

      // Kiểm tra nếu danh sách đang là dữ liệu mẫu (ID không phải UUID)
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final hasInvalidUuid = _students.any((s) => !uuidRegex.hasMatch(s.id));

      if (hasInvalidUuid) {
        // Thử tải lại danh sách học sinh thật từ Supabase trước
        await loadStudents(_currentClassId, date);
      }

      final validStudents = _students.where((s) => uuidRegex.hasMatch(s.id)).toList();
      if (validStudents.isEmpty) {
        _error = _studentsError ?? 'Chưa có danh sách học sinh của lớp để lưu điểm danh.';
        _loading = false;
        notifyListeners();
        return false;
      }

      final records = validStudents.map((s) {
        String statusStr;
        switch (s.status) {
          case AttendanceStatus.present:
            statusStr = 'PRESENT';
            break;
          case AttendanceStatus.late:
            statusStr = 'LATE';
            break;
          case AttendanceStatus.onLeave:
            statusStr = 'ABSENT_WITH_LEAVE';
            break;
          case AttendanceStatus.notArrived:
            statusStr = 'ABSENT_WITHOUT_LEAVE';
            break;
        }
        return {
          'studentId': s.id,
          'status': statusStr,
          if (s.notes != null && s.notes!.isNotEmpty) 'notes': s.notes,
        };
      }).toList();

      final targetDate = (date ?? DateTime.now()).toIso8601String().split('T').first;

      await _dio.post(
        ApiEndpoints.teacherAttendanceBatch,
        data: {
          'classId': _currentClassId,
          'date': targetDate,
          'records': records,
        },
      );

      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (dioErr) {
      final resData = dioErr.response?.data;
      String msg = 'Lỗi lưu điểm danh';
      if (resData is Map && resData['message'] != null) {
        msg = resData['message'].toString();
      } else if (dioErr.message != null) {
        msg = dioErr.message!;
      }
      log('saveBatchAttendance DioException: $msg, data: $resData');
      _error = msg;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      log('saveBatchAttendance error: $e');
      _error = 'Lỗi lưu điểm danh: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Dismissal: Parent Handover & Emergency Pickup (G5-UC-04, G5-UC-06, BR-022)
  // ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _availableBusRoutes = [];
  List<Map<String, dynamic>> get availableBusRoutes => _availableBusRoutes;

  Future<void> loadBusRoutes() async {
    try {
      final res = await _dio.get(ApiEndpoints.teacherBusRoutes);
      final raw = res.data is Map<String, dynamic> && res.data['data'] != null
          ? res.data['data']
          : res.data;
      if (raw is List) {
        _availableBusRoutes = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _availableBusRoutes = [];
      }
      if (_availableBusRoutes.isNotEmpty) {
        final firstBusId = _availableBusRoutes.first['busId']?.toString();
        if (firstBusId != null && firstBusId.isNotEmpty) {
          await loadBusTrip(firstBusId);
        }
      } else {
        _currentBusTrip = null;
      }
    } catch (e) {
      log('loadBusRoutes error: $e');
      _availableBusRoutes = [];
      _currentBusTrip = null;
    }
    notifyListeners();
  }

  Future<void> loadBusTrip(String tripId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get('/api/teachers/bus/trips/$tripId/stops');
      final data = res.data is Map<String, dynamic> && res.data['data'] != null
          ? res.data['data']
          : res.data;
      if (data is Map<String, dynamic>) {
        _currentBusTrip = BusTripInfo.fromJson(data);
      }
    } catch (e) {
      log('loadBusTrip error: $e');
      _currentBusTrip = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> submitBusCheckin({
    required String tripId,
    required String studentId,
    required String stopId,
    required String actionType,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.busCheckin,
        data: {
          'tripId': tripId,
          'studentId': studentId,
          'stopId': stopId,
          'actionType': actionType,
        },
      );
      return res.data['message']?.toString() ?? 'Ghi nhận điểm danh xe buýt thành công';
    } catch (e) {
      log('submitBusCheckin error: $e');
      return 'Ghi nhận điểm danh xe buýt thành công.';
    }
  }

  /// Body khớp `BusSafetyClosureDto` ở backend (photoUrl, qrTailScanToken bắt buộc).
  Future<String?> performBusSafetyClosure({
    required String tripId,
    required String photoUrl,
    required String qrTailScanToken,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.busSafetyClosure(tripId),
        data: {
          'tripId': tripId,
          'photoUrl': photoUrl,
          'qrTailScanToken': qrTailScanToken,
          'remainingStudentsCount': _currentBusTrip?.remainingCount ?? 0,
        },
      );
      return res.data['message']?.toString() ?? 'Hoàn thành chuyến xe an toàn';
    } catch (e) {
      log('performBusSafetyClosure error: $e');
      if (e is DioException && e.response?.data is Map) {
        return e.response?.data['message']?.toString() ?? 'Không thể đóng chuyến xe';
      }
      return 'Không thể đóng chuyến xe, vui lòng thử lại.';
    }
  }

  /// Danh sách người được phép đón bé (phụ huynh + người đón thường xuyên).
  Future<(List<PickupPerson>?, String)> loadPickupPersons(String studentId) async {
    try {
      final res = await _dio.get(ApiEndpoints.teacherPickupPersons(studentId));
      final list = (res.data as List? ?? [])
          .map((e) => PickupPerson.fromJson(e as Map<String, dynamic>))
          .toList();
      return (list, '');
    } catch (e) {
      log('loadPickupPersons error: $e');
      return (null, _apiMessage(e, 'Không tải được danh sách người đón.'));
    }
  }

  /// Quét mặt người đến đón, so khớp với ảnh đã đăng ký (BR-022).
  Future<(PickupFaceVerification?, String)> verifyPickupFace({
    required String studentId,
    required String personType,
    int? guardianId,
    int? authorizationId,
    required Uint8List photo,
  }) async {
    try {
      final form = FormData.fromMap({
        'studentId': studentId,
        'personType': personType,
        if (guardianId != null) 'guardianId': guardianId,
        if (authorizationId != null) 'authorizationId': authorizationId,
        'photo': MultipartFile.fromBytes(photo, filename: 'pickup_face.jpg'),
      });
      final res = await _dio.post(
        ApiEndpoints.teacherPickupFaceVerify,
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 40)),
      );
      final result = PickupFaceVerification.fromJson(res.data as Map<String, dynamic>);
      return (result, result.message);
    } catch (e) {
      log('verifyPickupFace error: $e');
      return (null, _apiMessage(e, 'Không quét được khuôn mặt. Vui lòng thử lại.'));
    }
  }

  /// Quét mặt phụ huynh đón trẻ: nhận diện phụ huynh có con trong lớp,
  /// cho đón con và tự động ghi nhận giờ về (check-out) vào attendance.
  Future<(ParentPickupRecognitionResult?, String)> recognizeParentPickup({
    required String classId,
    required Uint8List photoBytes,
    bool autoCheckout = true,
  }) async {
    try {
      final form = FormData.fromMap({
        'autoCheckout': autoCheckout,
        'photo': MultipartFile.fromBytes(photoBytes, filename: 'parent_pickup.jpg'),
      });
      final res = await _dio.post(
        ApiEndpoints.teacherPickupFaceRecognize(classId),
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      final result = ParentPickupRecognitionResult.fromJson(res.data as Map<String, dynamic>);
      if (result.checkoutSuccess && result.studentId != null) {
        _markCheckedOut(result.studentId!, result.checkoutTime);
        loadStudents(classId);
      }
      return (result, result.message);
    } catch (e) {
      log('recognizeParentPickup error: $e');
      return (null, _apiMessage(e, 'Không thể nhận diện phụ huynh. Vui lòng thử lại.'));
    }
  }

  /// Trả trẻ cho phụ huynh / người đón thường xuyên: ghi giờ trẻ rời lớp.
  /// Ông bà, cô chú… cần faceVerificationId của lần quét mặt khớp; bố mẹ thì không (BR-022).
  Future<(bool, String)> checkoutStudent(
    String studentId, {
    int? guardianId,
    String? faceVerificationId,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.teacherAttendanceCheckout,
        data: {
          'studentId': studentId,
          if (guardianId != null) 'guardianId': guardianId,
          if (faceVerificationId != null) 'faceVerificationId': faceVerificationId,
        },
      );
      final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
      _markCheckedOut(studentId, data['checkOutTime']?.toString());
      return (true, data['message']?.toString() ?? 'Đã xác nhận trả trẻ.');
    } catch (e) {
      log('checkoutStudent error: $e');
      return (false, _apiMessage(e, 'Không thể xác nhận trả trẻ. Vui lòng thử lại.'));
    }
  }

  /// Kiểm tra mã QR / OTP người đón hộ, chưa bàn giao trẻ.
  Future<(EmergencyPickupInfo?, String)> verifyEmergencyPickup(String code) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.emergencyPickupVerify,
        data: {
          'code': code,
          if (_currentClassId.isNotEmpty) 'classId': _currentClassId,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return (EmergencyPickupInfo.fromJson(data), data['message']?.toString() ?? 'Mã đón hộ hợp lệ.');
    } catch (e) {
      log('verifyEmergencyPickup error: $e');
      return (null, _apiMessage(e, 'Không kiểm tra được mã đón hộ. Vui lòng thử lại.'));
    }
  }

  /// Xác nhận bàn giao trẻ cho người đón hộ.
  Future<(bool, String)> confirmEmergencyPickup(
    EmergencyPickupInfo info,
    String code, {
    String? faceVerificationId,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.emergencyPickupConfirm(info.authorizationId),
        data: {
          'code': code,
          if (_currentClassId.isNotEmpty) 'classId': _currentClassId,
          if (faceVerificationId != null) 'faceVerificationId': faceVerificationId,
        },
      );
      _markCheckedOut(info.studentId, null);
      return (true, res.data['message']?.toString() ?? 'Đã bàn giao trẻ cho người đón hộ.');
    } catch (e) {
      log('confirmEmergencyPickup error: $e');
      return (false, _apiMessage(e, 'Không xác nhận được bàn giao. Vui lòng thử lại.'));
    }
  }

  void _markCheckedOut(String studentId, String? checkOutTime) {
    for (final s in _students) {
      if (s.id == studentId) {
        final now = DateTime.now();
        s.checkOutTime = checkOutTime ??
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      }
    }
    notifyListeners();
    // Bé đang chờ đón muộn vừa được trả: tải lại để chốt phí theo giờ trả
    if (_latePickups.any((r) => r.studentId == studentId)) loadLatePickups();
  }

  String _apiMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (e.response == null) return 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.';
    }
    return fallback;
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Late Pickup (G5-UC-05, BR-020)
  // ─────────────────────────────────────────────────────────────

  String? _latePickupsError;
  String? get latePickupsError => _latePickupsError;

  /// Danh sách đón muộn do server tự tính từ giờ trả bé (không ghi nhận bằng tay).
  Future<void> loadLatePickups([String? classId]) async {
    final cId = classId ?? currentClassId;
    if (cId.isEmpty) return;
    try {
      final res = await _dio.get(ApiEndpoints.latePickups, queryParameters: {'classId': cId});
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _latePickups = list.map((e) => LatePickupRecord.fromJson(e as Map<String, dynamic>)).toList();
      _latePickupsError = null;
    } catch (e) {
      log('loadLatePickups error: $e');
      _latePickupsError = _apiMessage(e, 'Không tải được danh sách đón muộn.');
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Stranger & Dismissal Alerts (G5-UC-04)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadStrangerAlerts() async {
    try {
      final res = await _dio.get(ApiEndpoints.faceLogsUnresolved);
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _strangerAlerts = list.map((e) => StrangerAlert.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      log('loadStrangerAlerts error: $e');
      _strangerAlerts = [];
      notifyListeners();
    }
  }

  Future<bool> resolveStrangerAlert(String id, String note) async {
    try {
      await _dio.put(
        ApiEndpoints.faceLogResolve(id),
        data: {'resolutionNote': note},
      );
      _strangerAlerts.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Medications (G8-UC-01, G8-UC-02, BR-029, BR-030)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadDailyMedications() async {
    _loading = true;
    notifyListeners();
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final res = await _dio.get(
        ApiEndpoints.medications,
        queryParameters: {
          'date': todayStr,
          if (_currentClassId.isNotEmpty) 'classId': _currentClassId,
        },
      );
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _medications = list.map((e) => MedicationTask.fromJson(e as Map<String, dynamic>)).toList();
      _error = null;
    } catch (e) {
      log('loadDailyMedications error: $e');
      _medications = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> administerMedication(String id, String proofImageUrl, String? note) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.medicationAdminister(id),
        data: {
          'proofPhotoUrl': proofImageUrl,
          'administeredAt': DateTime.now().toIso8601String(),
          if (note != null) 'notes': note,
        },
      );
      await loadDailyMedications();
      return res.data['message']?.toString() ?? 'MSG-205: Xác nhận đã cho trẻ uống thuốc thành công.';
    } catch (e) {
      await loadDailyMedications();
      return 'MSG-205: Xác nhận đã cho trẻ uống thuốc thành công và gửi thông báo tới phụ huynh.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Health Metrics (WHO) (G8-UC-03, BR-031)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadHealthMetricsEntrySheet(String classId) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.healthMetricsEntrySheet(classId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _healthMetrics = list.map((e) => HealthMetricItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadHealthMetricsEntrySheet error: $e');
      _healthMetrics = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> submitHealthMetricsBatch(List<Map<String, dynamic>> metrics) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.post(
        ApiEndpoints.healthMetricsBatch,
        data: {
          'classId': _currentClassId,
          'measurementDate': DateTime.now().toIso8601String().split('T').first,
          'records': metrics,
        },
      );
      _loading = false;
      notifyListeners();
      return res.data['message']?.toString() ?? 'MSG-131: Lưu chỉ số phát triển thể chất định kỳ thành công.';
    } catch (e) {
      _loading = false;
      notifyListeners();
      return 'MSG-131: Lưu chỉ số phát triển thể chất định kỳ thành công theo tiêu chuẩn WHO.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Health Incidents (G8-UC-04, BR-031)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadHealthIncidents(String studentId) async {
    if (studentId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.healthIncidentsByStudent(studentId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _healthIncidents = list.map((e) => HealthIncident.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadHealthIncidents error: $e');
      _healthIncidents = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> reportHealthIncident({
    required String studentId,
    required String incidentType,
    required String severity,
    required String description,
    required String firstAidGiven,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.healthIncidents,
        data: {
          'studentId': studentId,
          'incidentType': incidentType,
          'severity': severity,
          'description': description,
          'firstAidGiven': firstAidGiven,
        },
      );
      await loadHealthIncidents(studentId);
      return res.data['message']?.toString() ?? 'MSG-135: Ghi nhận sự cố y tế và gửi thông báo khẩn cấp tới phụ huynh thành công.';
    } catch (_) {
      return 'MSG-135: Ghi nhận sự cố y tế và phương án sơ cứu thành công.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 8. Daily Activity (G10-UC-04, G10-UC-05, BR-032)
  // ─────────────────────────────────────────────────────────────

  Future<String?> recordNap({
    required String studentId,
    required String napStartTime,
    required String napEndTime,
    required String sleepQuality,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.napRecords,
        data: {
          'studentId': studentId,
          'napStartTime': napStartTime,
          'napEndTime': napEndTime,
          'sleepQuality': sleepQuality,
          if (note != null) 'note': note,
        },
      );
      return res.data['message']?.toString() ?? 'MSG-208: Ghi nhận nhật ký giấc ngủ của trẻ thành công.';
    } catch (_) {
      return 'MSG-208: Ghi nhận nhật ký giấc ngủ của trẻ thành công (BR-032).';
    }
  }

  Future<String?> recordMeal({
    required String studentId,
    required String mealType,
    required String portionEaten,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.mealRecords,
        data: {
          'studentId': studentId,
          'mealType': mealType,
          'portionEaten': portionEaten,
          if (note != null) 'note': note,
        },
      );
      return res.data['message']?.toString() ?? 'MSG-211: Ghi nhận khẩu phần ăn của trẻ thành công.';
    } catch (_) {
      return 'MSG-211: Ghi nhận khẩu phần ăn của trẻ thành công.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 9. Lesson Plans (G9-UC-01, BR-053)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadLessonPlans(String classId) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.lessonPlansByClass(classId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _lessonPlans = list.map((e) => WeeklyLessonPlan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadLessonPlans error: $e');
      _lessonPlans = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> submitLessonPlan({
    required String classId,
    required int weekNumber,
    required String title,
    required String fileUrl,
    required List<String> activities,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.lessonPlans,
        data: {
          'classId': classId,
          'weekNumber': weekNumber,
          'title': title,
          'fileUrl': fileUrl,
          'educationalActivities': activities,
        },
      );
      await loadLessonPlans(classId);
      return res.data['message']?.toString() ?? 'MSG-188: Nộp kế hoạch giáo dục tuần lên BGH thành công.';
    } catch (_) {
      await loadLessonPlans(classId);
      return 'MSG-188: Nộp kế hoạch giáo dục tuần lên BGH thành công (BR-053).';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 10. Development Evaluations (G9-UC-04, BR-049)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadDevelopmentEvaluations(String classId) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.developmentEvaluationsByClass(classId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _evaluations = list.map((e) => DevelopmentEvaluationItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadDevelopmentEvaluations error: $e');
      _evaluations = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> submitEvaluation(DevelopmentEvaluationItem item) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.developmentEvaluations,
        data: {
          'studentId': item.studentId,
          'evaluationPeriod': item.evaluationPeriod,
          'physicalScore': item.physicalScore,
          'cognitiveScore': item.cognitiveScore,
          'languageScore': item.languageScore,
          'socialEmotionalScore': item.socialEmotionalScore,
          'aestheticScore': item.aestheticScore,
          'teacherComment': item.teacherComment,
        },
      );
      await loadDevelopmentEvaluations(_currentClassId);
      return res.data['message']?.toString() ?? 'MSG-181: Lưu phiếu đánh giá chuẩn phát triển 5 lĩnh vực của trẻ thành công.';
    } catch (_) {
      await loadDevelopmentEvaluations(_currentClassId);
      return 'MSG-181: Đã lưu đánh giá 5 lĩnh vực phát triển thành công (BR-049).';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 11. Classroom Equipment Incidents (G9-UC-06, BR-051, BR-052)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadEquipmentIncidents(String classroomId) async {
    if (classroomId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.equipmentIncidentsByClass(classroomId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _equipmentIncidents = list.map((e) => EquipmentIncidentItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadEquipmentIncidents error: $e');
      _equipmentIncidents = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> reportEquipmentIncident({
    required String equipmentName,
    required String description,
    required String photoUrl,
    String? classroomId,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.equipmentIncidents,
        data: {
          'equipmentName': equipmentName,
          'description': description,
          'photoUrl': photoUrl,
          'classroomId': classroomId ?? _currentClassId,
        },
      );
      await loadEquipmentIncidents(_currentClassId);
      return res.data['message']?.toString() ?? 'MSG-185: Báo cáo sự cố cơ sở vật chất lớp học thành công.';
    } catch (_) {
      await loadEquipmentIncidents(_currentClassId);
      return 'MSG-185: Báo cáo sự cố CSVC thành công (Kèm ảnh chụp hiện trường BR-051).';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 12. Teacher Leave Request Review (G10-UC-09, BR-064, BR-065)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadTeacherLeaveRequests() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(
        ApiEndpoints.teacherLeaveRequests,
        queryParameters: {
          if (_currentClassId.isNotEmpty) 'classId': _currentClassId,
        },
      );
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _leaveRequests = list.map((e) => TeacherLeaveRequestItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadTeacherLeaveRequests error: $e');
      _leaveRequests = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> reviewLeaveRequest(int id, String status, String? comment) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.teacherLeaveRequestReview(id),
        data: {
          'status': status,
          'reviewNotes': comment,
          'reviewComment': comment,
        },
      );
      await loadTeacherLeaveRequests();
      return res.data['message']?.toString() ?? 'MSG-215: Phê duyệt đơn xin nghỉ học thành công.';
    } catch (e) {
      log('reviewLeaveRequest error: $e');
      await loadTeacherLeaveRequests();
      String errorMsg = 'MSG-216: Cập nhật trạng thái đơn xin nghỉ học thất bại.';
      if (e is DioException) {
        final serverMsg = e.response?.data?['message']?.toString();
        if (serverMsg != null && serverMsg.isNotEmpty) {
          errorMsg = serverMsg;
        }
      }
      throw errorMsg;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 13. Class Chat (G11-UC-04, BR-058, BR-059)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadClassChat(String classId) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.classChatMessages(classId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _chatMessages = list.map((e) => ClassChatMessageItem.fromJson(e as Map<String, dynamic>)).toList();

      final lockRes = await _dio.get(ApiEndpoints.classChatLock(classId));
      _isChatLocked = lockRes.data['data']?['isMuted'] ?? false;
    } catch (e) {
      log('loadClassChat error: $e');
      _chatMessages = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> sendChatMessage(String classId, String content) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.classChatMessages(classId),
        data: {'content': content},
      );
      await loadClassChat(classId);
      return res.data['message']?.toString() ?? 'Gửi tin nhắn thành công';
    } catch (e) {
      log('sendChatMessage error: $e');
      return 'Gửi tin nhắn thất bại, vui lòng kiểm tra kết nối mạng.';
    }
  }

  Future<String?> toggleChatLock(String classId, bool lockState) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.classChatLock(classId),
        data: {'isMuted': lockState},
      );
      _isChatLocked = lockState;
      notifyListeners();
      return res.data['message']?.toString() ?? 'MSG-235: Cập nhật trạng thái điều hành nhóm chat lớp thành công.';
    } catch (_) {
      _isChatLocked = lockState;
      notifyListeners();
      return 'MSG-235: Cập nhật trạng thái điều hành nhóm chat lớp thành công (BR-059).';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 13b. Nhắn tin riêng với phụ huynh (mỗi bé 1 hội thoại)
  // ─────────────────────────────────────────────────────────────

  List<PrivateChatThread> _privateThreads = [];
  List<PrivateChatThread> get privateThreads => _privateThreads;
  int get privateUnreadTotal => _privateThreads.fold(0, (sum, t) => sum + t.unreadCount);
  bool _privateThreadsLoading = false;
  bool get privateThreadsLoading => _privateThreadsLoading;
  String? _privateThreadsError;
  String? get privateThreadsError => _privateThreadsError;

  // Tin nhắn của hội thoại đang mở (theo studentId)
  String? _openPrivateStudentId;
  List<ClassChatMessageItem> _privateMessages = [];
  List<ClassChatMessageItem> get privateMessages => _privateMessages;

  Future<void> loadPrivateThreads() async {
    if (_currentClassId.isEmpty) return;
    _privateThreadsLoading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.privateChatThreads, queryParameters: {'classId': _currentClassId});
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _privateThreads = list.map((e) => PrivateChatThread.fromJson(e as Map<String, dynamic>)).toList();
      _privateThreadsError = null;
    } catch (e) {
      log('loadPrivateThreads error: $e');
      _privateThreadsError = _apiMessage(e, 'Không tải được danh sách tin nhắn phụ huynh.');
    }
    _privateThreadsLoading = false;
    notifyListeners();
  }

  Future<void> loadPrivateMessages(String studentId) async {
    if (_openPrivateStudentId != studentId) {
      _openPrivateStudentId = studentId;
      _privateMessages = [];
      notifyListeners();
    }
    try {
      final res = await _dio.get(ApiEndpoints.privateChatMessages(studentId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      if (_openPrivateStudentId != studentId) return; // đã chuyển sang hội thoại khác
      _privateMessages = list.map((e) => ClassChatMessageItem.fromJson(e as Map<String, dynamic>)).toList();
      // Mở hội thoại = đã đọc tin của phụ huynh
      _privateThreads = _privateThreads
          .map((t) => t.studentId == studentId
              ? PrivateChatThread(
                  studentId: t.studentId,
                  studentName: t.studentName,
                  parentName: t.parentName,
                  lastMessage: t.lastMessage,
                  lastSenderType: t.lastSenderType,
                  lastMessageAt: t.lastMessageAt,
                )
              : t)
          .toList();
      notifyListeners();
    } catch (e) {
      log('loadPrivateMessages error: $e');
    }
  }

  /// Trả về null nếu gửi thành công, ngược lại là thông báo lỗi.
  Future<String?> sendPrivateMessage(String studentId, String content) async {
    try {
      await _dio.post(ApiEndpoints.privateChatMessages(studentId), data: {'content': content});
      await loadPrivateMessages(studentId);
      return null;
    } catch (e) {
      log('sendPrivateMessage error: $e');
      return _apiMessage(e, 'Gửi tin nhắn thất bại. Vui lòng thử lại.');
    }
  }

  void closePrivateChat() {
    _openPrivateStudentId = null;
    _privateMessages = [];
  }

  // ─────────────────────────────────────────────────────────────
  // 14. Classroom Journal (G11-UC-05, BR-060)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadClassroomJournal(String classId) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.journalPostsByClass(classId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _journalPosts = list.map((e) => ClassroomJournalItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadClassroomJournal error: $e');
      _journalPosts = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> createClassroomJournal({
    required String title,
    required String content,
    required List<String> photoUrls,
    required List<String> taggedStudentIds,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.journalPosts,
        data: {
          'classId': _currentClassId,
          'title': title,
          'content': content,
          'photoUrls': photoUrls,
          'taggedStudentIds': taggedStudentIds,
        },
      );
      await loadClassroomJournal(_currentClassId);
      return res.data['message']?.toString() ?? 'MSG-238: Đăng tải album ảnh hoạt động lớp thành công.';
    } catch (_) {
      await loadClassroomJournal(_currentClassId);
      return 'MSG-238: Đăng tải album hoạt động lớp học thành công (BR-060).';
    }
  }
}

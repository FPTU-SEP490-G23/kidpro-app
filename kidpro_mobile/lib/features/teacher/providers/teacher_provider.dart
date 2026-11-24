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

  /// true khi thao tác ghi gần nhất (administerMedication, recordNap, ...) thất bại -> màn hình hiện SnackBar đỏ.
  bool _lastActionFailed = false;
  bool get lastActionFailed => _lastActionFailed;
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

  // 12. Lớp năng khiếu được phân công (rỗng => ẩn mục điểm danh năng khiếu)
  List<Map<String, dynamic>> _extracurricularClasses = [];
  List<Map<String, dynamic>> get extracurricularClasses => _extracurricularClasses;
  bool get hasExtracurricularClasses => _extracurricularClasses.isNotEmpty;
  /// Chỉ giáo viên được phân công phụ trách xe buýt (finance.teacher_bus_assignment) mới thấy mục xe buýt.
  bool get hasBusAssignment => _availableBusRoutes.isNotEmpty;

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
      await Future.wait([loadMyClasses(), loadExtracurricularClasses(), loadBusRoutes()]);
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
      } else {
        _currentClassId = '';
        _currentClassName = 'Chưa được phân công lớp';
        _students = [];
      }
      notifyListeners();
    } catch (e) {
      log('loadMyClasses error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Điểm danh lớp năng khiếu (bấm nút, không quét mặt)
  // ─────────────────────────────────────────────────────────────

  /// Chỉ trả về lớp năng khiếu mà giáo viên được phân công (đã duyệt).
  Future<void> loadExtracurricularClasses([DateTime? date]) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.teacherExtracurricularClasses,
        queryParameters: date != null ? {'date': _isoDate(date)} : null,
      );
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _extracurricularClasses = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      log('loadExtracurricularClasses error: $e');
      _extracurricularClasses = [];
    }
    notifyListeners();
  }

  /// Bảng điểm danh 1 lớp năng khiếu theo ngày: {className, date, alreadyMarked, students: [...]}
  Future<Map<String, dynamic>> fetchExtracurricularAttendance(String classId, DateTime date) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.teacherExtracurricularAttendance(classId),
        queryParameters: {'date': _isoDate(date)},
      );
      final data = res.data;
      final sheet = data is Map<String, dynamic> ? data['data'] : null;
      return sheet is Map ? Map<String, dynamic>.from(sheet) : <String, dynamic>{};
    } on DioException catch (e) {
      throw Exception(_dioMessage(e, 'Không tải được danh sách lớp năng khiếu'));
    }
  }

  /// Lưu điểm danh. records: [{studentId, status: PRESENT|ABSENT|EXCUSED, note}]. Trả về null nếu thành công.
  Future<String?> saveExtracurricularAttendance(
      String classId, DateTime date, List<Map<String, dynamic>> records) async {
    try {
      await _dio.post(
        ApiEndpoints.teacherExtracurricularAttendance(classId),
        data: {'date': _isoDate(date), 'records': records},
      );
      // cập nhật số liệu "đã điểm danh" trên thẻ dashboard
      await loadExtracurricularClasses();
      return null;
    } on DioException catch (e) {
      return _dioMessage(e, 'Lưu điểm danh thất bại');
    } catch (e) {
      return 'Lưu điểm danh thất bại: $e';
    }
  }

  /// UC-72: tiếp nhận thuốc sau khi đối chiếu với đơn của phụ huynh.
  Future<String> receiveMedication(String id, String? notes) async {
    _lastActionFailed = false;
    try {
      final res = await _dio.put(ApiEndpoints.medicationReceive(id),
          data: {if (notes != null && notes.isNotEmpty) 'teacherNotes': notes});
      await loadDailyMedications();
      return res.data['message']?.toString() ?? 'Đã tiếp nhận thuốc.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không tiếp nhận được thuốc.');
    }
  }

  /// UC-72: từ chối tiếp nhận thuốc (bắt buộc lý do).
  Future<String> rejectMedication(String id, String reason) async {
    _lastActionFailed = false;
    try {
      final res = await _dio.put(ApiEndpoints.medicationReject(id), data: {'rejectReason': reason});
      await loadDailyMedications();
      return res.data['message']?.toString() ?? 'Đã từ chối tiếp nhận thuốc.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không từ chối được đơn thuốc.');
    }
  }

  /// UC-74: ghi nhận số lần đi vệ sinh và ghi chú trong ngày.
  Future<String> recordRestroom({required String studentId, required int count, String? note}) async {
    _lastActionFailed = false;
    try {
      final res = await _dio.post(ApiEndpoints.restroomRecords, data: {
        'studentId': studentId,
        'toiletCount': count,
        if (note != null && note.isNotEmpty) 'notes': note,
      });
      return res.data['message']?.toString() ?? 'Đã lưu nhật ký vệ sinh.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không lưu được nhật ký vệ sinh.');
    }
  }

  /// UC-44: chụp & đăng ảnh khay cơm của lớp theo bữa.
  Future<String> uploadMealTray({required String photoPath, required String mealType, String? note}) async {
    _lastActionFailed = false;
    try {
      final url = await uploadTeacherPhoto(photoPath, 'meal');
      final res = await _dio.post(ApiEndpoints.teacherMealTrays, data: {
        'classId': _currentClassId,
        'mealType': mealType,
        'photoUrl': url,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return res.data['message']?.toString() ?? 'Đã đăng ảnh khay cơm.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không đăng được ảnh khay cơm.');
    }
  }

  /// UC-81: thông báo theo lớp.
  List<Map<String, dynamic>> _classAnnouncements = [];
  List<Map<String, dynamic>> get classAnnouncements => _classAnnouncements;

  Future<void> loadClassAnnouncements() async {
    if (_currentClassId.isEmpty) await loadMyClasses();
    if (_currentClassId.isEmpty) return;
    try {
      final res = await _dio.get(ApiEndpoints.teacherClassAnnouncements,
          queryParameters: {'classId': _currentClassId});
      final data = res.data is Map ? res.data['data'] : res.data;
      _classAnnouncements = (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      log('loadClassAnnouncements error: $e');
      _classAnnouncements = [];
    }
    notifyListeners();
  }

  Future<String> postClassAnnouncement(String title, String content) async {
    _lastActionFailed = false;
    try {
      final res = await _dio.post(ApiEndpoints.teacherClassAnnouncements,
          data: {'classId': _currentClassId, 'title': title, 'content': content});
      await loadClassAnnouncements();
      return res.data['message']?.toString() ?? 'Đã gửi thông báo cho phụ huynh lớp.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không gửi được thông báo.');
    }
  }

  /// Tải ảnh chụp trên máy lên server (folder: attendance | bus-safety | journal | facility), trả về URL cloud.
  /// Ảnh đã là URL http thì giữ nguyên.
  Future<String> uploadTeacherPhoto(String pathOrUrl, String folder) async {
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(pathOrUrl, filename: '$folder.jpg'),
    });
    final res = await _dio.post(ApiEndpoints.teacherUploadPhoto,
        data: form, queryParameters: {'folder': folder});
    final data = res.data is Map && res.data['data'] is Map ? res.data['data'] as Map : res.data as Map;
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Không nhận được URL ảnh từ máy chủ');
    return url;
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dioMessage(DioException e, String fallback) {
    final resData = e.response?.data;
    if (resData is Map && resData['message'] != null) return resData['message'].toString();
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Không kết nối được máy chủ';
    }
    return fallback;
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
                if (rec['temperature'] is num) {
                  s.temperature = (rec['temperature'] as num).toDouble();
                }
                if (rec['guardianName'] != null) {
                  s.guardianName = rec['guardianName'].toString();
                }
                if (rec['photoUrl'] != null) {
                  s.photoUrl = rec['photoUrl'].toString();
                }
                if (rec['symptoms'] != null) {
                  s.symptoms = rec['symptoms'].toString();
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
    String? symptoms,
  }) {
    if (index < 0 || index >= _students.length) return;
    if (symptoms != null) _students[index].symptoms = symptoms;
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
    final isPast830 = (now.hour > 8 || (now.hour == 8 && now.minute > 30));
    final defaultStatus = isPast830 ? AttendanceStatus.late : AttendanceStatus.present;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (var s in _students) {
      // Bé đã có đơn nghỉ phép được duyệt giữ nguyên 'Nghỉ phép'
      if (s.status == AttendanceStatus.onLeave) continue;
      s.status = defaultStatus;
      s.checkInTime ??= timeStr;
    }
    notifyListeners();
  }

  void toggleStudentStatus(int index) {
    if (index < 0 || index >= _students.length) return;
    final current = _students[index].status;
    final now = DateTime.now();
    final isPast830 = (now.hour > 8 || (now.hour == 8 && now.minute > 30));

    switch (current) {
      case AttendanceStatus.notArrived:
        _students[index].status = isPast830 ? AttendanceStatus.late : AttendanceStatus.present;
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

      // Ảnh lúc đón chụp trên máy -> tải lên cloud trước khi lưu (để xem lại được sau khi tải lại)
      for (final s in validStudents) {
        if (s.photoUrl != null && s.photoUrl!.isNotEmpty && !s.photoUrl!.startsWith('http')) {
          s.photoUrl = await uploadTeacherPhoto(s.photoUrl!, 'attendance');
        }
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
          if (s.checkInTime != null && RegExp(r'^\d{2}:\d{2}').hasMatch(s.checkInTime!))
            'checkInTime': s.checkInTime!.substring(0, 5),
          if (s.temperature != null) 'temperature': s.temperature,
          if (s.guardianName != null && s.guardianName!.isNotEmpty) 'guardianName': s.guardianName,
          if (s.symptoms != null && s.symptoms!.isNotEmpty) 'symptoms': s.symptoms,
          if (s.photoUrl != null && s.photoUrl!.startsWith('http')) 'photoUrl': s.photoUrl,
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
    _lastActionFailed = false;
    try {
      final res = await _dio.post(
        ApiEndpoints.busCheckin,
        data: {
          'tripId': tripId,
          'studentId': studentId,
          'stopId': stopId,
          'action': actionType,
        },
      );
      await loadBusTrip(tripId);
      return res.data['message']?.toString() ?? 'Ghi nhận điểm danh xe buýt thành công';
    } catch (e) {
      log('submitBusCheckin error: $e');
      _lastActionFailed = true;
      return _apiMessage(e, 'Không ghi nhận được điểm danh xe buýt.');
    }
  }

  /// Body khớp `BusSafetyClosureDto` ở backend (photoUrl, qrTailScanToken bắt buộc).
  Future<String?> performBusSafetyClosure({
    required String tripId,
    required String photoUrl,
    required String qrTailScanToken,
  }) async {
    _lastActionFailed = false;
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
      await loadBusTrip(tripId);
      return res.data['message']?.toString() ?? 'Hoàn thành chuyến xe an toàn';
    } catch (e) {
      log('performBusSafetyClosure error: $e');
      _lastActionFailed = true;
      return _apiMessage(e, 'Không thể đóng chuyến xe, vui lòng thử lại.');
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
    _lastActionFailed = false;
    try {
      // Ảnh chụp từ camera là file trên máy -> tải lên server trước để lấy fileId/url thật (BR-030)
      String? proofPhotoId;
      String photoUrl = proofImageUrl;
      if (!proofImageUrl.startsWith('http')) {
        final form = FormData.fromMap({
          'photo': await MultipartFile.fromFile(proofImageUrl, filename: 'medication_proof.jpg'),
        });
        final up = await _dio.post(ApiEndpoints.medicationProofPhoto, data: form);
        final upData = up.data is Map && up.data['data'] is Map ? up.data['data'] as Map : up.data as Map;
        proofPhotoId = upData['fileId']?.toString();
        photoUrl = upData['url']?.toString() ?? '';
      }
      final res = await _dio.post(
        ApiEndpoints.medicationAdminister(id),
        data: {
          if (proofPhotoId != null) 'proofPhotoId': proofPhotoId,
          'photoUrl': photoUrl,
          'administeredAt': DateTime.now().toIso8601String(),
          if (note != null) 'notes': note,
        },
      );
      await loadDailyMedications();
      return res.data['message']?.toString() ?? 'MSG-205: Xác nhận đã cho trẻ uống thuốc thành công.';
    } catch (e) {
      await loadDailyMedications();
      _lastActionFailed = true;
      return _apiMessage(e, 'Không xác nhận được lần uống thuốc.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Health Metrics (WHO) (G8-UC-03, BR-031)
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _measurementRounds = [];
  List<Map<String, dynamic>> get measurementRounds => _measurementRounds;

  Future<void> loadMeasurementRounds() async {
    try {
      final res = await _dio.get('/api/health-reports/rounds');
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _measurementRounds = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      notifyListeners();
    } catch (e) {
      log('loadMeasurementRounds error: $e');
      _measurementRounds = [];
    }
  }

  Future<void> loadHealthMetricsEntrySheet(String classId, {String? measurementRoundId}) async {
    if (classId.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final queryParams = measurementRoundId != null && measurementRoundId.isNotEmpty
          ? {'measurementRoundId': measurementRoundId}
          : null;
      final res = await _dio.get(
        ApiEndpoints.healthMetricsEntrySheet(classId),
        queryParameters: queryParams,
      );
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

  Future<String?> submitHealthMetricsBatch(List<Map<String, dynamic>> metrics, {String? measurementRoundId}) async {
    _lastActionFailed = false;
    _loading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {
        'classId': _currentClassId,
        'measurementDate': DateTime.now().toIso8601String().split('T').first,
        'records': metrics,
      };
      if (measurementRoundId != null && measurementRoundId.isNotEmpty) {
        body['measurementRoundId'] = measurementRoundId;
      }
      final res = await _dio.post(
        ApiEndpoints.healthMetricsBatch,
        data: body,
      );
      _loading = false;
      notifyListeners();
      return res.data['message']?.toString() ?? 'MSG-131: Lưu chỉ số phát triển thể chất định kỳ thành công.';
    } catch (e) {
      _loading = false;
      notifyListeners();
      _lastActionFailed = true;
      return _apiMessage(e, 'Không lưu được chỉ số thể chất.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Health Incidents (G8-UC-04, BR-031)
  // ─────────────────────────────────────────────────────────────

  /// Sự cố y tế của cả lớp đang chọn (thay vì chỉ 1 học sinh).
  Future<void> loadClassHealthIncidents() async {
    if (_currentClassId.isEmpty) return;
    try {
      final res = await _dio.get(ApiEndpoints.healthIncidentsByClass(_currentClassId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _healthIncidents = list.map((e) => HealthIncident.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadClassHealthIncidents error: $e');
      _healthIncidents = [];
    }
    notifyListeners();
  }

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
    _lastActionFailed = false;
    try {
      final res = await _dio.post(
        ApiEndpoints.healthIncidents,
        data: {
          // Khớp HealthIncidentCreateDto: loại sự cố + mức độ ghi vào đầu mô tả triệu chứng
          'studentId': studentId,
          'symptomDescription': '[$incidentType][$severity] $description',
          'isSevere': severity == 'SEVERE',
          if (firstAidGiven.isNotEmpty) 'firstAidGiven': firstAidGiven,
        },
      );
      await loadClassHealthIncidents();
      return res.data['message']?.toString() ?? 'MSG-135: Ghi nhận sự cố y tế và gửi thông báo khẩn cấp tới phụ huynh thành công.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không ghi nhận được sự cố y tế.');
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
    _lastActionFailed = false;
    try {
      final res = await _dio.post(
        ApiEndpoints.napRecords,
        data: {
          // Khớp DailyActivityRecordDto ở backend (startTime/endTime/notes, enum SleepQuality)
          'studentId': studentId,
          'startTime': napStartTime,
          'endTime': napEndTime,
          'sleepQuality': const {
                'NGỦ SÂU': 'GOOD',
                'HAY GIẬT MÌNH': 'RESTLESS',
                'KHÓ VÀO GIẤC': 'DIFFICULT_TO_SLEEP',
                'KHÓC KHI THỨC': 'WOKE_UP_CRYING',
              }[sleepQuality] ??
              sleepQuality,
          if (note != null && note.isNotEmpty) 'notes': note,
        },
      );
      final msg = res.data['message']?.toString() ?? 'MSG-208: Ghi nhận nhật ký giấc ngủ của trẻ thành công.';
      final minutes = (res.data['data'] is Map) ? res.data['data']['napDurationMinutes'] : null;
      return minutes != null ? '$msg (Thời lượng ngủ: $minutes phút)' : msg;
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không lưu được nhật ký giấc ngủ.');
    }
  }

  Future<String?> recordMeal({
    required String studentId,
    required String mealType,
    required String portionEaten,
    String? note,
  }) async {
    _lastActionFailed = false;
    try {
      final res = await _dio.post(
        ApiEndpoints.mealRecords,
        data: {
          // Khớp DailyActivityRecordDto ở backend (mealType, intakeLevel enum ConsumptionLevel, notes)
          'studentId': studentId,
          'mealType': const {
                'BỮA SÁNG': 'BREAKFAST',
                'BỮA PHỤ SÁNG': 'MORNING_SNACK',
                'BỮA TRƯA': 'LUNCH',
                'BỮA XẾ': 'AFTERNOON_SNACK',
              }[mealType] ??
              mealType,
          'intakeLevel': portionEaten == 'NONE' ? 'REFUSED' : portionEaten,
          if (note != null && note.isNotEmpty) 'notes': note,
        },
      );
      return res.data['message']?.toString() ?? 'MSG-211: Ghi nhận khẩu phần ăn của trẻ thành công.';
    } catch (e) {
      _lastActionFailed = true;
      return _apiMessage(e, 'Không lưu được khẩu phần ăn.');
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
    _lastActionFailed = false;
    try {
      final res = await _dio.post(
        ApiEndpoints.lessonPlans,
        data: {
          'classId': classId,
          'weekNumber': weekNumber,
          'title': title,
          if (fileUrl.isNotEmpty) 'fileUrl': fileUrl,
          // Backend nhận 'activities' dạng chuỗi, mỗi dòng 1 ngày (Thứ 2 → Thứ 6)
          'activities': activities.join('\n'),
        },
      );
      await loadLessonPlans(classId);
      return res.data['message']?.toString() ?? 'MSG-188: Nộp kế hoạch giáo dục tuần lên BGH thành công.';
    } catch (e) {
      await loadLessonPlans(classId);
      _lastActionFailed = true;
      return _apiMessage(e, 'Không nộp được kế hoạch giáo dục tuần.');
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
    _lastActionFailed = false;
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
          'comments': item.teacherComment,
        },
      );
      await loadDevelopmentEvaluations(_currentClassId);
      return res.data['message']?.toString() ?? 'MSG-181: Lưu phiếu đánh giá chuẩn phát triển 5 lĩnh vực của trẻ thành công.';
    } catch (e) {
      await loadDevelopmentEvaluations(_currentClassId);
      _lastActionFailed = true;
      return _apiMessage(e, 'Không lưu được phiếu đánh giá.');
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

  /// Danh mục thiết bị của lớp để chọn khi báo hỏng (UC-67 bước 2).
  Future<List<ClassEquipmentOption>> loadClassEquipmentOptions() async {
    if (_currentClassId.isEmpty) return [];
    try {
      final res = await _dio.get(ApiEndpoints.classEquipmentOptions(_currentClassId));
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
      return list.map((e) => ClassEquipmentOption.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('loadClassEquipmentOptions error: $e');
      return [];
    }
  }

  /// Gửi phiếu báo hỏng (UC-67): chọn [equipmentId] trong danh mục, hoặc nhập [equipmentName] khi thiết bị chưa có trong danh mục.
  Future<String?> reportEquipmentIncident({
    String? equipmentId,
    String? equipmentName,
    int damagedQuantity = 1,
    String severity = 'NORMAL',
    required String description,
    required String photoUrl,
    String? classroomId,
  }) async {
    _lastActionFailed = false;
    try {
      final uploadedUrl = await uploadTeacherPhoto(photoUrl, 'facility');
      final res = await _dio.post(
        ApiEndpoints.equipmentIncidents,
        data: {
          if (equipmentId != null) 'equipmentId': equipmentId,
          if (equipmentName != null) 'equipmentName': equipmentName,
          'damagedQuantity': damagedQuantity,
          'description': description,
          'severity': severity,
          'photoUrl': uploadedUrl,
          'classroomId': classroomId ?? _currentClassId,
        },
      );
      await loadEquipmentIncidents(_currentClassId);
      return res.data['message']?.toString() ?? 'Gửi báo cáo sự cố hư hỏng cơ sở vật chất lớp học thành công.';
    } catch (e) {
      await loadEquipmentIncidents(_currentClassId);
      _lastActionFailed = true;
      return _apiMessage(e, 'Không gửi được báo cáo sự cố CSVC.');
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
    _lastActionFailed = false;
    try {
      final res = await _dio.put(
        ApiEndpoints.classChatLock(classId),
        data: {'isMuted': lockState},
      );
      _isChatLocked = lockState;
      notifyListeners();
      return res.data['message']?.toString() ?? 'MSG-235: Cập nhật trạng thái điều hành nhóm chat lớp thành công.';
    } catch (e) {
      notifyListeners();
      _lastActionFailed = true;
      return _apiMessage(e, 'Không cập nhật được trạng thái nhóm chat.');
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
    _lastActionFailed = false;
    try {
      // Ảnh chọn từ máy -> tải lên cloud trước
      final uploaded = <String>[];
      for (final p in photoUrls) {
        uploaded.add(await uploadTeacherPhoto(p, 'journal'));
      }
      final res = await _dio.post(
        ApiEndpoints.journalPosts,
        data: {
          'classId': _currentClassId,
          'title': title,
          'content': content,
          'photoUrls': uploaded,
          'taggedStudentIds': taggedStudentIds,
        },
      );
      await loadClassroomJournal(_currentClassId);
      return res.data['message']?.toString() ?? 'MSG-238: Đăng tải album ảnh hoạt động lớp thành công.';
    } catch (e) {
      await loadClassroomJournal(_currentClassId);
      _lastActionFailed = true;
      return _apiMessage(e, 'Không đăng được album.');
    }
  }
}

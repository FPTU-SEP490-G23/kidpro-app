import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';

class TeacherProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  List<TeacherStudent> _students = [];
  List<StrangerAlert> _strangerAlerts = [];
  List<MedicationTask> _medications = [];
  bool _loading = false;
  String? _error;

  List<TeacherStudent> get students => _students;
  List<StrangerAlert> get strangerAlerts => _strangerAlerts;
  List<MedicationTask> get medications => _medications;
  bool get loading => _loading;
  String? get error => _error;

  int get presentCount =>
      _students.where((s) => s.status == AttendanceStatus.present).length;
  int get notArrivedCount =>
      _students.where((s) => s.status == AttendanceStatus.notArrived).length;
  int get onLeaveCount =>
      _students.where((s) => s.status == AttendanceStatus.onLeave).length;

  // ── Attendance ──

  Future<void> loadStudents(String classId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.teacherClassStudents(classId));
      _students = (res.data as List)
          .map((e) => TeacherStudent.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      _error = e.message;
    }
    _loading = false;
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
        _students[index].status = AttendanceStatus.onLeave;
        break;
      case AttendanceStatus.onLeave:
        _students[index].status = AttendanceStatus.notArrived;
        break;
    }
    notifyListeners();
  }

  Future<bool> submitAttendanceBatch() async {
    _loading = true;
    notifyListeners();
    try {
      final records = _students.map((s) {
        String statusStr;
        switch (s.status) {
          case AttendanceStatus.present:
            statusStr = 'PRESENT';
            break;
          case AttendanceStatus.onLeave:
            statusStr = 'EXCUSED_ABSENCE';
            break;
          case AttendanceStatus.notArrived:
            statusStr = 'UNEXCUSED_ABSENCE';
            break;
        }
        return {
          'studentId': s.id,
          'status': statusStr,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _dio.post(
        ApiEndpoints.teacherAttendanceBatch,
        data: {'records': records},
      );
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Stranger & Dismissal Alerts ──

  Future<void> loadStrangerAlerts() async {
    try {
      final res = await _dio.get(ApiEndpoints.faceLogsUnresolved);
      _strangerAlerts = (res.data as List)
          .map((e) => StrangerAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = e.message;
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
    } on DioException {
      return false;
    }
  }

  // ── Medications (14:00 daily) ──

  Future<void> loadDailyMedications() async {
    _loading = true;
    notifyListeners();
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final res = await _dio.get(
        ApiEndpoints.medications,
        queryParameters: {'date': todayStr},
      );
      _medications = (res.data as List)
          .map((e) => MedicationTask.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on DioException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> administerMedication(String id, String proofImageUrl, String? note) async {
    try {
      await _dio.put(
        ApiEndpoints.medicationAdminister(id),
        data: {
          'proofImageUrl': proofImageUrl,
          'administeredAt': DateTime.now().toIso8601String(),
          if (note != null) 'note': note,
        },
      );
      await loadDailyMedications();
      return true;
    } on DioException {
      return false;
    }
  }
}

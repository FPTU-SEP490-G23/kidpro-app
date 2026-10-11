/// Teacher models matching KidPro backend entities and DTOs.

enum AttendanceStatus { present, notArrived, onLeave }

class TeacherStudent {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? studentCode;
  AttendanceStatus status;

  TeacherStudent({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.studentCode,
    this.status = AttendanceStatus.notArrived,
  });

  factory TeacherStudent.fromJson(Map<String, dynamic> json) => TeacherStudent(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        studentCode: json['studentCode'] as String?,
        status: AttendanceStatus.notArrived,
      );
}

class StrangerAlert {
  final String id;
  final String? snapshotUrl;
  final DateTime detectedAt;
  final double? confidence;
  final bool isResolved;
  final String? resolutionNote;

  const StrangerAlert({
    required this.id,
    this.snapshotUrl,
    required this.detectedAt,
    this.confidence,
    this.isResolved = false,
    this.resolutionNote,
  });

  factory StrangerAlert.fromJson(Map<String, dynamic> json) => StrangerAlert(
        id: json['id'] as String,
        snapshotUrl: json['snapshotUrl'] as String? ?? json['photoUrl'] as String?,
        detectedAt: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        isResolved: json['isResolved'] as bool? ?? false,
        resolutionNote: json['resolutionNote'] as String?,
      );
}

class MedicationTask {
  final String id;
  final String studentId;
  final String studentName;
  final String medicineName;
  final String dosage;
  final String? note;
  final String status; // PENDING, ADMINISTERED, CANCELLED
  final String? proofImageUrl;
  final DateTime? administeredAt;

  const MedicationTask({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.medicineName,
    required this.dosage,
    this.note,
    required this.status,
    this.proofImageUrl,
    this.administeredAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isAdministered => status == 'ADMINISTERED';

  factory MedicationTask.fromJson(Map<String, dynamic> json) => MedicationTask(
        id: json['id'] as String,
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? 'Học sinh',
        medicineName: json['medicineName'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        proofImageUrl: json['proofImageUrl'] as String?,
        administeredAt: json['administeredAt'] != null
            ? DateTime.parse(json['administeredAt'] as String)
            : null,
      );
}

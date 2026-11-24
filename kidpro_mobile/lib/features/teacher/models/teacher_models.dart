/// Teacher models matching KidPro backend entities and DTOs.
library;

enum AttendanceStatus { present, late, onLeave, notArrived }

class TeacherStudent {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? studentCode;
  AttendanceStatus status;
  String? checkInTime;
  String? checkOutTime;
  String? notes;
  double? temperature;
  String? guardianName;
  String? photoUrl;
  String? checkInMethod;
  /// UC-33: triệu chứng khi khám sức khỏe buổi sáng
  String? symptoms;

  TeacherStudent({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.studentCode,
    this.status = AttendanceStatus.notArrived,
    this.checkInTime,
    this.checkOutTime,
    this.notes,
    this.temperature,
    this.guardianName,
    this.photoUrl,
    this.checkInMethod,
    this.symptoms,
  });

  factory TeacherStudent.fromJson(Map<String, dynamic> json) => TeacherStudent(
        id: (json['id'] ?? json['studentId'] ?? '') as String,
        fullName: (json['fullName'] ?? json['name'] ?? json['studentName'] ?? '') as String,
        avatarUrl: json['avatarUrl'] as String?,
        studentCode: json['studentCode'] as String?,
        status: parseStatus(json['status'] as String?),
        checkInTime: json['checkInTime'] as String?,
        checkOutTime: json['checkOutTime'] as String?,
        notes: json['notes'] as String?,
        temperature: (json['temperature'] as num?)?.toDouble(),
        guardianName: json['guardianName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        checkInMethod: json['checkInMethod'] as String?,
      );

  static AttendanceStatus parseStatus(String? status) {
    if (status == null) return AttendanceStatus.notArrived;
    final upper = status.toUpperCase();
    if (upper == 'PRESENT') return AttendanceStatus.present;
    if (upper == 'LATE') return AttendanceStatus.late;
    if (upper == 'EXCUSED_ABSENCE' ||
        upper == 'ON_LEAVE' ||
        upper == 'ABSENT_PERMITTED' ||
        upper == 'ABSENT_WITH_LEAVE') {
      return AttendanceStatus.onLeave;
    }
    return AttendanceStatus.notArrived;
  }
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
        id: (json['id'] ?? json['faceLogId'] ?? '') as String,
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

  // Backend: PENDING (chờ tiếp nhận), ACCEPTED (đã nhận thuốc), COMPLETED (đã cho uống), CANCELLED
  bool get isPending => status == 'PENDING' || status == 'ACCEPTED';
  /// UC-72: đơn mới, cô giáo chưa tiếp nhận & đối chiếu thuốc
  bool get isAwaitingReceipt => status == 'PENDING';
  /// Đã tiếp nhận thuốc, chờ cho uống
  bool get isReceived => status == 'ACCEPTED';
  bool get isAdministered => status == 'ADMINISTERED' || status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  factory MedicationTask.fromJson(Map<String, dynamic> json) => MedicationTask(
        id: (json['id'] ?? json['requestId'] ?? '').toString(),
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? 'Học sinh',
        medicineName: json['medicineName'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        note: json['note'] as String? ?? json['instructions'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        proofImageUrl: json['proofImageUrl'] as String? ?? json['proofPhotoUrl'] as String?,
        administeredAt: json['administeredAt'] != null
            ? DateTime.parse(json['administeredAt'] as String)
            : null,
      );
}

// ── Bus Attendance (G5-UC-02, G5-UC-03, BR-024) ──
class BusStopInfo {
  final String stopId;
  final String stopName;
  final String stopAddress;
  final int stopOrder;
  final String estimatedTime;
  final double? latitude;
  final double? longitude;
  final int boardedCount;
  final int deboardedCount;
  final bool isPassed;
  final bool isDestination;

  const BusStopInfo({
    required this.stopId,
    required this.stopName,
    this.stopAddress = '',
    this.stopOrder = 1,
    this.estimatedTime = '',
    this.latitude,
    this.longitude,
    this.boardedCount = 0,
    this.deboardedCount = 0,
    this.isPassed = false,
    this.isDestination = false,
  });

  factory BusStopInfo.fromJson(Map<String, dynamic> json) => BusStopInfo(
        stopId: (json['stopId'] ?? '').toString(),
        stopName: json['stopName'] as String? ?? 'Trạm đón/trả',
        stopAddress: json['stopAddress'] as String? ?? '',
        stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
        estimatedTime: json['estimatedTime'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        boardedCount: (json['boardedCount'] as num?)?.toInt() ?? 0,
        deboardedCount: (json['deboardedCount'] as num?)?.toInt() ?? 0,
        isPassed: json['isPassed'] as bool? ?? false,
        isDestination: json['isDestination'] as bool? ?? false,
      );
}

class BusTripInfo {
  final String tripId;
  final String routeName;
  final String plateNumber;
  final String? driverName;
  final String? driverPhone;
  final int totalStudents;
  final int onboardCount;
  final int deboardedCount;
  final int remainingCount;
  final bool isSafetyClosed;
  final List<BusStopInfo> stops;
  final List<BusStudentInfo> students;
  final int waitingCount;

  const BusTripInfo({
    required this.tripId,
    required this.routeName,
    required this.plateNumber,
    this.driverName,
    this.driverPhone,
    required this.totalStudents,
    required this.onboardCount,
    required this.deboardedCount,
    required this.remainingCount,
    this.isSafetyClosed = false,
    this.stops = const [],
    this.students = const [],
    this.waitingCount = 0,
  });

  factory BusTripInfo.fromJson(Map<String, dynamic> json) {
    List<BusStopInfo> stopsList = [];
    if (json['stops'] is List) {
      final rawStops = json['stops'] as List;
      stopsList = rawStops.map((s) {
        if (s is Map<String, dynamic>) {
          return BusStopInfo.fromJson(s);
        } else if (s is Map) {
          return BusStopInfo.fromJson(Map<String, dynamic>.from(s));
        }
        return null;
      }).whereType<BusStopInfo>().toList();
    }
    return BusTripInfo(
      tripId: (json['tripId'] ?? '').toString(),
      routeName: json['routeName'] as String? ?? 'Tuyến xe buýt KidPro',
      plateNumber: json['plateNumber'] as String? ?? '',
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      onboardCount: (json['onboardCount'] as num?)?.toInt() ?? 0,
      deboardedCount: (json['deboardedCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
      isSafetyClosed: json['isSafetyClosed'] as bool? ?? false,
      stops: stopsList,
      students: (json['students'] is List)
          ? (json['students'] as List)
              .whereType<Map>()
              .map((e) => BusStudentInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      waitingCount: (json['waitingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Học sinh đăng ký (đã duyệt) đi chuyến xe: WAITING (chưa lên) / ONBOARD (trên xe) / DEBOARDED (đã xuống).
class BusStudentInfo {
  final String studentId;
  final String studentName;
  final String? className;
  final String? pickupAddress;
  final String status;
  final String? lastTime;

  const BusStudentInfo({
    required this.studentId,
    required this.studentName,
    this.className,
    this.pickupAddress,
    this.status = 'WAITING',
    this.lastTime,
  });

  bool get isOnboard => status == 'ONBOARD';
  bool get isDeboarded => status == 'DEBOARDED';

  factory BusStudentInfo.fromJson(Map<String, dynamic> json) => BusStudentInfo(
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String? ?? '',
        className: json['className'] as String?,
        pickupAddress: json['pickupAddress'] as String?,
        status: json['status'] as String? ?? 'WAITING',
        lastTime: json['lastTime'] as String?,
      );
}

// ── Emergency Pickup Verification (G5-UC-06, BR-022) ──
class EmergencyPickupInfo {
  final int authorizationId;
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String? className;
  final String? parentName;
  final String? parentPhone;
  final String pickupPersonName;
  final String? pickupPersonPhone;
  final DateTime? validUntil;
  /// Phụ huynh có gửi ảnh người đón hộ: phải quét mặt khớp mới được bàn giao.
  final bool hasPickupPhoto;

  const EmergencyPickupInfo({
    required this.authorizationId,
    required this.studentId,
    required this.studentName,
    this.studentCode,
    this.className,
    this.parentName,
    this.parentPhone,
    required this.pickupPersonName,
    this.pickupPersonPhone,
    this.validUntil,
    this.hasPickupPhoto = false,
  });

  factory EmergencyPickupInfo.fromJson(Map<String, dynamic> json) => EmergencyPickupInfo(
        authorizationId: (json['authorizationId'] as num).toInt(),
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String? ?? '',
        studentCode: json['studentCode'] as String?,
        className: json['className'] as String?,
        parentName: json['authorizedByParentName'] as String?,
        parentPhone: json['authorizedByParentPhone'] as String?,
        pickupPersonName: json['pickupPersonName'] as String? ?? '',
        pickupPersonPhone: json['pickupPersonPhone'] as String?,
        validUntil: json['validUntil'] != null
            ? DateTime.tryParse(json['validUntil'].toString())
            : null,
        hasPickupPhoto: json['hasPickupPhoto'] as bool? ?? false,
      );
  }

/// Kết quả quét khuôn mặt phụ huynh khi đón trẻ (nhận diện phụ huynh trong lớp, cho đón con & ghi attendance)
class ParentPickupRecognitionResult {
  final bool matched;
  final double? similarity;
  final double? threshold;
  final String? personType;
  final String? personName;
  final String? relationship;
  final String? phoneNumber;
  final String? photoUrl;
  final String? capturedPhotoUrl;
  final int? guardianId;
  final String? studentId;
  final String? studentName;
  final String? studentCode;
  final String? className;
  final bool checkoutSuccess;
  final bool alreadyCheckedOut;
  final String? checkoutTime;
  final String message;

  const ParentPickupRecognitionResult({
    required this.matched,
    this.similarity,
    this.threshold,
    this.personType,
    this.personName,
    this.relationship,
    this.phoneNumber,
    this.photoUrl,
    this.capturedPhotoUrl,
    this.guardianId,
    this.studentId,
    this.studentName,
    this.studentCode,
    this.className,
    required this.checkoutSuccess,
    required this.alreadyCheckedOut,
    this.checkoutTime,
    required this.message,
  });

  factory ParentPickupRecognitionResult.fromJson(Map<String, dynamic> json) {
    return ParentPickupRecognitionResult(
      matched: json['matched'] as bool? ?? false,
      similarity: (json['similarity'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      personType: json['personType'] as String?,
      personName: json['personName'] as String?,
      relationship: json['relationship'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      capturedPhotoUrl: json['capturedPhotoUrl'] as String?,
      guardianId: (json['guardianId'] as num?)?.toInt(),
      studentId: json['studentId'] as String?,
      studentName: json['studentName'] as String?,
      studentCode: json['studentCode'] as String?,
      className: json['className'] as String?,
      checkoutSuccess: json['checkoutSuccess'] as bool? ?? false,
      alreadyCheckedOut: json['alreadyCheckedOut'] as bool? ?? false,
      checkoutTime: json['checkoutTime']?.toString(),
      message: json['message'] as String? ?? '',
    );
  }
}

// ── Đón muộn tự động tính phí (G5-UC-05, BR-020) ──
/// Hệ thống tự tính: sau 17:30 tính 30.000đ/giờ, giờ chưa trọn tính tròn 1 giờ.
class LatePickupRecord {
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String? parentName;
  final String? parentPhone;
  /// Giờ trả bé (HH:mm); null khi bé vẫn đang chờ đón.
  final String? pickupTime;
  /// true: chưa được đón, phí còn tăng theo giờ.
  final bool isWaiting;
  final int lateMinutes;
  final int chargedHours;
  final double feeAmount;

  const LatePickupRecord({
    required this.studentId,
    required this.studentName,
    this.studentCode,
    this.parentName,
    this.parentPhone,
    this.pickupTime,
    required this.isWaiting,
    required this.lateMinutes,
    required this.chargedHours,
    required this.feeAmount,
  });

  factory LatePickupRecord.fromJson(Map<String, dynamic> json) {
    final rawTime = json['pickupTime']?.toString();
    return LatePickupRecord(
      studentId: (json['studentId'] ?? '').toString(),
      studentName: json['studentName'] as String? ?? 'Bé',
      studentCode: json['studentCode'] as String?,
      parentName: json['parentName'] as String?,
      parentPhone: json['parentPhone'] as String?,
      pickupTime: rawTime != null && rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime,
      isWaiting: json['status'] == 'WAITING',
      lateMinutes: (json['lateMinutes'] as num?)?.toInt() ?? 0,
      chargedHours: (json['chargedHours'] as num?)?.toInt() ?? 0,
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Health Metrics (WHO) (G8-UC-03, BR-031) ──
class HealthMetricItem {
  final String studentId;
  final String studentName;
  double? heightCm;
  double? weightKg;
  double? bmi;
  String? nutritionalStatus;

  HealthMetricItem({
    required this.studentId,
    required this.studentName,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.nutritionalStatus,
  });

  factory HealthMetricItem.fromJson(Map<String, dynamic> json) => HealthMetricItem(
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String? ?? '',
        heightCm: ((json['heightCm'] ?? json['lastHeightCm']) as num?)?.toDouble(),
        weightKg: ((json['weightKg'] ?? json['lastWeightKg']) as num?)?.toDouble(),
        bmi: ((json['bmi'] ?? json['lastBmi']) as num?)?.toDouble(),
        nutritionalStatus: (json['nutritionalStatus'] ?? json['lastZScoreStatus'])?.toString(),
      );
}

// ── Health Incident (G8-UC-04, BR-031) ──
class HealthIncident {
  final int incidentId;
  final String studentId;
  final String studentName;
  final String incidentType;
  final String severity; // MILD, MODERATE, SEVERE
  final String description;
  final String? firstAidGiven;
  final String status;
  final DateTime createdAt;

  const HealthIncident({
    required this.incidentId,
    required this.studentId,
    required this.studentName,
    required this.incidentType,
    required this.severity,
    required this.description,
    this.firstAidGiven,
    required this.status,
    required this.createdAt,
  });

  factory HealthIncident.fromJson(Map<String, dynamic> json) {
    // Backend lưu '[LOẠI][MỨC ĐỘ] mô tả' trong symptomDescription
    final raw = (json['symptomDescription'] ?? json['description'] ?? '').toString();
    final m = RegExp(r'^\[([^\]]*)\]\[([^\]]*)\]\s*(.*)$', dotAll: true).firstMatch(raw);
    final time = json['incidentTime'] ?? json['createdAt'];
    return HealthIncident(
      incidentId: (json['incidentId'] as num?)?.toInt() ?? 0,
      studentId: (json['studentId'] ?? '').toString(),
      studentName: json['studentName'] as String? ?? 'Bé',
      incidentType: m?.group(1) ?? json['incidentType'] as String? ?? 'SỰ CỐ',
      severity: m?.group(2) ?? json['severity'] as String? ?? 'MILD',
      description: m?.group(3) ?? raw,
      firstAidGiven: json['firstAidGiven'] as String?,
      status: json['status'] as String? ?? 'REPORTED',
      createdAt: time != null ? (DateTime.tryParse(time.toString()) ?? DateTime.now()) : DateTime.now(),
    );
  }
}

// ── Lesson Plan (G9-UC-01, BR-053) ──
class WeeklyLessonPlan {
  final int planId;
  final String classId;
  final int weekNumber;
  final String title;
  final String status; // DRAFT, SUBMITTED, APPROVED, REJECTED
  final String? fileUrl;
  final String? reviewComment;
  final DateTime createdAt;

  const WeeklyLessonPlan({
    required this.planId,
    required this.classId,
    required this.weekNumber,
    required this.title,
    required this.status,
    this.fileUrl,
    this.reviewComment,
    required this.createdAt,
  });

  factory WeeklyLessonPlan.fromJson(Map<String, dynamic> json) => WeeklyLessonPlan(
        planId: (json['planId'] as num?)?.toInt() ?? 0,
        classId: (json['classId'] ?? '').toString(),
        weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
        title: json['title'] as String? ?? 'Kế hoạch giáo dục tuần',
        status: json['status'] as String? ?? 'SUBMITTED',
        fileUrl: json['fileUrl'] as String?,
        reviewComment: json['reviewComment'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

// ── 5-Domain Development Evaluation (G9-UC-04, BR-049) ──
class DevelopmentEvaluationItem {
  final int? evaluationId;
  final String studentId;
  final String studentName;
  final String evaluationPeriod;
  final double physicalScore;
  final double cognitiveScore;
  final double languageScore;
  final double socialEmotionalScore;
  final double aestheticScore;
  final String teacherComment;
  final String status;

  const DevelopmentEvaluationItem({
    this.evaluationId,
    required this.studentId,
    required this.studentName,
    required this.evaluationPeriod,
    required this.physicalScore,
    required this.cognitiveScore,
    required this.languageScore,
    required this.socialEmotionalScore,
    required this.aestheticScore,
    required this.teacherComment,
    required this.status,
  });

  factory DevelopmentEvaluationItem.fromJson(Map<String, dynamic> json) {
    double parseScore(dynamic val) {
      if (val == null) return 5.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 5.0;
    }

    return DevelopmentEvaluationItem(
      evaluationId: (json['evaluationId'] as num?)?.toInt(),
      studentId: (json['studentId'] ?? '').toString(),
      studentName: json['studentName'] as String? ?? '',
      evaluationPeriod: json['evaluationPeriod'] as String? ?? 'HỌC KỲ I',
      physicalScore: parseScore(json['physicalScore']),
      cognitiveScore: parseScore(json['cognitiveScore']),
      languageScore: parseScore(json['languageScore']),
      socialEmotionalScore: parseScore(json['socialEmotionalScore']),
      aestheticScore: parseScore(json['aestheticScore']),
      teacherComment: json['teacherComment'] as String? ?? json['reviewNote'] as String? ?? '',
      status: json['status'] as String? ?? 'SUBMITTED',
    );
  }
}

// ── Classroom Equipment Incident (G9-UC-06, BR-051, BR-052) ──
/// Thiết bị trong danh mục tài sản của lớp (UC-67 bước 2).
class ClassEquipmentOption {
  final String equipmentId;
  final String equipmentCode;
  final String name;
  final int goodQuantity;
  final int damagedQuantity;

  const ClassEquipmentOption({
    required this.equipmentId,
    required this.equipmentCode,
    required this.name,
    required this.goodQuantity,
    required this.damagedQuantity,
  });

  factory ClassEquipmentOption.fromJson(Map<String, dynamic> json) => ClassEquipmentOption(
        equipmentId: json['equipmentId']?.toString() ?? '',
        equipmentCode: json['equipmentCode']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        goodQuantity: (json['goodQuantity'] as num?)?.toInt() ?? 0,
        damagedQuantity: (json['damagedQuantity'] as num?)?.toInt() ?? 0,
      );
}

class EquipmentIncidentItem {
  final String incidentId;
  final String equipmentName;
  final String? equipmentCode;
  final int damagedQuantity;
  final String severity; // NORMAL, URGENT
  final String classroomName;
  final String description;
  final String? photoUrl;
  final String status; // PENDING, IN_PROGRESS, RESOLVED
  final DateTime createdAt;
  final String? handledByName;
  final String? handlerNote;

  const EquipmentIncidentItem({
    required this.incidentId,
    required this.equipmentName,
    this.equipmentCode,
    this.damagedQuantity = 1,
    this.severity = 'NORMAL',
    required this.classroomName,
    required this.description,
    this.photoUrl,
    required this.status,
    required this.createdAt,
    this.handledByName,
    this.handlerNote,
  });

  factory EquipmentIncidentItem.fromJson(Map<String, dynamic> json) {
    // Backend trả incidentId dạng UUID và thời gian báo ở reportedAt
    final at = json['reportedAt'] ?? json['createdAt'];
    return EquipmentIncidentItem(
      incidentId: json['incidentId']?.toString() ?? '',
      equipmentName: json['equipmentName'] as String? ?? '',
      equipmentCode: json['equipmentCode'] as String?,
      damagedQuantity: (json['damagedQuantity'] as num?)?.toInt() ?? 1,
      severity: json['severity']?.toString() ?? 'NORMAL',
      classroomName: json['classroomName'] as String? ?? 'Lớp học',
      description: json['description'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: at != null ? DateTime.tryParse(at.toString()) ?? DateTime.now() : DateTime.now(),
      handledByName: json['handledByName'] as String?,
      handlerNote: json['handlerNote'] as String?,
    );
  }
}

// ── Leave Request Review (G10-UC-09, BR-064, BR-065) ──
class TeacherLeaveRequestItem {
  final int id;
  final String studentId;
  final String studentName;
  final String startDate;
  final String endDate;
  final String reason;
  final String status; // PENDING, APPROVED, REJECTED
  final bool mealRefundEligible;

  const TeacherLeaveRequestItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.mealRefundEligible = false,
  });

  factory TeacherLeaveRequestItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['leaveRequestId'] ?? json['id'];
    final int parsedId = (rawId as num?)?.toInt() ?? int.tryParse(rawId?.toString() ?? '0') ?? 0;

    return TeacherLeaveRequestItem(
      id: parsedId,
      studentId: (json['studentId'] ?? '').toString(),
      studentName: json['studentName'] as String? ?? 'Học sinh',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      mealRefundEligible: json['mealRefundEligible'] as bool? ?? json['eligibleForMealRefund'] as bool? ?? false,
    );
  }
}

// ── Classroom Chat Message (G11-UC-04, BR-058, BR-059) ──
class ClassChatMessageItem {
  final int messageId;
  final String classId;
  final String? studentName;
  final String senderType; // TEACHER, PARENT
  final String senderName;
  final String content;
  final bool isSilent;
  final DateTime createdAt;

  const ClassChatMessageItem({
    required this.messageId,
    required this.classId,
    this.studentName,
    required this.senderType,
    required this.senderName,
    required this.content,
    this.isSilent = false,
    required this.createdAt,
  });

  factory ClassChatMessageItem.fromJson(Map<String, dynamic> json) => ClassChatMessageItem(
        messageId: (json['messageId'] as num?)?.toInt() ?? 0,
        classId: (json['classId'] ?? '').toString(),
        studentName: json['studentName'] as String?,
        senderType: json['senderType'] as String? ?? 'TEACHER',
        senderName: json['senderName'] as String? ?? 'Giáo viên',
        content: json['content'] as String? ?? '',
        isSilent: json['isSilent'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

// ── Hội thoại nhắn riêng với phụ huynh của 1 bé ──
class PrivateChatThread {
  final String studentId;
  final String studentName;
  final String? parentName;
  final String? lastMessage;
  final String? lastSenderType; // TEACHER, PARENT
  final DateTime? lastMessageAt;
  final int unreadCount;

  const PrivateChatThread({
    required this.studentId,
    required this.studentName,
    this.parentName,
    this.lastMessage,
    this.lastSenderType,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory PrivateChatThread.fromJson(Map<String, dynamic> json) => PrivateChatThread(
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String? ?? 'Bé',
        parentName: json['parentName'] as String?,
        lastMessage: json['lastMessage'] as String?,
        lastSenderType: json['lastSenderType'] as String?,
        lastMessageAt: json['lastMessageAt'] != null ? DateTime.tryParse(json['lastMessageAt'].toString()) : null,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

// ── Classroom Journal Post (G11-UC-05, BR-060) ──
class ClassroomJournalItem {
  final int postId;
  final String classId;
  final String className;
  final String title;
  final String content;
  final List<String> photoUrls;
  final List<String> taggedStudentIds;
  final DateTime createdAt;

  const ClassroomJournalItem({
    required this.postId,
    required this.classId,
    required this.className,
    required this.title,
    required this.content,
    required this.photoUrls,
    required this.taggedStudentIds,
    required this.createdAt,
  });

  factory ClassroomJournalItem.fromJson(Map<String, dynamic> json) => ClassroomJournalItem(
        postId: (json['postId'] as num?)?.toInt() ?? 0,
        classId: (json['classId'] ?? '').toString(),
        className: json['className'] as String? ?? 'Lớp học',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        photoUrls: (json['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
        taggedStudentIds: (json['taggedStudentIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

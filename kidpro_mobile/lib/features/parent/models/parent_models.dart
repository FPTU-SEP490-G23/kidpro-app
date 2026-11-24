/// Parent-side models matching backend DTOs.
library;

class Invoice {
  final String id;
  final String studentName;
  final String periodLabel;
  final double totalAmount;
  final double paidAmount;
  final String status; // PENDING, PAID, OVERDUE, DISPUTED, UNPAID, PARTIAL
  final String? referenceCode;
  final String? paymentQrCode;

  const Invoice({
    required this.id,
    required this.studentName,
    required this.periodLabel,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.referenceCode,
    this.paymentQrCode,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isPaid => status == 'PAID' || status == 'OVERPAID';

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['invoiceId']?.toString() ?? json['id']?.toString() ?? '',
        studentName: json['studentName'] as String? ?? 'Bé yêu',
        periodLabel: json['periodLabel'] as String? ??
            'Tháng ${json['billingMonth'] ?? 10}/${json['billingYear'] ?? 2026}',
        totalAmount: (json['finalAmount'] ?? json['totalAmount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'UNPAID',
        referenceCode: json['invoiceCode'] as String? ?? json['referenceCode'] as String?,
        paymentQrCode: json['paymentQrCode'] as String?,
      );
}

class VietQrPayment {
  final String qrDataUrl;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final double amount;
  final String referenceCode;
  final String? deepLink;
  final String? checkoutUrl;
  final String? qrCode;

  const VietQrPayment({
    required this.qrDataUrl,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.referenceCode,
    this.deepLink,
    this.checkoutUrl,
    this.qrCode,
  });

  factory VietQrPayment.fromJson(Map<String, dynamic> json) => VietQrPayment(
        qrDataUrl: json['qrImageUrl'] as String? ?? json['paymentQrCode'] as String? ?? json['qrDataUrl'] as String? ?? '',
        bankName: json['bankName'] as String? ?? json['bankCode'] as String? ?? 'MB Bank',
        accountNumber: json['accountNumber'] as String? ?? '',
        accountName: json['accountName'] as String? ?? 'TRUONG MAM NON KIDPRO',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        referenceCode: json['referenceCode'] as String? ?? json['invoiceCode'] as String? ?? '',
        deepLink: json['deepLink'] as String? ?? json['deepLinkUrl'] as String?,
        checkoutUrl: json['checkoutUrl'] as String?,
        qrCode: json['qrCode'] as String? ?? json['paymentQrCode'] as String?,
      );
}

class LeaveRequest {
  final int? id;
  final String studentId;
  final String? studentName;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // PENDING, APPROVED, REJECTED
  final bool eligibleForMealRefund;

  LeaveRequest({
    this.id,
    required this.studentId,
    this.studentName,
    required this.reason,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? leaveDate,
    this.status = 'PENDING',
    this.eligibleForMealRefund = false,
  })  : startDate = startDate ?? leaveDate ?? DateTime.now(),
        endDate = endDate ?? leaveDate ?? startDate ?? DateTime.now();

  DateTime get leaveDate => startDate;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
        'reason': reason,
      };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['leaveRequestId'] as int? ?? json['id'] as int?,
        studentId: json['studentId']?.toString() ?? '',
        studentName: json['studentName'] as String?,
        reason: json['reason'] as String? ?? '',
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : DateTime.now(),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : DateTime.now(),
        status: json['status'] as String? ?? 'PENDING',
        eligibleForMealRefund: json['eligibleForMealRefund'] as bool? ?? false,
      );
}

class MedicationRequest {
  final int? id;
  final String studentId;
  final String? studentName;
  final String instructions;
  final DateTime startDate;
  final DateTime endDate;
  final String? prescriptionPhotoUrl;
  final String? prescriptionPhotoId;
  final String status; // PENDING, ACCEPTED, COMPLETED, CANCELLED
  final String? medicineName;
  final String? dosage;
  final String? note;

  MedicationRequest({
    this.id,
    required this.studentId,
    this.studentName,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    String? prescriptionPhotoUrl,
    String? prescriptionImageUrl,
    this.prescriptionPhotoId,
    this.status = 'PENDING',
    this.medicineName,
    this.dosage,
    this.note,
  })  : instructions = instructions ??
            '${medicineName ?? ""}: ${dosage ?? ""}. ${note ?? ""}'.trim(),
        startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 1)),
        prescriptionPhotoUrl = prescriptionPhotoUrl ?? prescriptionImageUrl;

  String? get prescriptionImageUrl => prescriptionPhotoUrl;

  /// Bản sao gắn mã ảnh đơn thuốc đã upload lên cloud.
  MedicationRequest copyWithPhotoId(String photoId) => MedicationRequest(
        id: id,
        studentId: studentId,
        studentName: studentName,
        instructions: instructions,
        startDate: startDate,
        endDate: endDate,
        prescriptionPhotoUrl: prescriptionPhotoUrl,
        prescriptionPhotoId: photoId,
        status: status,
        medicineName: medicineName,
        dosage: dosage,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'instructions': instructions,
        if (medicineName != null) 'medicineName': medicineName,
        if (medicineName != null) 'medicationName': medicineName,
        if (dosage != null) 'dosage': dosage,
        if (note != null) 'notes': note,
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
        if (prescriptionPhotoId != null) 'prescriptionPhotoId': prescriptionPhotoId,
      };

  factory MedicationRequest.fromJson(Map<String, dynamic> json) =>
      MedicationRequest(
        id: json['requestId'] as int? ?? json['id'] as int?,
        studentId: json['studentId']?.toString() ?? '',
        studentName: json['studentName'] as String?,
        instructions: json['instructions'] as String? ?? '',
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : DateTime.now(),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : DateTime.now(),
        prescriptionPhotoUrl: json['prescriptionPhotoUrl'] as String?,
        prescriptionPhotoId: json['prescriptionPhotoId']?.toString(),
        status: json['status'] as String? ?? 'PENDING',
      );
}

class EmergencyPickup {
  final int? authorizationId;
  final String studentId;
  final String? studentName;
  final String pickupPersonName;
  final String pickupPersonPhone;
  final String? pinCode;
  final String? otpCode;
  final DateTime validUntil;
  final String status; // ACTIVE, USED, EXPIRED
  final String? qrData;

  const EmergencyPickup({
    this.authorizationId,
    required this.studentId,
    this.studentName,
    required this.pickupPersonName,
    required this.pickupPersonPhone,
    this.pinCode,
    this.otpCode,
    required this.validUntil,
    this.status = 'ACTIVE',
    this.qrData,
  });

  bool get isActive => status == 'ACTIVE' && validUntil.isAfter(DateTime.now());

  Map<String, dynamic> toJson(String parentId) => {
        'studentId': studentId,
        'parentId': parentId,
        'pickupPersonName': pickupPersonName,
        'pickupPersonPhone': pickupPersonPhone,
        if (pinCode != null) 'pinCode': pinCode,
      };

  factory EmergencyPickup.fromJson(Map<String, dynamic> json) => EmergencyPickup(
        authorizationId: json['authorizationId'] as int?,
        studentId: json['studentId']?.toString() ?? '',
        studentName: json['studentName'] as String?,
        pickupPersonName: json['pickupPersonName'] as String? ?? '',
        pickupPersonPhone: json['pickupPersonPhone'] as String? ?? '',
        otpCode: json['otpCode'] as String?,
        validUntil: json['validUntil'] != null
            ? DateTime.parse(json['validUntil'] as String)
            : DateTime.now().add(const Duration(minutes: 60)),
        status: json['status'] as String? ?? 'ACTIVE',
        qrData: json['qrData'] as String?,
      );
}

class AuthorizedGuardian {
  final int? guardianId;
  final String studentId;
  final String fullName;
  final String phoneNumber;
  final String relationshipToStudent;
  final bool isAllowedPickup;
  final String? note;
  final DateTime? createdAt;

  const AuthorizedGuardian({
    this.guardianId,
    required this.studentId,
    required this.fullName,
    required this.phoneNumber,
    required this.relationshipToStudent,
    this.isAllowedPickup = true,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'relationshipToStudent': relationshipToStudent,
        'isAllowedPickup': isAllowedPickup,
        if (note != null) 'note': note,
      };

  factory AuthorizedGuardian.fromJson(Map<String, dynamic> json) =>
      AuthorizedGuardian(
        guardianId: json['guardianId'] as int?,
        studentId: json['studentId']?.toString() ?? '',
        fullName: json['fullName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        relationshipToStudent: json['relationshipToStudent'] as String? ?? '',
        isAllowedPickup: json['isAllowedPickup'] as bool? ?? true,
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
}

class AllergyAlert {
  final int? allergyId;
  final String studentId;
  final String allergyType; // FOOD, MEDICATION, ENVIRONMENTAL
  final String allergen;
  final String severity; // MILD, MODERATE, SEVERE
  final String? description;

  const AllergyAlert({
    this.allergyId,
    required this.studentId,
    required this.allergyType,
    required this.allergen,
    required this.severity,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'allergyType': allergyType,
        'allergen': allergen,
        'severity': severity,
        if (description != null) 'description': description,
      };

  factory AllergyAlert.fromJson(Map<String, dynamic> json) => AllergyAlert(
        allergyId: json['allergyId'] as int?,
        studentId: json['studentId']?.toString() ?? '',
        allergyType: json['allergyType'] as String? ?? 'FOOD',
        allergen: json['allergen'] as String? ?? '',
        severity: json['severity'] as String? ?? 'MODERATE',
        description: json['description'] as String?,
      );
}

class ChatThread {
  final String id;
  final String otherPartyName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatThread({
    required this.id,
    required this.otherPartyName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
        id: json['id'] as String,
        otherPartyName: json['otherPartyName'] as String? ?? '',
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.parse(json['lastMessageAt'] as String)
            : null,
        unreadCount: json['unreadCount'] as int? ?? 0,
      );
}

/// Hội thoại nhắn riêng với giáo viên chủ nhiệm về 1 con.
class PrivateChatThreadModel {
  final String studentId;
  final String studentName;
  final String? className;
  final String? teacherName;
  final String? lastMessage;
  final String? lastSenderType; // TEACHER, PARENT
  final DateTime? lastMessageAt;
  final int unreadCount;

  const PrivateChatThreadModel({
    required this.studentId,
    required this.studentName,
    this.className,
    this.teacherName,
    this.lastMessage,
    this.lastSenderType,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory PrivateChatThreadModel.fromJson(Map<String, dynamic> json) => PrivateChatThreadModel(
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String? ?? 'Bé',
        className: json['className'] as String?,
        teacherName: json['teacherName'] as String?,
        lastMessage: json['lastMessage'] as String?,
        lastSenderType: json['lastSenderType'] as String?,
        lastMessageAt: json['lastMessageAt'] != null ? DateTime.tryParse(json['lastMessageAt'].toString()) : null,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderType; // TEACHER, PARENT
  final String? studentName;
  final String content;
  final DateTime sentAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName = 'Người dùng',
    this.senderType,
    this.studentName,
    required this.content,
    required this.sentAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['messageId'] ?? json['id'] ?? '')?.toString() ?? '',
        senderId: (json['senderAccountId'] ?? json['senderId'] ?? '')?.toString() ?? '',
        senderName: json['senderName'] as String? ?? 'Người dùng',
        senderType: json['senderType'] as String?,
        studentName: json['studentName'] as String?,
        content: json['content'] as String? ?? '',
        sentAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : (json['sentAt'] != null ? DateTime.parse(json['sentAt'] as String) : DateTime.now()),
        isRead: json['isRead'] as bool? ?? false,
      );
}

class StudentSummary {
  final String studentId;
  final String studentCode;
  final String fullName;
  final String? dateOfBirth;
  final String? gender;
  final String? classId;
  final String? className;
  final String? avatarUrl;
  final String? parentId;
  /// BR-018: gói bán trú (FULL: sáng-trưa-xế, LUNCH_SNACK: trưa-xế, NONE)
  final String boardingPackage;
  final String? boardingPackageLabel;
  /// Hạn báo nghỉ để được giảm trừ tiền ăn của gói, dạng HH:mm (null nếu không ăn bán trú)
  final String? mealRefundCutoff;
  final String? pendingBoardingPackage;
  final String? pendingPackageFrom;

  const StudentSummary({
    required this.studentId,
    required this.studentCode,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.classId,
    this.className,
    this.avatarUrl,
    this.parentId,
    this.boardingPackage = 'LUNCH_SNACK',
    this.boardingPackageLabel,
    this.mealRefundCutoff,
    this.pendingBoardingPackage,
    this.pendingPackageFrom,
  });

  String get displayName => className != null ? '$fullName ($className)' : fullName;

  factory StudentSummary.fromJson(Map<String, dynamic> json) => StudentSummary(
        studentId: json['studentId']?.toString() ?? '',
        studentCode: json['studentCode']?.toString() ?? '',
        fullName: json['fullName'] as String? ?? '',
        dateOfBirth: json['dateOfBirth']?.toString(),
        gender: json['gender']?.toString(),
        classId: json['classId']?.toString(),
        className: json['className'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        parentId: json['parentId']?.toString(),
        boardingPackage: json['boardingPackage']?.toString() ?? 'LUNCH_SNACK',
        boardingPackageLabel: json['boardingPackageLabel'] as String?,
        mealRefundCutoff: json['mealRefundCutoff']?.toString(),
        pendingBoardingPackage: json['pendingBoardingPackage']?.toString(),
        pendingPackageFrom: json['pendingPackageFrom']?.toString(),
      );
}

// ==========================================
// SỔ ĐIỆN TỬ & NHẬT KÝ MẦM NON (6 LOẠI)
// ==========================================

class DailyActivityModel {
  final int? activityId;
  final String? studentId;
  final String? date;
  final String? breakfastConsumption;
  final String? morningSnackConsumption;
  final String? lunchConsumption;
  final String? afternoonSnackConsumption;
  final String? mealNote;
  final String? sleepQuality;
  final int? napDurationMinutes;
  final String? napNote;
  final String? generalNote;
  final String? recordedByName;
  /// UC-74: nhật ký vệ sinh
  final int? toiletCount;
  final String? toiletNote;

  const DailyActivityModel({
    this.activityId,
    this.studentId,
    this.date,
    this.breakfastConsumption,
    this.morningSnackConsumption,
    this.lunchConsumption,
    this.afternoonSnackConsumption,
    this.mealNote,
    this.sleepQuality,
    this.napDurationMinutes,
    this.napNote,
    this.generalNote,
    this.recordedByName,
    this.toiletCount,
    this.toiletNote,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) => DailyActivityModel(
        activityId: json['activityId'] as int?,
        studentId: json['studentId']?.toString(),
        date: json['date']?.toString(),
        breakfastConsumption: json['breakfastConsumption']?.toString(),
        morningSnackConsumption: json['morningSnackConsumption']?.toString(),
        lunchConsumption: json['lunchConsumption']?.toString(),
        afternoonSnackConsumption: json['afternoonSnackConsumption']?.toString(),
        mealNote: json['mealNote'] as String?,
        sleepQuality: json['sleepQuality']?.toString(),
        napDurationMinutes: (json['napDurationMinutes'] as num?)?.toInt(),
        napNote: json['napNote'] as String?,
        generalNote: json['generalNote'] as String?,
        recordedByName: json['recordedByName'] as String?,
        toiletCount: (json['toiletCount'] as num?)?.toInt(),
        toiletNote: json['toiletNote'] as String?,
      );
}

class AttendanceRecordModel {
  final int? attendanceId;
  final String? studentId;
  final String? date;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;
  final String? notes;

  const AttendanceRecordModel({
    this.attendanceId,
    this.studentId,
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.status = 'PRESENT',
    this.notes,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) => AttendanceRecordModel(
        attendanceId: json['attendanceId'] as int?,
        studentId: json['studentId']?.toString(),
        date: json['date']?.toString(),
        checkInTime: json['checkInTime']?.toString(),
        checkOutTime: json['checkOutTime']?.toString(),
        status: json['status']?.toString() ?? 'PRESENT',
        notes: json['notes'] as String?,
      );
}

class DevelopmentEvaluationModel {
  final int? evaluationId;
  final String? studentId;
  final String? studentName;
  final String? evaluationPeriod;
  final String? physicalScore;
  final String? cognitiveScore;
  final String? languageScore;
  final String? socialEmotionalScore;
  final String? aestheticScore;
  final String? teacherName;
  final String? status;
  final String? reviewNote;

  const DevelopmentEvaluationModel({
    this.evaluationId,
    this.studentId,
    this.studentName,
    this.evaluationPeriod,
    this.physicalScore,
    this.cognitiveScore,
    this.languageScore,
    this.socialEmotionalScore,
    this.aestheticScore,
    this.teacherName,
    this.status,
    this.reviewNote,
  });

  factory DevelopmentEvaluationModel.fromJson(Map<String, dynamic> json) => DevelopmentEvaluationModel(
        evaluationId: json['evaluationId'] as int?,
        studentId: json['studentId']?.toString(),
        studentName: json['studentName'] as String?,
        evaluationPeriod: json['evaluationPeriod'] as String?,
        physicalScore: json['physicalScore'] as String?,
        cognitiveScore: json['cognitiveScore'] as String?,
        languageScore: json['languageScore'] as String?,
        socialEmotionalScore: json['socialEmotionalScore'] as String?,
        aestheticScore: json['aestheticScore'] as String?,
        teacherName: json['teacherName'] as String?,
        status: json['status'] as String?,
        reviewNote: json['reviewNote'] as String?,
      );
}

class HealthGrowthMetricModel {
  final int? metricId;
  final String? studentId;
  final String? measuredDate;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final String? zscoreCategory;
  final String? note;

  const HealthGrowthMetricModel({
    this.metricId,
    this.studentId,
    this.measuredDate,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.zscoreCategory,
    this.note,
  });

  factory HealthGrowthMetricModel.fromJson(Map<String, dynamic> json) => HealthGrowthMetricModel(
        metricId: json['metricId'] as int?,
        studentId: json['studentId']?.toString(),
        measuredDate: _formatYmd((json['measurementDate'] ?? json['measuredDate'])?.toString()),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        // BE trả enum ZScoreStatus (Jackson đặt tên "zscoreStatus")
        zscoreCategory: _zScoreLabel(
            (json['zscoreStatus'] ?? json['zScoreStatus'] ?? json['zscoreCategory'])?.toString()),
        note: json['note'] as String?,
      );

  /// "2026-11-20" -> "20/11/2026"; giữ nguyên nếu không đúng định dạng.
  static String? _formatYmd(String? s) {
    if (s == null || s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String? _zScoreLabel(String? s) {
    switch (s) {
      case 'NORMAL':
        return 'Bình thường';
      case 'MALNUTRITION':
        return 'Suy dinh dưỡng';
      case 'UNDERWEIGHT':
        return 'Thiếu cân';
      case 'OBESE':
        return 'Béo phì';
      default:
        return s;
    }
  }
}

class JournalPostModel {
  final int? postId;
  final String? title;
  final String? content;
  final String? classId;
  final String? className;
  final String? teacherName;
  final List<String> imageUrls;
  final String? createdAt;

  const JournalPostModel({
    this.postId,
    this.title,
    this.content,
    this.classId,
    this.className,
    this.teacherName,
    this.imageUrls = const [],
    this.createdAt,
  });

  factory JournalPostModel.fromJson(Map<String, dynamic> json) {
    List<String> images = [];
    final rawImages = json['photoUrls'] ?? json['imageUrls'];
    if (rawImages is List) {
      images = rawImages.map((e) => e.toString()).toList();
    }
    return JournalPostModel(
      postId: json['postId'] as int? ?? json['id'] as int?,
      title: json['title'] as String? ?? 'Hoạt động trải nghiệm',
      content: json['content'] as String? ?? '',
      classId: json['classId']?.toString(),
      className: json['className'] as String?,
      teacherName: json['teacherName'] as String? ?? json['authorStaffName'] as String?,
      imageUrls: images,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

// ==========================================
// TỔNG HỢP 11 LOẠI ĐƠN TỪ / PHIẾU YÊU CẦU
// ==========================================

class ParentUnifiedRequest {
  final String id;
  final String requestType; // LEAVE, TRANSFER, EMERGENCY_PICKUP, GUARDIAN, MEDICATION, ALLERGY, BUS, EXTRACURRICULAR, DISPUTE, OTHER, BIOMETRIC
  final String typeLabel;
  final String title;
  final String? studentId;
  final String? studentName;
  final String status;
  final String statusLabel;
  final String? createdAt;
  final Map<String, dynamic> metadata;

  const ParentUnifiedRequest({
    required this.id,
    required this.requestType,
    required this.typeLabel,
    required this.title,
    this.studentId,
    this.studentName,
    required this.status,
    required this.statusLabel,
    this.createdAt,
    this.metadata = const {},
  });

  factory ParentUnifiedRequest.fromJson(Map<String, dynamic> json) => ParentUnifiedRequest(
        id: json['id']?.toString() ?? '',
        requestType: json['requestType'] as String? ?? 'OTHER',
        typeLabel: json['typeLabel'] as String? ?? 'Đơn từ',
        title: json['title'] as String? ?? '',
        studentId: json['studentId']?.toString(),
        studentName: json['studentName'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        statusLabel: json['statusLabel'] as String? ?? 'Đang xử lý',
        createdAt: json['createdAt']?.toString(),
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      );

  String get type => requestType;
}

class AvailableOption {
  final String id;
  final String title;
  final String? subtitle;

  const AvailableOption({
    required this.id,
    required this.title,
    this.subtitle,
  });

  factory AvailableOption.fromClassJson(Map<String, dynamic> json) => AvailableOption(
        id: json['classId']?.toString() ?? '',
        title: json['className'] as String? ?? '',
        subtitle: json['roomNumber'] != null ? 'Phòng: ${json['roomNumber']}' : null,
      );

  factory AvailableOption.fromBusJson(Map<String, dynamic> json) {
    final routeStart = json['routeStart']?.toString().trim() ?? '';
    final routeEnd = json['routeEnd']?.toString().trim() ?? '';
    final routePoints = [
      if (routeStart.isNotEmpty) 'Điểm đầu: $routeStart',
      if (routeEnd.isNotEmpty) 'Điểm cuối: $routeEnd',
    ].join(' • ');

    return AvailableOption(
      id: json['busId']?.toString() ?? '',
      title: 'Tuyến xe: ${json['busNumber'] ?? ""}',
      subtitle: routePoints.isNotEmpty
          ? routePoints
          : json['routeDescription']?.toString(),
    );
  }

  factory AvailableOption.fromExtraJson(Map<String, dynamic> json) => AvailableOption(
        id: json['classId']?.toString() ?? '',
        title: json['className'] as String? ?? '',
        subtitle: '${json['subject'] ?? ""} • Lịch: ${json['scheduleDescription'] ?? ""}',
      );
}

class NotificationItem {
  final int notificationId;
  final String title;
  final String body;
  final bool isRead;
  final String? createdAt;
  final String type; // BILLING, ATTENDANCE, REQUEST, ANNOUNCEMENT, GENERAL

  const NotificationItem({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.type = 'GENERAL',
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      notificationId: json['notificationId'] is int
          ? json['notificationId'] as int
          : int.tryParse(json['notificationId']?.toString() ?? '0') ?? 0,
      title: json['title'] as String? ?? 'Thông báo',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? (json['read'] as bool? ?? false),
      createdAt: json['createdAt']?.toString(),
      type: json['type'] as String? ?? 'GENERAL',
    );
  }

  NotificationItem copyWith({
    int? notificationId,
    String? title,
    String? body,
    bool? isRead,
    String? createdAt,
    String? type,
  }) {
    return NotificationItem(
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
    );
  }
}



class StudentFaceFile {
  final int? faceFileId;
  final String? studentId;
  final String? studentName;
  final String? className;
  final String photoUrl;
  final int? fileSize;
  final bool isActive;
  final String? createdAt;

  const StudentFaceFile({
    this.faceFileId,
    this.studentId,
    this.studentName,
    this.className,
    required this.photoUrl,
    this.fileSize,
    this.isActive = true,
    this.createdAt,
  });

  factory StudentFaceFile.fromJson(Map<String, dynamic> json) {
    return StudentFaceFile(
      faceFileId: json['faceFileId'] is int
          ? json['faceFileId'] as int
          : int.tryParse(json['faceFileId']?.toString() ?? ''),
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString(),
      className: json['className']?.toString(),
      photoUrl: json['photoUrl']?.toString() ?? '',
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : int.tryParse(json['fileSize']?.toString() ?? ''),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class BusStopOption {
  final String stopId;
  final String stopName;
  final String stopAddress;
  final int stopOrder;
  final String estimatedTime;

  const BusStopOption({
    required this.stopId,
    required this.stopName,
    this.stopAddress = '',
    this.stopOrder = 1,
    this.estimatedTime = '',
  });

  factory BusStopOption.fromJson(Map<String, dynamic> json) => BusStopOption(
        stopId: (json['stopId'] ?? '').toString(),
        stopName: json['stopName'] as String? ?? 'Điểm dừng',
        stopAddress: json['stopAddress'] as String? ?? '',
        stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
        estimatedTime: json['estimatedTime'] as String? ?? '',
      );
}

class MealRegisterItem {
  final int registerId;
  final String studentId;
  final String? studentName;
  final String? studentCode;
  final String? className;
  final String? serviceId;
  final String? serviceName;
  final double? unitPrice;
  final String? registeredDate;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? statusLabel;
  final String? note;
  final String? parentName;
  final String? parentPhone;
  final DateTime? createdAt;

  const MealRegisterItem({
    required this.registerId,
    required this.studentId,
    this.studentName,
    this.studentCode,
    this.className,
    this.serviceId,
    this.serviceName,
    this.unitPrice,
    this.registeredDate,
    this.startDate,
    this.endDate,
    required this.status,
    this.statusLabel,
    this.note,
    this.parentName,
    this.parentPhone,
    this.createdAt,
  });

  factory MealRegisterItem.fromJson(Map<String, dynamic> json) => MealRegisterItem(
        registerId: (json['registerId'] as num?)?.toInt() ?? 0,
        studentId: (json['studentId'] ?? '').toString(),
        studentName: json['studentName'] as String?,
        studentCode: json['studentCode'] as String?,
        className: json['className'] as String?,
        serviceId: (json['serviceId'] ?? '').toString(),
        serviceName: json['serviceName'] as String? ?? 'Ăn sáng bán trú',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 450000.0,
        registeredDate: json['registeredDate'] as String?,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        status: (json['status'] ?? 'PENDING').toString(),
        statusLabel: json['statusLabel'] as String?,
        note: json['note'] as String?,
        parentName: json['parentName'] as String?,
        parentPhone: json['parentPhone'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      );
}

/// Parent-side models matching backend DTOs.

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
  bool get isPaid => status == 'PAID';

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

  const VietQrPayment({
    required this.qrDataUrl,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.referenceCode,
    this.deepLink,
  });

  factory VietQrPayment.fromJson(Map<String, dynamic> json) => VietQrPayment(
        qrDataUrl: json['paymentQrCode'] as String? ?? json['qrDataUrl'] as String? ?? '',
        bankName: json['bankCode'] as String? ?? json['bankName'] as String? ?? 'MB Bank',
        accountNumber: json['accountNumber'] as String? ?? '999988887777',
        accountName: json['accountName'] as String? ?? 'TRUONG MAM NON QUOC TE KIDPRO',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        referenceCode: json['invoiceCode'] as String? ?? json['referenceCode'] as String? ?? '',
        deepLink: json['deepLink'] as String?,
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

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'instructions': instructions,
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
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

class BiometricPurgeCertificate {
  final String studentId;
  final String studentName;
  final String certificateCode;
  final String hashSha256;
  final String purgedAt;
  final int deletedFaceVectorsCount;
  final String message;

  const BiometricPurgeCertificate({
    required this.studentId,
    required this.studentName,
    required this.certificateCode,
    required this.hashSha256,
    required this.purgedAt,
    required this.deletedFaceVectorsCount,
    required this.message,
  });

  factory BiometricPurgeCertificate.fromJson(Map<String, dynamic> json) =>
      BiometricPurgeCertificate(
        studentId: json['studentId']?.toString() ?? '',
        studentName: json['studentName'] as String? ?? '',
        certificateCode: json['certificateCode'] as String? ?? '',
        hashSha256: json['hashSha256'] as String? ?? '',
        purgedAt: json['purgedAt'] as String? ?? '',
        deletedFaceVectorsCount: json['deletedFaceVectorsCount'] as int? ?? 0,
        message: json['message'] as String? ?? '',
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

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        content: json['content'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}

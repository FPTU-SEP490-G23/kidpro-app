/// Parent-side models matching backend DTOs.

class Invoice {
  final String id;
  final String studentName;
  final String periodLabel;
  final double totalAmount;
  final double paidAmount;
  final String status; // PENDING, PAID, OVERDUE, DISPUTED
  final String? referenceCode;

  const Invoice({
    required this.id,
    required this.studentName,
    required this.periodLabel,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.referenceCode,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isPaid => status == 'PAID';

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as String,
        studentName: json['studentName'] as String? ?? '',
        periodLabel: json['periodLabel'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String,
        referenceCode: json['referenceCode'] as String?,
      );
}

class VietQrPayment {
  final String qrDataUrl; // base64 or URL to QR image
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
        qrDataUrl: json['qrDataUrl'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        referenceCode: json['referenceCode'] as String? ?? '',
        deepLink: json['deepLink'] as String?,
      );
}

class LeaveRequest {
  final String? id;
  final String studentId;
  final String reason;
  final DateTime leaveDate;

  const LeaveRequest({
    this.id,
    required this.studentId,
    required this.reason,
    required this.leaveDate,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'reason': reason,
        'leaveDate': leaveDate.toIso8601String().split('T').first,
      };
}

class MedicationRequest {
  final String studentId;
  final String medicineName;
  final String dosage;
  final String? note;
  final String? prescriptionImageUrl;

  const MedicationRequest({
    required this.studentId,
    required this.medicineName,
    required this.dosage,
    this.note,
    this.prescriptionImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'medicineName': medicineName,
        'dosage': dosage,
        if (note != null) 'note': note,
        if (prescriptionImageUrl != null)
          'prescriptionImageUrl': prescriptionImageUrl,
      };
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
        content: json['content'] as String? ?? '',
        sentAt: DateTime.parse(json['sentAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}

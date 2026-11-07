/// Người được phép đón trẻ và kết quả quét mặt khi trả trẻ (BR-022).
/// Dùng chung cho app phụ huynh (đăng ký ảnh) và app giáo viên (quét mặt).
class PickupPerson {
  final String personType; // PARENT | GUARDIAN
  final String? parentId;
  final int? guardianId;
  final String fullName;
  final String? relationship;
  final String? phoneNumber;
  /// false: bố mẹ / người giám hộ chính, bàn giao không cần quét mặt.
  final bool faceRequired;
  final bool faceRegistered;
  final String? facePhotoUrl;

  const PickupPerson({
    required this.personType,
    this.parentId,
    this.guardianId,
    required this.fullName,
    this.relationship,
    this.phoneNumber,
    this.faceRequired = true,
    this.faceRegistered = false,
    this.facePhotoUrl,
  });

  bool get isGuardian => personType == 'GUARDIAN';

  /// Khóa duy nhất để phân biệt người đón trong danh sách.
  String get key => isGuardian ? 'G$guardianId' : 'P$parentId';

  factory PickupPerson.fromJson(Map<String, dynamic> json) => PickupPerson(
        personType: json['personType'] as String? ?? 'PARENT',
        parentId: json['parentId']?.toString(),
        guardianId: (json['guardianId'] as num?)?.toInt(),
        fullName: json['fullName'] as String? ?? '',
        relationship: json['relationship'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        faceRequired: json['faceRequired'] as bool? ?? true,
        faceRegistered: json['faceRegistered'] as bool? ?? false,
        facePhotoUrl: json['facePhotoUrl'] as String?,
      );
}

class PickupFaceVerification {
  final String verificationId;
  final String personName;
  final bool hasReference;
  final bool matched;
  final double? similarity;
  final double? threshold;
  final String? referencePhotoUrl;
  final String message;

  const PickupFaceVerification({
    required this.verificationId,
    required this.personName,
    required this.hasReference,
    required this.matched,
    this.similarity,
    this.threshold,
    this.referencePhotoUrl,
    required this.message,
  });

  int? get percent => similarity == null ? null : (similarity! * 100).round();

  factory PickupFaceVerification.fromJson(Map<String, dynamic> json) => PickupFaceVerification(
        verificationId: json['verificationId'] as String,
        personName: json['personName'] as String? ?? '',
        hasReference: json['hasReference'] as bool? ?? false,
        matched: json['matched'] as bool? ?? false,
        similarity: (json['similarity'] as num?)?.toDouble(),
        threshold: (json['threshold'] as num?)?.toDouble(),
        referencePhotoUrl: json['referencePhotoUrl'] as String?,
        message: json['message'] as String? ?? '',
      );
}

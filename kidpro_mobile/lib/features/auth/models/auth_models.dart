/// Maps to backend LoginRequest / LoginResponse DTOs.

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class LoginResponse {
  final String token;
  final String type;
  final String userId;
  final String email;
  final String role;
  final String? fullName;

  const LoginResponse({
    required this.token,
    required this.type,
    required this.userId,
    required this.email,
    required this.role,
    this.fullName,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        type: json['type'] as String? ?? 'Bearer',
        userId: (json['userId'] ?? json['id'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        fullName: json['fullName'] as String?,
      );
}

/// Maps to backend UserResponseDto.
class UserProfile {
  final String id;
  final String email;
  final String role;
  final String? fullName;
  final String? phone;
  final String status;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phone,
    required this.status,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['userId'] ?? json['id'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String?,
        status: (json['status'] ?? 'ACTIVE') as String,
      );
}

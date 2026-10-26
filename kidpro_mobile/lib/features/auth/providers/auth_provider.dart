import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/features/auth/models/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  AuthStatus _status = AuthStatus.unauthenticated;
  UserProfile? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserProfile? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  
  bool get isParent {
    final r = _user?.role.toUpperCase() ?? '';
    return r == 'PARENT' || r == 'PHU_HUYNH' || r == 'ROLE_PARENT';
  }

  bool get isTeacher {
    final r = _user?.role.toUpperCase() ?? '';
    return r == 'TEACHER' || r == 'GIAO_VIEN' || r == 'ROLE_TEACHER';
  }

  /// Try to restore session from stored token.
  Future<void> tryAutoLogin() async {
    final token = await SecureStorageHelper.getAccessToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return;
    }
    try {
      final res = await _dio.get(ApiEndpoints.userMe);
      _user = UserProfile.fromJson(res.data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      final savedRole = await SecureStorageHelper.getRole();
      final savedUserId = await SecureStorageHelper.getUserId();
      if (savedRole != null && savedUserId != null) {
        _user = UserProfile(
          id: savedUserId,
          email: '',
          role: savedRole,
          status: 'ACTIVE',
        );
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
        await SecureStorageHelper.clearAll();
      }
    }
    notifyListeners();
  }

  /// Login with email + password.
  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.post(
        ApiEndpoints.login,
        data: LoginRequest(email: email, password: password).toJson(),
      );
      final loginResp = LoginResponse.fromJson(res.data);

      await SecureStorageHelper.saveAccessToken(loginResp.token);
      await SecureStorageHelper.saveRole(loginResp.role);
      await SecureStorageHelper.saveUserId(loginResp.userId);

      // Lưu trữ user profile từ LoginResponse của backend Spring Boot
      _user = UserProfile(
        id: loginResp.userId,
        email: loginResp.email,
        role: loginResp.role,
        fullName: loginResp.fullName,
        status: 'ACTIVE',
      );

      // Cập nhật thêm nếu endpoint /api/auth/me trả về dữ liệu chi tiết
      try {
        final profileRes = await _dio.get(ApiEndpoints.userMe);
        _user = UserProfile.fromJson(profileRes.data);
      } catch (_) {
        // Giữ _user đã trích xuất từ loginResp
      }

      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _loading = false;
      String msg = 'Không thể kết nối đến máy chủ. Vui lòng thử lại sau.';
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 400 || statusCode == 403) {
        msg = 'Tài khoản hoặc mật khẩu không chính xác';
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          msg = '${data['message']}';
        }
      } else if (e.response?.data is Map && e.response?.data['message'] != null) {
        msg = '${e.response?.data['message']}';
      }
      _error = msg;
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return false;
    } catch (e) {
      _loading = false;
      _error = 'Đã có lỗi xảy ra: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await SecureStorageHelper.clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

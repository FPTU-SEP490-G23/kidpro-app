import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/features/auth/models/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserProfile? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isParent => _user?.role == 'PHU_HUYNH';
  bool get isTeacher => _user?.role == 'GIAO_VIEN';

  /// Try to restore session from stored token.
  Future<void> tryAutoLogin() async {
    final token = await SecureStorageHelper.getAccessToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final res = await _dio.get(ApiEndpoints.userMe);
      _user = UserProfile.fromJson(res.data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      await SecureStorageHelper.clearAll();
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

      // Fetch full user profile
      final profileRes = await _dio.get(ApiEndpoints.userMe);
      _user = UserProfile.fromJson(profileRes.data);
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _loading = false;
      if (e.response?.statusCode == 401) {
        _error = 'Email hoặc mật khẩu không chính xác';
      } else {
        _error = 'Lỗi kết nối. Vui lòng thử lại.';
      }
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

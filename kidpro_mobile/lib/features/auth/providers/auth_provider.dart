import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/features/auth/models/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  AuthStatus _status = AuthStatus.authenticated;
  UserProfile? _user = const UserProfile(
    id: 'mock-teacher-1',
    email: 'giaovien@kidpro.edu.vn',
    fullName: 'Cô Thu Hương',
    role: 'GIAO_VIEN',
    status: 'ACTIVE',
  );
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserProfile? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isParent => _user?.role == 'PHU_HUYNH';
  bool get isTeacher => _user?.role == 'GIAO_VIEN';

  /// Thiết lập tài khoản giả lập để test nhanh không cần DB
  void setMockRole({required bool isTeacher}) {
    _status = AuthStatus.authenticated;
    _error = null;
    _user = isTeacher
        ? const UserProfile(
            id: 'mock-teacher-1',
            email: 'giaovien@kidpro.edu.vn',
            fullName: 'Cô Thu Hương',
            role: 'GIAO_VIEN',
            status: 'ACTIVE',
          )
        : const UserProfile(
            id: 'mock-parent-1',
            email: 'phuhuynh@kidpro.edu.vn',
            fullName: 'Nguyễn Văn Ba',
            role: 'PHU_HUYNH',
            status: 'ACTIVE',
          );
    notifyListeners();
  }

  /// Try to restore session from stored token.
  Future<void> tryAutoLogin() async {
    final token = await SecureStorageHelper.getAccessToken();
    if (token == null) {
      // Mặc định duy trì tài khoản giả lập để test offline không cần login
      if (_user == null) {
        setMockRole(isTeacher: true);
      }
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
      // Nếu backend chưa chạy, tự động đăng nhập giả lập để tiếp tục test
      setMockRole(isTeacher: !email.toLowerCase().contains('phuhuynh'));
      return true;
    }
  }

  Future<void> logout() async {
    await SecureStorageHelper.clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';

/// Dio HTTP client configured for KidPro backend.
class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;

  /// Ưu tiên `--dart-define=BASE_URL=http://<ip>:8080` (thiết bị thật qua Wi-Fi),
  /// mặc định 10.0.2.2 cho Android Emulator (trỏ về localhost của máy tính).
  static const _envBaseUrl = String.fromEnvironment('BASE_URL');
  static String get defaultHostUrl => _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://127.0.0.1:8080');

  String get baseUrl => dio.options.baseUrl;
  String get currentBaseUrl => dio.options.baseUrl;

  /// Tự động lấy URL của AI Backend (cổng 8000) dựa theo Host của Backend (cổng 8080)
  String get aiBaseUrl {
    try {
      final uri = Uri.parse(dio.options.baseUrl);
      if (uri.host.isNotEmpty) {
        final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
        return '$scheme://${uri.host}:8000';
      }
    } catch (_) {}
    return 'http://192.168.10.51:8000';
  }

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: defaultHostUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    _loadSavedBaseUrl();
  }

  Future<void> init() async => _loadSavedBaseUrl();

  Future<void> _loadSavedBaseUrl() async {
    final saved = await SecureStorageHelper.getCustomBaseUrl();
    if (saved != null && saved.isNotEmpty && saved != 'http://192.168.10.131:8080' && saved != 'http://192.168.10.125:8080' && saved != 'http://192.168.1.2:8080') {
      dio.options.baseUrl = saved;
    } else {
      dio.options.baseUrl = defaultHostUrl;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    String formatted = newUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    dio.options.baseUrl = formatted;
    await SecureStorageHelper.saveCustomBaseUrl(formatted);
  }

  factory ApiClient() => _instance ??= ApiClient._();
}

/// Injects JWT Bearer token into every request.
/// On 401, attempts to refresh the token once before failing.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth header for public endpoints
    final publicPaths = [
      ApiEndpoints.login,
      ApiEndpoints.googleLogin,
      ApiEndpoints.register,
      ApiEndpoints.refreshToken,
    ];
    if (!publicPaths.contains(options.path)) {
      final token = await SecureStorageHelper.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorageHelper.getRefreshToken();
        if (refreshToken == null) {
          await SecureStorageHelper.clearAll();
          return handler.reject(err);
        }

        final response = await Dio(BaseOptions(
          baseUrl: _dio.options.baseUrl,
        )).post(ApiEndpoints.refreshToken, data: {
          'refreshToken': refreshToken,
        });

        final newToken = response.data['token'] as String;
        await SecureStorageHelper.saveAccessToken(newToken);

        // Retry the original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch(opts);
        return handler.resolve(retryResponse);
      } on DioException {
        // Refresh failed — force logout
        await SecureStorageHelper.clearAll();
        return handler.reject(err);
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

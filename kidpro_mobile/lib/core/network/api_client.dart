import 'package:dio/dio.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';

/// Dio HTTP client configured for KidPro backend.
class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;

  ApiClient._() {
    dio = Dio(BaseOptions(
      // ponytail: hardcoded localhost, swap via --dart-define=BASE_URL=... for staging/prod
      baseUrl: const String.fromEnvironment('BASE_URL',
          defaultValue: 'http://127.0.0.1:8080'),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(dio));
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

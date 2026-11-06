import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage for JWT tokens.
class SecureStorageHelper {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'user_role';
  static const _userIdKey = 'user_id';

  // Access Token
  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessKey, value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: _accessKey);

  // Refresh Token
  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshKey);

  // Role
  static Future<void> saveRole(String role) =>
      _storage.write(key: _roleKey, value: role);

  static Future<String?> getRole() =>
      _storage.read(key: _roleKey);

  // User ID
  static Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  static Future<String?> getUserId() =>
      _storage.read(key: _userIdKey);

  // Custom Base URL (IP/Host)
  static const _baseUrlKey = 'custom_base_url';
  static Future<void> saveCustomBaseUrl(String url) =>
      _storage.write(key: _baseUrlKey, value: url);

  static Future<String?> getCustomBaseUrl() =>
      _storage.read(key: _baseUrlKey);

  // Custom AI Server URL
  static const _aiServerUrlKey = 'custom_ai_server_url';
  static Future<void> saveAiServerUrl(String url) =>
      _storage.write(key: _aiServerUrlKey, value: url);

  static Future<String?> getAiServerUrl() =>
      _storage.read(key: _aiServerUrlKey);

  // Clear all on logout
  static Future<void> clearAll() async {
    final customUrl = await getCustomBaseUrl();
    final customAiUrl = await getAiServerUrl();
    await _storage.deleteAll();
    if (customUrl != null) {
      await saveCustomBaseUrl(customUrl); // Preserve server IP across logouts
    }
    if (customAiUrl != null) {
      await saveAiServerUrl(customAiUrl); // Preserve AI Server URL across logouts
    }
  }
}

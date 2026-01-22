import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data.
///
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (with AES encryption)
/// - Web: Falls back to in-memory storage (not persistent)
///
/// Use this for:
/// - Auth tokens
/// - API keys
/// - Sensitive user preferences
///
/// DO NOT use for:
/// - Large data (use Hive or SQLite instead)
/// - Non-sensitive preferences (use SharedPreferences)
class SecureStorageService {
  // Singleton instance
  static final SecureStorageService instance = SecureStorageService._();

  // Private constructor
  SecureStorageService._();

  // Android-specific security options
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'nba_predictions_secure',
    preferencesKeyPrefix: 'nba_',
  );

  // iOS-specific security options
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'nba_predictions',
  );

  // Storage instance
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  // Storage keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keySessionExpiry = 'session_expiry';
  static const String _keyLastLogin = 'last_login';

  // ============================================================================
  // AUTH TOKEN MANAGEMENT
  // ============================================================================

  /// Store authentication token securely.
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
    if (kDebugMode) {
      print('SecureStorage: Auth token saved');
    }
  }

  /// Retrieve stored authentication token.
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  /// Delete authentication token.
  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }

  /// Store refresh token securely.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Retrieve stored refresh token.
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Delete refresh token.
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================

  /// Save user ID for session tracking.
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Get stored user ID.
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Save session expiry timestamp.
  Future<void> saveSessionExpiry(DateTime expiry) async {
    await _storage.write(
      key: _keySessionExpiry,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  /// Check if session is expired.
  Future<bool> isSessionExpired() async {
    final expiryStr = await _storage.read(key: _keySessionExpiry);
    if (expiryStr == null) return true;

    try {
      final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  /// Record last login time.
  Future<void> recordLogin() async {
    await _storage.write(
      key: _keyLastLogin,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// Get last login time.
  Future<DateTime?> getLastLogin() async {
    final lastLoginStr = await _storage.read(key: _keyLastLogin);
    if (lastLoginStr == null) return null;

    try {
      return DateTime.parse(lastLoginStr);
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // GENERIC SECURE STORAGE
  // ============================================================================

  /// Store a value securely by key.
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value by key.
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a value by key.
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Check if a key exists.
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  // ============================================================================
  // CLEAR ALL DATA
  // ============================================================================

  /// Clear all secure storage data.
  ///
  /// Call this on logout to remove all sensitive data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
    if (kDebugMode) {
      print('SecureStorage: All data cleared');
    }
  }

  /// Clear only authentication-related data.
  Future<void> clearAuthData() async {
    await Future.wait([
      deleteAuthToken(),
      deleteRefreshToken(),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keySessionExpiry),
    ]);
    if (kDebugMode) {
      print('SecureStorage: Auth data cleared');
    }
  }
}

/// Extension for easy access throughout the app.
extension SecureStorage on Object {
  SecureStorageService get secureStorage => SecureStorageService.instance;
}

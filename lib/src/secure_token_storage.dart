import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth.dart';

/// Secure token storage implementation using flutter_secure_storage
/// Stores tokens in encrypted format with platform-specific secure storage:
/// - iOS: Keychain
/// - Android: Keystore
class SecureTokenStorage implements TokenStorage {
  static const String _keyAccessToken = 'keemos_access_token';
  static const String _keyRefreshToken = 'keemos_refresh_token';
  static const String _keyTokenExpiry = 'keemos_token_expiry';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_this_device_this_app_only,
              ),
            );

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<void> saveTokenExpiry(int expiresIn) async {
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
    await _storage.write(key: _keyTokenExpiry, value: expiryTime.toString());
  }

  @override
  Future<String?> readAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  @override
  Future<String?> readRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<int?> readTokenExpiry() async {
    final value = await _storage.read(key: _keyTokenExpiry);
    return value != null ? int.parse(value) : null;
  }

  Future<bool> isAccessTokenExpired() async {
    final expiry = await readTokenExpiry();
    if (expiry == null) return true;
    // Consider token expired if less than 60 seconds remaining
    return DateTime.now().millisecondsSinceEpoch > (expiry - 60000);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyTokenExpiry),
    ]);
  }

  /// Clears only tokens, preserves other user preferences if needed
  Future<void> clearTokensOnly() async {
    await clear();
  }

  /// Get all stored tokens (useful for debugging)
  Future<Map<String, String?>> getAllTokens() async {
    return {
      'access_token': await readAccessToken(),
      'refresh_token': await readRefreshToken(),
    };
  }
}

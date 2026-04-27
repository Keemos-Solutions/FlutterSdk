import 'dart:async';
import 'package:dio/dio.dart';
import 'models.dart';
import 'generated/auth_models.dart';

/// Abstraction for token storage so core package remains platform-agnostic.
abstract class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<void> saveTokenExpiry(int expiresIn);
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<int?> readTokenExpiry();
  Future<bool> isAccessTokenExpired();
  Future<void> clear();
}

/// Simple in-memory storage (default) — replace with secure storage in Flutter example.
class InMemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;
  int? _expiryMs;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _expiryMs = null;
  }

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<int?> readTokenExpiry() async => _expiryMs;

  @override
  Future<bool> isAccessTokenExpired() async {
    if (_expiryMs == null) return true;
    return DateTime.now().millisecondsSinceEpoch > (_expiryMs! - 60000);
  }

  @override
  Future<void> saveAccessToken(String token) async {
    _access = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _refresh = token;
  }

  @override
  Future<void> saveTokenExpiry(int expiresIn) async {
    _expiryMs = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
  }
}

class ChangePasswordNotAllowedException implements Exception {
  final String message;

  ChangePasswordNotAllowedException([
    this.message = 'Change password is not available for this account. '
        'Social-login accounts must set a manual password first.',
  ]);

  @override
  String toString() => message;
}

class AuthManager {
  final Dio _dio;
  final TokenStorage storage;
  late StreamSubscription? _tokenRefreshTimer;

  /// Completer to prevent concurrent refresh requests
  Completer<bool>? _refreshInProgress;

  AuthManager({Dio? dio, TokenStorage? storage})
      : _dio = dio ?? Dio(),
        storage = storage ?? InMemoryTokenStorage() {
    _dio.options.baseUrl = 'https://api.keemos.vn';
  }

  /// Login with email and password
  /// Saves both access and refresh tokens with expiration time
  Future<AuthToken> login(String email, String password) async {
    final req = LoginRequest(email: email, password: password);
    final resp = await _dio.post('/api/v1/auth/login', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    final tokenData = body['data'] ?? body;

    // Parse both tokens from response
    final authToken = AuthToken.fromJson(tokenData['tokens'] ?? tokenData);

    // Save tokens
    await storage.saveAccessToken(authToken.accessToken);
    if (authToken.refreshToken != null) {
      await storage.saveRefreshToken(authToken.refreshToken!);
    }
    if (authToken.expiresIn != null) {
      await storage.saveTokenExpiry(authToken.expiresIn!);
    }

    return authToken;
  }

  /// Social login (Google, Facebook, Apple)
  Future<AuthToken> socialLogin(String provider, String token) async {
    final req = SocialProviderRequest(provider: provider, token: token);
    final resp = await _dio.post('/api/v1/auth/social-login', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    final tokenData = body['data'] ?? body;

    final authToken = AuthToken.fromJson(tokenData['tokens'] ?? tokenData);

    await storage.saveAccessToken(authToken.accessToken);
    if (authToken.refreshToken != null) {
      await storage.saveRefreshToken(authToken.refreshToken!);
    }
    if (authToken.expiresIn != null) {
      await storage.saveTokenExpiry(authToken.expiresIn!);
    }

    return authToken;
  }

  /// Logout and clear all stored tokens
  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await storage.clear();
  }

  /// Get current access token
  Future<String?> getAccessToken() => storage.readAccessToken();

  /// Set access token without login (e.g., from saved state)
  /// Returns true if token is set successfully
  Future<bool> setAccessToken(String token) async {
    await storage.saveAccessToken(token);
    return true;
  }

  /// Get refresh token
  Future<String?> getRefreshToken() => storage.readRefreshToken();

  /// Link a social account (Google/Facebook/Apple) to current authenticated user.
  ///
  /// Requires a valid access token. If access token is expired, this method
  /// will try one refresh and retry once.
  Future<void> socialLink({
    required String provider,
    required String token,
  }) async {
    final access = await storage.readAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError('No access token found. Login is required before socialLink.');
    }

    final payload = SocialProviderRequest(provider: provider, token: token).toJson();

    Future<Response<dynamic>> send(String jwt) {
      return _dio.post(
        '/api/v1/auth/social-link',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      );
    }

    try {
      await send(access);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await tryRefresh();
        if (refreshed) {
          final refreshedAccess = await storage.readAccessToken();
          if (refreshedAccess != null && refreshedAccess.isNotEmpty) {
            await send(refreshedAccess);
            return;
          }
        }
      }
      rethrow;
    }
  }

  /// Change password for current authenticated user.
  ///
  /// Requires a valid access token. If the token is expired, this method will
  /// try one refresh and retry once. Backend may return HTTP 400 for social
  /// accounts that have never set a manual password.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final access = await storage.readAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError('No access token found. Login is required before changePassword.');
    }

    final payload = ChangePasswordRequest(
      oldPassword: oldPassword,
      newPassword: newPassword,
    ).toJson();

    Future<Response<dynamic>> send(String token) {
      return _dio.post(
        '/api/v1/auth/change-password',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    try {
      await send(access);
      return;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 400 && _looksLikeSocialOnlyPasswordCase(e.response?.data)) {
        throw ChangePasswordNotAllowedException();
      }

      if (statusCode == 401) {
        final refreshed = await tryRefresh();
        if (refreshed) {
          final refreshedAccess = await storage.readAccessToken();
          if (refreshedAccess != null && refreshedAccess.isNotEmpty) {
            await send(refreshedAccess);
            return;
          }
        }
      }

      rethrow;
    }
  }

  /// Refresh access token using refresh token
  /// Prevents concurrent refresh requests using Completer
  Future<bool> tryRefresh() async {
    // If refresh is already in progress, wait for it to complete
    if (_refreshInProgress != null) {
      return _refreshInProgress!.future;
    }

    final refresh = await storage.readRefreshToken();
    if (refresh == null) return false;

    _refreshInProgress = Completer<bool>();

    try {
      final resp = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(
          validateStatus: (status) {
            // Don't throw on 401, we'll handle it
            return status != null && status < 500;
          },
        ),
      );

      final statusCode = resp.statusCode ?? 200;
      if (statusCode == 401) {
        await storage.clear();
        _refreshInProgress!.complete(false);
        return false;
      }

      final body = resp.data as Map<String, dynamic>;
      final tokenData = body['data'] ?? body;
      final authToken = AuthToken.fromJson(tokenData['tokens'] ?? tokenData);

      await storage.saveAccessToken(authToken.accessToken);
      if (authToken.refreshToken != null) {
        await storage.saveRefreshToken(authToken.refreshToken!);
      }
      if (authToken.expiresIn != null) {
        await storage.saveTokenExpiry(authToken.expiresIn!);
      }

      _refreshInProgress!.complete(true);
      return true;
    } catch (e) {
      await storage.clear();
      _refreshInProgress!.complete(false);
      return false;
    } finally {
      _refreshInProgress = null;
    }
  }

  /// Check if access token is expired
  Future<bool> isTokenExpired() => storage.isAccessTokenExpired();

  /// Cleanup resources
  void dispose() {
    _tokenRefreshTimer?.cancel();
  }

  bool _looksLikeSocialOnlyPasswordCase(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) return false;
    final directMessage = responseData['message']?.toString().toLowerCase() ?? '';
    final dataMessage = (responseData['data'] is Map<String, dynamic>)
        ? (responseData['data']['message']?.toString().toLowerCase() ?? '')
        : '';
    final msg = '$directMessage $dataMessage';
    return msg.contains('social') ||
        msg.contains('google') ||
        msg.contains('facebook') ||
        msg.contains('apple') ||
        msg.contains('manual password') ||
        msg.contains('set password');
  }
}

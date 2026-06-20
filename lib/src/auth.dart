import 'dart:async';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    _expiryMs =
        DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
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
  Timer? _autoRefreshTimer;

  /// Completer to prevent concurrent refresh requests
  Completer<bool>? _refreshInProgress;

  // Cache fields to prevent write-to-read delay and performance issues
  String? _accessTokenCache;
  String? _refreshTokenCache;
  int? _tokenExpiryCache;
  bool _isAuthFailed = false;

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyKratosSessionToken = 'keemos_kratos_session_token';
  String? _kratosSessionTokenCache;
  String? _recoveryFlowIdCache;

  Future<void> _saveKratosSessionToken(String token) async {
    _kratosSessionTokenCache = token;
    await _secureStorage.write(key: _keyKratosSessionToken, value: token);
  }

  Future<String?> _getKratosSessionToken() async {
    if (_kratosSessionTokenCache != null) return _kratosSessionTokenCache;
    _kratosSessionTokenCache = await _secureStorage.read(key: _keyKratosSessionToken);
    return _kratosSessionTokenCache;
  }

  Future<void> _clearKratosSessionToken() async {
    _kratosSessionTokenCache = null;
    await _secureStorage.delete(key: _keyKratosSessionToken);
  }

  Future<String?> _getAccessToken() async {
    if (_accessTokenCache != null) return _accessTokenCache;
    _accessTokenCache = await storage.readAccessToken();
    return _accessTokenCache;
  }

  Future<String?> _getRefreshToken() async {
    if (_refreshTokenCache != null) return _refreshTokenCache;
    _refreshTokenCache = await storage.readRefreshToken();
    return _refreshTokenCache;
  }

  Future<int?> _getTokenExpiry() async {
    if (_tokenExpiryCache != null) return _tokenExpiryCache;
    _tokenExpiryCache = await storage.readTokenExpiry();
    return _tokenExpiryCache;
  }

  Future<bool> _isTokenExpired() async {
    final expiry = await _getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().millisecondsSinceEpoch > (expiry - 60000);
  }

  AuthManager({Dio? dio, TokenStorage? storage})
      : _dio = dio ?? Dio(),
        storage = storage ?? InMemoryTokenStorage() {
    _dio.options.baseUrl = 'https://api.keemos.vn';
    _setupInterceptors();
    unawaited(_restoreAutoRefresh());
  }

  /// Setup Dio interceptors for automatic token refresh on 401
  void _setupInterceptors() {
    // Request interceptor: Add Authorization header with access token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, handler) async {
          final accessToken = await _getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
      ),
    );

    // Error interceptor: Handle 401 by refreshing token and retrying
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized errors by attempting token refresh
          // Skip retry for refresh endpoint itself to prevent infinite loop
          final isRefreshEndpoint =
              error.requestOptions.path.contains('/auth/refresh');
          final alreadyRetried =
              error.requestOptions.extra['_refreshed_token'] == true;

          // Nếu đã xác định xác thực thất bại hoặc chưa đăng nhập, bỏ qua việc gọi tryRefresh
          if (_isAuthFailed) {
            return handler.next(error);
          }

          if (error.response?.statusCode == 401 &&
              !isRefreshEndpoint &&
              !alreadyRetried) {
            try {
              final refreshed = await tryRefresh();
              if (refreshed) {
                // Mark request as refreshed to prevent infinite retries
                error.requestOptions.extra['_refreshed_token'] = true;

                // Retry the original request with refreshed token
                return handler.resolve(
                  await _dio.request(
                    error.requestOptions.path,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                    options: Options(
                      method: error.requestOptions.method,
                      headers: error.requestOptions.headers,
                      extra: error.requestOptions.extra,
                    ),
                  ),
                );
              }
            } catch (_) {
              // Refresh failed, pass through the original error
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Login with email and password
  /// Saves both access and refresh tokens with expiration time
  Future<AuthToken> login(
    String email,
    String password, {
    String? deviceName,
  }) async {
    final req = LoginRequest(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    final resp = await _dio.post('/api/v1/auth/login', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    final authToken = _parseAuthToken(body);
    await _persistAuthToken(authToken);
    return authToken;
  }

  /// Register with email and password. Saves tokens when returned by the API.
  Future<AuthToken> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';

    // Bước 1: Khởi tạo Registration Flow trên Kratos
    final flowResp = await _dio.get(
      '$baseDomain/kratos/self-service/registration/api',
      options: Options(
        headers: {'Accept': 'application/json'},
      ),
    );
    final flowBody = flowResp.data as Map<String, dynamic>;
    final flowId = flowBody['id'] as String;

    // Bước 2: Gửi thông tin đăng ký lên Kratos
    final registrationResp = await _dio.post(
      '$baseDomain/kratos/self-service/registration',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'password',
        'traits': {
          'email': email,
          'full_name': fullName ?? email.split('@').first,
        },
        'password': password,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    final registrationBody = registrationResp.data as Map<String, dynamic>;
    final sessionToken = registrationBody['session_token'] as String;

    // Lưu Kratos Session Token
    await _saveKratosSessionToken(sessionToken);

    // Bước 3: Đổi Kratos Session lấy Keemos JWT
    final sessionResp = await _dio.get(
      '$baseDomain/api/v1/auth/session/kratos',
      options: Options(
        headers: {
          'Cookie': 'ory_kratos_session=$sessionToken',
          'Authorization': 'Bearer $sessionToken',
          'X-Session-Token': sessionToken,
          'Accept': 'application/json',
        },
      ),
    );
    final sessionBody = sessionResp.data as Map<String, dynamic>;
    final authToken = _parseAuthToken(sessionBody);
    await _persistAuthToken(authToken);

    return authToken;
  }

  /// Request a password-reset OTP for [email].
  Future<void> forgotPassword(String email) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';

    // Bước 1: Khởi tạo recovery flow
    final flowResp = await _dio.get(
      '$baseDomain/kratos/self-service/recovery/api',
      options: Options(
        headers: {'Accept': 'application/json'},
      ),
    );
    final flowBody = flowResp.data as Map<String, dynamic>;
    final flowId = flowBody['id'] as String;

    // Bước 2: Gửi email yêu cầu nhận mã khôi phục
    await _dio.post(
      '$baseDomain/kratos/self-service/recovery',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'code',
        'email': email,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _recoveryFlowIdCache = flowId;
  }

  /// Reset password using OTP from email.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';

    var flowId = _recoveryFlowIdCache;
    if (flowId == null || flowId.isEmpty) {
      final flowResp = await _dio.get(
        '$baseDomain/kratos/self-service/recovery/api',
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      final flowBody = flowResp.data as Map<String, dynamic>;
      flowId = flowBody['id'] as String;
    }

    // Bước 3: Gửi mã OTP khôi phục nhận được từ email
    final submitOtpResp = await _dio.post(
      '$baseDomain/kratos/self-service/recovery',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'code',
        'code': otp,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    final submitOtpBody = submitOtpResp.data as Map<String, dynamic>;
    final tempSessionToken = submitOtpBody['session_token'] as String;

    // Bước 4: Đặt lại mật khẩu mới bằng settings flow với session token tạm thời này
    final settingsFlowResp = await _dio.get(
      '$baseDomain/kratos/self-service/settings/api',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'X-Session-Token': tempSessionToken,
        },
      ),
    );
    final settingsFlowBody = settingsFlowResp.data as Map<String, dynamic>;
    final settingsFlowId = settingsFlowBody['id'] as String;

    await _dio.post(
      '$baseDomain/kratos/self-service/settings',
      queryParameters: {'flow': settingsFlowId},
      data: {
        'method': 'password',
        'password': newPassword,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Session-Token': tempSessionToken,
        },
      ),
    );
    _recoveryFlowIdCache = null;
  }

  /// Social login (Google, Facebook, Apple)
  Future<AuthToken> socialLogin(String provider, String token) async {
    if (provider == 'google') {
      dev.log('[SDK Auth] Starting Kratos Google SSO flow');
      final baseUri = Uri.parse(_dio.options.baseUrl);
      final baseDomain = '${baseUri.scheme}://${baseUri.authority}';

      // Bước 1: Khởi tạo Login Flow trên Kratos
      dev.log('[SDK Auth] Step 1: Initialize Kratos login flow');
      final flowResp = await _dio.get(
        '$baseDomain/kratos/self-service/login/api',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      final flowBody = flowResp.data as Map<String, dynamic>;
      final flowId = flowBody['id'] as String;

      // Bước 2: Submit Google IDToken lên Kratos
      dev.log('[SDK Auth] Step 2: Submit Google IDToken to Kratos. Flow: $flowId');
      final submitResp = await _dio.post(
        '$baseDomain/kratos/self-service/login',
        queryParameters: {'flow': flowId},
        data: {
          'method': 'oidc',
          'provider': 'google',
          'id_token': token,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      final submitBody = submitResp.data as Map<String, dynamic>;
      final sessionToken = submitBody['session_token'] as String;
      await _saveKratosSessionToken(sessionToken);

      // Bước 3: Đổi Kratos Session lấy Keemos JWT
      dev.log('[SDK Auth] Step 3: Exchange Kratos Session for Keemos JWT');
      final sessionResp = await _dio.get(
        '$baseDomain/api/v1/auth/session/kratos',
        options: Options(
          headers: {
            'Cookie': 'ory_kratos_session=$sessionToken',
            'Authorization': 'Bearer $sessionToken',
            'X-Session-Token': sessionToken,
            'Accept': 'application/json',
          },
        ),
      );
      final sessionBody = sessionResp.data as Map<String, dynamic>;
      final authToken = _parseAuthToken(sessionBody);

      await _persistAuthToken(authToken);
      return authToken;
    } else {
      final req = SocialProviderRequest(provider: provider, token: token);
      final resp =
          await _dio.post('/api/v1/auth/social-login', data: req.toJson());
      final body = resp.data as Map<String, dynamic>;
      final authToken = _parseAuthToken(body);

      await _persistAuthToken(authToken);

      return authToken;
    }
  }

  /// Logout and clear all stored tokens
  Future<void> logout() async {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;

    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';
    final kratosToken = await _getKratosSessionToken();

    if (kratosToken != null && kratosToken.isNotEmpty) {
      try {
        await _dio.delete(
          '$baseDomain/kratos/self-service/logout/api',
          data: {
            'session_token': kratosToken,
          },
          options: Options(
            headers: {
              'Accept': 'application/json',
            },
          ),
        );
      } catch (e) {
        dev.log('[SDK Auth] Kratos logout error: $e');
      }
      await _clearKratosSessionToken();
    }

    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await _clearTokensSafely();
  }

  /// Get current access token
  Future<String?> getAccessToken() => _getAccessToken();

  /// Set access token without login (e.g., from saved state)
  /// Returns true if token is set successfully
  Future<bool> setAccessToken(String token) async {
    _accessTokenCache = token;
    await storage.saveAccessToken(token);
    return true;
  }

  /// Get refresh token
  Future<String?> getRefreshToken() => _getRefreshToken();

  /// Link a social account (Google/Facebook/Apple) to current authenticated user.
  ///
  /// Requires a valid access token. If access token is expired, this method
  /// will try one refresh and retry once.
  Future<void> socialLink({
    required String provider,
    required String token,
  }) async {
    final access = await _getAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError(
          'No access token found. Login is required before socialLink.');
    }

    final payload =
        SocialProviderRequest(provider: provider, token: token).toJson();

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
          final refreshedAccess = await _getAccessToken();
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
  /// Requires a valid Kratos session token or access token.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';
    final kratosToken = await _getKratosSessionToken();

    if (kratosToken == null || kratosToken.isEmpty) {
      dev.log('[SDK Auth] Kratos token not found. Falling back to core-api changePassword');
      final access = await _getAccessToken();
      if (access == null || access.isEmpty) {
        throw StateError('No access token found. Login is required before changePassword.');
      }

      final payload = ChangePasswordRequest(
        oldPassword: oldPassword,
        newPassword: newPassword,
      ).toJson();

      try {
        await _dio.post(
          '/api/v1/auth/change-password',
          data: payload,
          options: Options(headers: {'Authorization': 'Bearer $access'}),
        );
        return;
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 400 && _looksLikeSocialOnlyPasswordCase(e.response?.data)) {
          throw ChangePasswordNotAllowedException();
        }
        rethrow;
      }
    }

    // Bước 1: Khởi tạo settings flow
    final flowResp = await _dio.get(
      '$baseDomain/kratos/self-service/settings/api',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'X-Session-Token': kratosToken,
        },
      ),
    );
    final flowBody = flowResp.data as Map<String, dynamic>;
    final flowId = flowBody['id'] as String;

    // Bước 2: Thực hiện đổi mật khẩu
    await _dio.post(
      '$baseDomain/kratos/self-service/settings',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'password',
        'password': newPassword,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Session-Token': kratosToken,
        },
      ),
    );
  }

  /// Update user profile (full name, avatar, etc.) via Kratos Settings Flow.
  Future<void> updateProfile({
    required String email,
    required String fullName,
    String? avatarUrl,
  }) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';
    final kratosToken = await _getKratosSessionToken();
    if (kratosToken == null || kratosToken.isEmpty) {
      throw StateError('Kratos session token not found. Login/Registration via Kratos is required.');
    }

    // Bước 1: Khởi tạo settings flow
    final flowResp = await _dio.get(
      '$baseDomain/kratos/self-service/settings/api',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'X-Session-Token': kratosToken,
        },
      ),
    );
    final flowBody = flowResp.data as Map<String, dynamic>;
    final flowId = flowBody['id'] as String;

    // Bước 2: Thực hiện cập nhật profile
    final traits = {
      'email': email,
      'full_name': fullName,
    };
    if (avatarUrl != null) {
      traits['avatar_url'] = avatarUrl;
    }

    await _dio.post(
      '$baseDomain/kratos/self-service/settings',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'profile',
        'traits': traits,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Session-Token': kratosToken,
        },
      ),
    );
  }

  /// Verify email address using the OTP code received from Kratos.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final baseDomain = '${baseUri.scheme}://${baseUri.authority}';

    // Bước 1: Khởi tạo verification flow
    final flowResp = await _dio.get(
      '$baseDomain/kratos/self-service/verification/api',
      options: Options(
        headers: {'Accept': 'application/json'},
      ),
    );
    final flowBody = flowResp.data as Map<String, dynamic>;
    final flowId = flowBody['id'] as String;

    // Bước 2: Gửi mã xác minh
    await _dio.post(
      '$baseDomain/kratos/self-service/verification',
      queryParameters: {'flow': flowId},
      data: {
        'method': 'code',
        'email': email,
        'code': code,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Fetch current authenticated user's profile.
  /// Will attempt one token refresh on 401 and retry.
  Future<UserProfile> getUserProfile() async {
    final access = await _getAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError(
          'No access token found. Login is required before getUserProfile.');
    }

    Future<Response<dynamic>> send(String token) {
      return _dio.get(
        '/api/v1/auth/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    try {
      final resp = await send(access);
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] ?? body;
      return UserProfile.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await tryRefresh();
        if (refreshed) {
          final refreshedAccess = await _getAccessToken();
          if (refreshedAccess != null && refreshedAccess.isNotEmpty) {
            final resp = await send(refreshedAccess);
            final body = resp.data as Map<String, dynamic>;
            final data = body['data'] ?? body;
            return UserProfile.fromJson(data as Map<String, dynamic>);
          }
        }
      }
      rethrow;
    }
  }

  /// Update arbitrary app-level settings for the current authenticated user.
  /// `settings` may be any JSON-serializable map.
  /// Will attempt one token refresh on 401 and retry.
  Future<Map<String, dynamic>> updateAppSettings(
      Map<String, dynamic> settings) async {
    final access = await _getAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError(
          'No access token found. Login is required before updateAppSettings.');
    }

    Future<Response<dynamic>> send(String token) {
      return _dio.patch(
        '/api/v1/auth/app-settings',
        data: {'settings': settings},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    try {
      final resp = await send(access);
      final body = resp.data as Map<String, dynamic>;
      return (body['data'] ?? body) as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await tryRefresh();
        if (refreshed) {
          final refreshedAccess = await _getAccessToken();
          if (refreshedAccess != null && refreshedAccess.isNotEmpty) {
            final resp = await send(refreshedAccess);
            final body = resp.data as Map<String, dynamic>;
            return (body['data'] ?? body) as Map<String, dynamic>;
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
    final inProgress = _refreshInProgress;
    if (inProgress != null) {
      dev.log('[SDK Auth #${identityHashCode(this)}] tryRefresh() already in progress, waiting...');
      return inProgress.future;
    }

    final completer = Completer<bool>();
    _refreshInProgress = completer;

    try {
      // Kiểm tra xem có thực thể khác đã làm mới token thành công trước đó chưa
      final latestAccess = await storage.readAccessToken();
      if (latestAccess != null && latestAccess.isNotEmpty && latestAccess != _accessTokenCache) {
        final expired = await storage.isAccessTokenExpired();
        if (!expired) {
          dev.log('[SDK Auth #${identityHashCode(this)}] Another instance already refreshed token. Syncing cache...');
          _accessTokenCache = latestAccess;
          _refreshTokenCache = await storage.readRefreshToken();
          _tokenExpiryCache = await storage.readTokenExpiry();
          _scheduleAutoRefresh(_tokenExpiryCache);
          return _completeRefresh(completer, true);
        }
      }

      // Kiểm tra xem token hiện tại đã thực sự hết hạn chưa.
      // Nếu token vẫn còn hạn, lỗi 401 của API không phải do hết hạn token.
      // Bỏ qua refresh để tránh tạo vòng lặp spam server vô ích.
      final isExpired = await _isTokenExpired();
      if (!isExpired) {
        dev.log('[SDK Auth #${identityHashCode(this)}] Token is still valid. Skipping refresh to prevent spam.');
        return _completeRefresh(completer, false);
      }

      // Luôn đọc trực tiếp từ storage để tránh cache RAM bị lệch pha với storage chung
      _refreshTokenCache = await storage.readRefreshToken();
      final refresh = _refreshTokenCache;
      dev.log('[SDK Auth #${identityHashCode(this)}] tryRefresh() called. Stored refresh token length: ${refresh?.length ?? 0}');
      if (refresh == null || refresh.isEmpty) {
        dev.log('[SDK Auth #${identityHashCode(this)}] No refresh token available, skipping refresh.');
        return _completeRefresh(completer, false);
      }

      dev.log('[SDK Auth #${identityHashCode(this)}] Sending POST /api/v1/auth/refresh...');
      final resp = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(
          validateStatus: (status) {
            // Nhận tất cả mã lỗi HTTP dưới 500 để tự xử lý lỗi Client (4xx)
            return status != null && status < 500;
          },
        ),
      );

      final statusCode = resp.statusCode ?? 200;
      dev.log('[SDK Auth #${identityHashCode(this)}] POST /api/v1/auth/refresh response status: $statusCode');
      // Nếu là lỗi xác thực phía Client (400 Bad Request, 401 Unauthorized, 403 Forbidden...)
      // thì chứng tỏ refresh token đã hết hạn hoặc không hợp lệ, cần xóa sạch token.
      if (statusCode >= 400 && statusCode < 500) {
        dev.log('[SDK Auth #${identityHashCode(this)}] Auth failure (4xx). Clearing tokens to stop loop.');
        await _clearTokensSafely();
        return _completeRefresh(completer, false);
      }

      final body = resp.data as Map<String, dynamic>;
      final authToken = _parseAuthToken(body);

      dev.log('[SDK Auth #${identityHashCode(this)}] Parsed AuthToken successfully. Saving new tokens...');
      await _persistAuthToken(authToken);

      return _completeRefresh(completer, true);
    } catch (e) {
      dev.log('[SDK Auth #${identityHashCode(this)}] tryRefresh() encountered exception: $e');
      // Đối với lỗi mạng hoặc lỗi server (5xx), không nên tự động xóa token
      // để tránh việc người dùng bị đăng xuất vô lý khi mất kết nối mạng tạm thời.
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        dev.log('[SDK Auth #${identityHashCode(this)}] DioException status code: $statusCode');
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          dev.log('[SDK Auth #${identityHashCode(this)}] DioException with 4xx. Clearing tokens...');
          await _clearTokensSafely();
        }
      }
      return _completeRefresh(completer, false);
    } finally {
      if (identical(_refreshInProgress, completer)) {
        _refreshInProgress = null;
      }
    }
  }

  /// Check if access token is expired
  Future<bool> isTokenExpired() => _isTokenExpired();

  /// Cleanup resources
  void dispose() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _restoreAutoRefresh() async {
    final expiryMs = await _getTokenExpiry();
    final refresh = await _getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      _isAuthFailed = true;
    } else {
      _isAuthFailed = false;
    }
    dev.log('[SDK Auth #${identityHashCode(this)}] _restoreAutoRefresh() called. Read expiryMs: $expiryMs, _isAuthFailed: $_isAuthFailed');
    _scheduleAutoRefresh(expiryMs);
  }

  void _scheduleAutoRefresh(int? expiryMs) {
    _autoRefreshTimer?.cancel();

    if (expiryMs == null) {
      dev.log('[SDK Auth #${identityHashCode(this)}] _scheduleAutoRefresh: expiryMs is null. Skipping timer scheduling.');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final refreshAt = expiryMs - const Duration(minutes: 1).inMilliseconds;
    final delayMs = refreshAt - now;
    final safeDelayMs = delayMs > 0 ? delayMs : 1000;

    dev.log('[SDK Auth #${identityHashCode(this)}] _scheduleAutoRefresh: expiryMs=$expiryMs, now=$now, delayMs=$delayMs, safeDelayMs=$safeDelayMs ms');

    _autoRefreshTimer = Timer(Duration(milliseconds: safeDelayMs), () {
      dev.log('[SDK Auth #${identityHashCode(this)}] Auto-refresh timer fired! Executing tryRefresh()...');
      unawaited(tryRefresh());
    });
  }

  bool _completeRefresh(Completer<bool> completer, bool value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    return value;
  }

  AuthToken _parseAuthToken(Map<String, dynamic> body) {
    final tokenData = body['data'] ?? body;
    if (tokenData is Map<String, dynamic>) {
      final nested = tokenData['tokens'];
      if (nested is Map<String, dynamic>) {
        return AuthToken.fromJson(nested);
      }
      return AuthToken.fromJson(tokenData);
    }
    return AuthToken.fromJson(const {});
  }

  Future<void> _persistAuthToken(AuthToken authToken) async {
    _isAuthFailed = false;
    dev.log('[SDK Auth #${identityHashCode(this)}] _persistAuthToken() called. expiresIn: ${authToken.expiresIn}');
    // Cập nhật cache đồng bộ trong RAM trước để đảm bảo các request tiếp theo
    // hoặc request retry có thể đọc được ngay lập tức, tránh write-to-read delay của OS Keyring.
    _accessTokenCache = authToken.accessToken;
    if (authToken.refreshToken != null) {
      _refreshTokenCache = authToken.refreshToken!;
    }
    if (authToken.expiresIn != null) {
      _tokenExpiryCache = DateTime.now()
          .add(Duration(seconds: authToken.expiresIn!))
          .millisecondsSinceEpoch;
      dev.log('[SDK Auth #${identityHashCode(this)}] Calculated in-memory _tokenExpiryCache: $_tokenExpiryCache');
    }

    // Ghi xuống bộ lưu trữ bất đồng bộ của OS để khôi phục phiên đăng nhập sau này.
    await storage.saveAccessToken(authToken.accessToken);
    if (authToken.refreshToken != null) {
      await storage.saveRefreshToken(authToken.refreshToken!);
    }
    if (authToken.expiresIn != null) {
      await storage.saveTokenExpiry(authToken.expiresIn!);
    }

    if (_tokenExpiryCache != null) {
      _scheduleAutoRefresh(_tokenExpiryCache!);
    } else {
      unawaited(_restoreAutoRefresh());
    }
  }

  Future<void> _clearTokensSafely() async {
    _isAuthFailed = true;
    dev.log('[SDK Auth #${identityHashCode(this)}] _clearTokensSafely() called. Clearing all cached and stored tokens.');
    _accessTokenCache = null;
    _refreshTokenCache = null;
    _tokenExpiryCache = null;
    await _clearKratosSessionToken();
    try {
      await storage.clear();
    } catch (_) {}
  }

  bool _looksLikeSocialOnlyPasswordCase(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) return false;
    final directMessage =
        responseData['message']?.toString().toLowerCase() ?? '';
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

import 'dart:async';
import 'package:dio/dio.dart';
import 'models.dart';

/// Abstraction for token storage so core package remains platform-agnostic.
abstract class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> clear();
}

/// Simple in-memory storage (default) — replace with secure storage in Flutter example.
class InMemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> saveAccessToken(String token) async {
    _access = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _refresh = token;
  }
}

class AuthManager {
  final Dio _dio;
  final TokenStorage storage;

  AuthManager({Dio? dio, TokenStorage? storage})
      : _dio = dio ?? Dio(),
        storage = storage ?? InMemoryTokenStorage() {
    _dio.options.baseUrl = 'https://api.keemos.vn';
  }

  Future<TokenResponse> login(String email, String password) async {
    final req = LoginRequest(email: email, password: password);
    final resp = await _dio.post('/api/v1/auth/login', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    final token = TokenResponse.fromJson(body['data'] ?? body);
    await storage.saveAccessToken(token.accessToken);
    return token;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await storage.clear();
  }

  Future<String?> getAccessToken() => storage.readAccessToken();

  // set access token w/o login (e.g. from saved state) - returns true if valid token set
  Future<bool> setAccessToken(String token) async {
    await storage.saveAccessToken(token);
    return true;
  }

  Future<bool> tryRefresh() async {
    final refresh = await storage.readRefreshToken();
    if (refresh == null) return false;
    try {
      final resp = await _dio.post('/api/v1/auth/refresh', data: {'refresh_token': refresh});
      final body = resp.data as Map<String, dynamic>;
      final token = TokenResponse.fromJson(body['data'] ?? body);
      await storage.saveAccessToken(token.accessToken);
      return true;
    } catch (e) {
      await storage.clear();
      return false;
    }
  }
}

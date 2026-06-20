import 'package:dio/dio.dart';

import '../client.dart';
import '../models.dart';

class AuthApi {
  final KeemosClient client;

  AuthApi(this.client);

  Future<TokenResponse> login(
    String email,
    String password, {
    String? deviceName,
  }) async {
    final req = LoginRequest(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    final resp =
        await client.post('/api/v1/auth/login', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    return TokenResponse.fromJson(body['data'] ?? body);
  }

  Future<TokenResponse> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final req = RegisterRequest(
      email: email,
      password: password,
      fullName: fullName,
    );
    final resp =
        await client.post('/api/v1/auth/register', data: req.toJson());
    final body = resp.data as Map<String, dynamic>;
    return TokenResponse.fromJson(body['data'] ?? body);
  }

  Future<void> forgotPassword(String email) async {
    final req = ForgotPasswordRequest(email: email);
    await client.post('/api/v1/auth/forgot-password', data: req.toJson());
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final req = ResetPasswordRequest(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
    await client.post('/api/v1/auth/reset-password', data: req.toJson());
  }

  Future<void> logout() async {
    await client.post('/api/v1/auth/logout');
  }

  /// Link a social account (Google/Facebook/Apple) to current authenticated user.
  Future<void> socialLink({
    required String provider,
    required String token,
  }) async {
    final req = SocialProviderRequest(provider: provider, token: token);
    await client.post('/api/v1/auth/social-link', data: req.toJson());
  }

  /// Change password for current authenticated user.
  ///
  /// API may return HTTP 400 for social-login accounts that have never set
  /// a manual password.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final req = ChangePasswordRequest(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    await client.post('/api/v1/auth/change-password', data: req.toJson());
  }

  Future<UserProfile> getProfile() async {
    final resp = await client.get('/api/v1/auth/profile');
    final body = resp.data as Map<String, dynamic>;
    return UserProfile.fromJson(body['data'] ?? body);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> updates) async {
    final resp = await client.post('/api/v1/auth/profile', data: updates);
    final body = resp.data as Map<String, dynamic>;
    await client.invalidateCacheByPrefix('/api/v1/auth/profile');
    return UserProfile.fromJson(body['data'] ?? body);
  }

  /// Update arbitrary app-level settings for the current authenticated user.
  /// `settings` is an arbitrary JSON object stored by the backend.
  Future<Map<String, dynamic>> updateAppSettings(
      Map<String, dynamic> settings) async {
    final resp = await client.dio
        .patch('/api/v1/auth/app-settings', data: {'settings': settings});
    final body = resp.data as Map<String, dynamic>;
    await client.invalidateCacheByPrefix('/api/v1/auth/app-settings');
    return (body['data'] ?? body) as Map<String, dynamic>;
  }

  /// List linked social providers for current authenticated user.
  ///
  /// Returns a normalized set with values in: `google`, `facebook`, `apple`.
  Future<Set<String>> listLinkedProviders() async {
    const endpoints = <String>[
      '/api/v1/auth/social-links',
      '/api/v1/auth/linked-accounts',
      '/api/v1/auth/social-accounts',
      '/api/v1/auth/providers/linked',
    ];

    for (final endpoint in endpoints) {
      final resp = await client.dio.get(
        endpoint,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final code = resp.statusCode ?? 0;
      if (code == 404) continue;
      if (code >= 400) {
        throw DioException(
          requestOptions: resp.requestOptions,
          response: resp,
          message: 'Linked providers request failed ($code)',
        );
      }

      final linked = _parseLinkedProvidersPayload(resp.data);
      if (linked.isNotEmpty) return linked;
    }
    return const {};
  }

  /// Delete the current authenticated account.
  Future<void> deleteAccount() async {
    await client.post('/api/v1/auth/delete-account');
  }

  Set<String> _parseLinkedProvidersPayload(dynamic payload) {
    final out = <String>{};
    final root = _asStringDynamicMap(payload);
    final data = _asStringDynamicMap(root['data']);
    for (final node in [
      payload,
      root['data'],
      root['providers'],
      root['linked_providers'],
      root['linked_accounts'],
      root['accounts'],
      data['providers'],
      data['linked_providers'],
      data['linked_accounts'],
      data['accounts'],
    ]) {
      out.addAll(_extractProviders(node));
    }
    return out;
  }

  Set<String> _extractProviders(dynamic node) {
    final out = <String>{};
    if (node == null) return out;

    if (node is String) {
      _addProviderName(out, node);
      return out;
    }

    if (node is List) {
      for (final item in node) {
        out.addAll(_extractProviders(item));
      }
      return out;
    }

    final map = _asStringDynamicMap(node);
    if (map.isEmpty) return out;

    final providerName = map['provider']?.toString() ??
        map['name']?.toString() ??
        map['type']?.toString();
    if (providerName != null && providerName.trim().isNotEmpty) {
      final hasLinkedFlag = map.containsKey('linked') ||
          map.containsKey('is_linked') ||
          map.containsKey('isLinked') ||
          map.containsKey('connected') ||
          map.containsKey('is_connected') ||
          map.containsKey('isConnected') ||
          map.containsKey('status');
      final linked = _isTruthy(map['linked']) ||
          _isTruthy(map['is_linked']) ||
          _isTruthy(map['isLinked']) ||
          _isTruthy(map['connected']) ||
          _isTruthy(map['is_connected']) ||
          _isTruthy(map['isConnected']) ||
          _isTruthy(map['status']);
      if (!hasLinkedFlag || linked) {
        _addProviderName(out, providerName);
      }
    }

    for (final provider in const ['google', 'facebook', 'apple']) {
      final value = map[provider];
      if (_isTruthy(value)) {
        out.add(provider);
      } else if (value is Map &&
          (_isTruthy(value['linked']) ||
              _isTruthy(value['is_linked']) ||
              _isTruthy(value['isLinked']) ||
              _isTruthy(value['connected']) ||
              _isTruthy(value['is_connected']) ||
              _isTruthy(value['isConnected']) ||
              _isTruthy(value['status']))) {
        out.add(provider);
      }
    }
    return out;
  }

  void _addProviderName(Set<String> out, String raw) {
    final value = raw.toLowerCase().trim();
    if (value.contains('google')) out.add('google');
    if (value.contains('facebook')) out.add('facebook');
    if (value.contains('apple')) out.add('apple');
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic node) {
    if (node is Map<String, dynamic>) return node;
    if (node is Map) {
      return node.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  bool _isTruthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' ||
          v == 'true' ||
          v == 'yes' ||
          v == 'linked' ||
          v == 'connected';
    }
    return false;
  }
}

import '../client.dart';
import '../models.dart';

class AuthApi {
  final KeemosClient client;

  AuthApi(this.client);

  Future<TokenResponse> login(String email, String password) async {
    final resp = await client.post('/api/v1/auth/login', data: {'email': email, 'password': password});
    final body = resp.data as Map<String, dynamic>;
    return TokenResponse.fromJson(body['data'] ?? body);
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
}

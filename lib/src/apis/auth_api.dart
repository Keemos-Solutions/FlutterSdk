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

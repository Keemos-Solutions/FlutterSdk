import 'package:keemos_sdk/keemos_sdk.dart';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final authManager = AuthManager(dio: dio);
  final client = KeemosClient(dio: dio, authManager: authManager);

  final authApi = AuthApi(client);

  // Example login
  final token = await authApi.login('user@example.com', 'SecurePass123!@#');
  print('Access token: ' + token.accessToken);

  // Get profile
  final profile = await authApi.getProfile();
  print('User: ' + (profile.fullName ?? profile.email ?? 'unknown'));
}

import 'package:flutter/material.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

/// Example usage of Keemos SDK with secure token storage
/// This demonstrates best practices for handling authentication

class KeemosAuthExample {
  static Future<void> demonstrateSecureTokenStorage() async {
    // 1. Initialize AuthManager with SecureTokenStorage
    // In a real Flutter app, use SecureTokenStorage for encrypted storage
    final authManager = AuthManager(
      storage: SecureTokenStorage(), // Uses flutter_secure_storage
    );

    try {
      // 2. User login - tokens are automatically saved securely
      final authToken = await authManager.login(
        'user@example.com',
        'password123',
      );

      print('Access Token: ${authToken.accessToken}');
      print('Expires in: ${authToken.expiresIn} seconds');

      // 3. Tokens are now secured:
      // - iOS: Stored in Keychain
      // - Android: Stored in Keystore (encrypted)

      // 4. Create KeemosClient (handles automatic token refresh on 401)
      final client = KeemosClient(authManager: authManager);
      print('Client initialized for: ${client.dio.options.baseUrl}');

    } catch (e) {
      print('Authentication failed: $e');
    }
  }

  static Future<void> demonstrateSocialLogin() async {
    final authManager = AuthManager(
      storage: SecureTokenStorage(),
    );

    try {
      // Google login - get token from Google SDK first
      // final googleToken = await GoogleSignIn().signIn();
      // final token = await googleToken?.authentication.idToken;

      // Then send to Keemos backend
      final authToken = await authManager.socialLogin(
        'google',
        'GOOGLE_ID_TOKEN_HERE',
      );

      print('Social login successful');
      print('New user created with ID: ${authToken.accessToken}');

    } catch (e) {
      print('Social login failed: $e');
    }
  }

  static Future<void> demonstrateTokenManagement() async {
    final authManager = AuthManager(
      storage: SecureTokenStorage(),
    );

    // Get current access token
    final token = await authManager.getAccessToken();
    print('Current token: $token');

    // Check if token is expired
    final isExpired = await authManager.isTokenExpired();
    print('Token expired: $isExpired');

    // Manually refresh token (usually handled automatically)
    final refreshed = await authManager.tryRefresh();
    if (refreshed) {
      print('Token refreshed successfully');
    } else {
      print('Token refresh failed - user needs to login again');
    }

    // Logout and clear all tokens
    await authManager.logout();
    print('Tokens cleared from secure storage');
  }

  static Future<void> demonstrateErrorRecovery() async {
    final authManager = AuthManager(
      storage: SecureTokenStorage(),
    );

    final client = KeemosClient(authManager: authManager);
    print('Client initialized for error recovery demo: ${client.dio.options.baseUrl}');

    try {
      // The SDK automatically handles:
      // 1. Adding Authorization header with token
      // 2. Catching 401 errors
      // 3. Attempting token refresh
      // 4. Retrying the original request with new token
      // 5. If refresh fails, logs user out automatically

      // Example API call with automatic error handling
      // final response = await client.get('/api/v1/households');

    } catch (e) {
      print('API call failed: $e');
      // User is logged out and tokens are cleared
    }
  }
}

/// Integration with Flutter app
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AuthManager authManager;
  late KeemosClient client;

  @override
  void initState() {
    super.initState();
    _setupKeemosSDK();
  }

  void _setupKeemosSDK() {
    // Initialize with secure token storage
    authManager = AuthManager(
      storage: SecureTokenStorage(),
    );

    client = KeemosClient(authManager: authManager);
  }

  @override
  void dispose() {
    authManager.dispose(); // Cleanup resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keemos IoT',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Keemos Authentication'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    await authManager.login(
                      'user@example.com',
                      'password',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login successful')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Login failed: $e')),
                    );
                  }
                },
                child: const Text('Login'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await authManager.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

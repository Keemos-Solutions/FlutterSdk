# 🔐 Token Storage & Authentication - Best Practices Guide

## Overview

The Keemos Flutter SDK provides secure token management with automatic refresh handling. This guide explains how to implement secure token storage in your Flutter application.

## Key Features

✅ **Secure Storage**: Encrypted storage using platform-specific secure storage  
✅ **Automatic Refresh**: Handles token refresh on 401 errors automatically  
✅ **Expiration Tracking**: Monitors token expiration with 60-second buffer  
✅ **Concurrent Request Prevention**: Prevents multiple simultaneous refresh requests  
✅ **Platform Support**: iOS (Keychain) and Android (Keystore)  

## Token Storage Implementations

### 1. SecureTokenStorage (Recommended for Flutter)

**Storage Location:**
- **iOS**: Keychain (encrypted, app-specific)
- **Android**: Android Keystore (encrypted, app-specific)

**Usage:**
```dart
import 'package:keemos_sdk/keemos_sdk.dart';

final authManager = AuthManager(
  storage: SecureTokenStorage(),
);
```

**Security Features:**
- End-to-end encrypted storage
- Platform-specific secure storage
- Automatic cleanup on logout
- No tokens in SharedPreferences or local files

### 2. InMemoryTokenStorage (Development Only)

**Warning**: Tokens stored in memory are lost on app restart and are not encrypted.

```dart
final authManager = AuthManager(
  storage: InMemoryTokenStorage(), // Default
);
```

Use this only for testing and development, never in production.

## Setup Instructions

### Step 1: Update Dependencies

```yaml
dependencies:
  keemos_sdk: ^0.4.0  # or latest
  flutter_secure_storage: ^9.0.0
```

### Step 2: Initialize AuthManager with SecureTokenStorage

```dart
import 'package:keemos_sdk/keemos_sdk.dart';

class AuthService {
  late AuthManager authManager;

  AuthService() {
    authManager = AuthManager(
      storage: SecureTokenStorage(),
    );
  }

  // Your auth methods...
}
```

### Step 3: Create KeemosClient

```dart
final client = KeemosClient(authManager: authManager);
```

## Authentication Flow

### Login

```dart
try {
  final authToken = await authManager.login(
    email: 'user@example.com',
    password: 'password123',
  );
  
  // Tokens are automatically saved to secure storage
  print('Access token expires in: ${authToken.expiresIn} seconds');
  print('Refresh token saved securely');
  
} catch (e) {
  print('Login failed: $e');
}
```

**What happens:**
1. Credentials sent to backend
2. Backend validates and returns access_token, refresh_token, expires_in
3. Both tokens saved to encrypted storage
4. Expiration time calculated and stored
5. Tokens cleared on error

### Social Login

```dart
final authToken = await authManager.socialLogin(
  'google',  // or 'facebook', 'apple'
  googleIdToken,  // ID token from social SDK
);

// Same secure storage as regular login
```

### Token Refresh

The SDK automatically handles token refresh:

```
Request → 401 Unauthorized
  ↓
Check if refresh token exists
  ↓
Send refresh request with refresh_token
  ↓
Receive new access_token
  ↓
Save new token to secure storage
  ↓
Retry original request
  ↓
Return response to caller
```

**Concurrent Refresh Prevention:**

If multiple requests receive 401 simultaneously:
```
Request 1 → 401 → Start refresh → Completer A
Request 2 → 401 → Refresh in progress → Wait for Completer A
Request 3 → 401 → Refresh in progress → Wait for Completer A
                   ↓
            Refresh completes
                   ↓
All three requests retry with new token
```

### Logout

```dart
await authManager.logout();

// What happens:
// 1. Send logout request to backend
// 2. Clear all tokens from secure storage
// 3. Clear expiration time
// 4. User needs to login again for next session
```

## Advanced Usage

### Manual Token Refresh

```dart
// Check if token is expired
final isExpired = await authManager.isTokenExpired();

if (isExpired) {
  // Attempt manual refresh
  final refreshed = await authManager.tryRefresh();
  
  if (refreshed) {
    print('Token refreshed');
  } else {
    print('Token refresh failed - need to login again');
    await authManager.logout();
  }
}
```

### Get Current Tokens

```dart
final accessToken = await authManager.getAccessToken();
final refreshToken = await authManager.getRefreshToken();

print('Access Token: $accessToken');
print('Refresh Token: $refreshToken');
```

### Set Token Without Login

Useful for restoring session after app restart:

```dart
// Check if tokens exist in storage
final token = await authManager.getAccessToken();

if (token != null) {
  // Session is still active
  final client = KeemosClient(authManager: authManager);
  // Continue using authenticated client
} else {
  // Session expired or not logged in
  // Show login screen
}
```

### Cleanup Resources

```dart
@override
void dispose() {
  authManager.dispose();
  super.dispose();
}
```

## Token Expiration Strategy

The SDK uses a **60-second buffer** before token expiration:

```
Token issued at:     12:00:00
Expires in:          3600 seconds
Expiration time:     13:00:00

Token considered expired when:
System time > 12:59:00 (60 seconds before actual expiry)
```

**Why?**
- Prevents "token expired" errors mid-request
- Gives time for refresh before expiration
- Reduces edge cases in token handling

## Error Handling

### 401 Unauthorized

```dart
try {
  final response = await client.get('/api/v1/households');
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // Handled automatically by interceptor
    // If refresh succeeds: request retried automatically
    // If refresh fails: user logged out, tokens cleared
  }
}
```

### 403 Forbidden

```dart
try {
  final response = await client.get('/api/v1/admin/settings');
} on DioException catch (e) {
  if (e.response?.statusCode == 403) {
    // Permission denied - cannot fix with token refresh
    // User needs different account with permissions
    print('Access denied');
  }
}
```

### Network Errors

```dart
try {
  final response = await client.get('/api/v1/households');
} on DioException catch (e) {
  if (e.type == DioExceptionType.connectionTimeout) {
    print('Connection timeout');
  } else if (e.type == DioExceptionType.unknown) {
    print('Network error: ${e.error}');
  }
}
```

## Security Best Practices

### ✅ DO:
- Use `SecureTokenStorage` in production Flutter apps
- Store refresh token separately from access token
- Clear tokens on logout
- Handle 401 errors with automatic refresh
- Implement proper error handling
- Use HTTPS for all API calls
- Validate tokens before making requests

### ❌ DON'T:
- Store tokens in SharedPreferences
- Store tokens in plain text files
- Pass tokens in query parameters
- Log tokens to console/analytics
- Use InMemoryTokenStorage in production
- Share tokens between users
- Hard-code tokens in app

## Platform-Specific Configuration

### iOS Setup

No additional setup required. The SDK uses:
- `KeychainAccessibility.first_this_device_this_app_only`
- Ensures tokens only accessible by your app on this device

### Android Setup

No additional setup required. The SDK uses:
- `RSA_ECB_OAEPwithSHA_256andMGF1Padding` for key cipher
- `AES_GCM_NoPadding` for storage cipher
- Standard Android Keystore encryption

## Troubleshooting

### Tokens Not Persisting

```dart
// Check if storage implementation is correct
final storage = SecureTokenStorage();
await storage.saveAccessToken('test_token');
final token = await storage.readAccessToken();
print('Saved token: $token'); // Should print 'test_token'
```

### Token Refresh Failing

```dart
// Check refresh token exists
final refreshToken = await authManager.getRefreshToken();
if (refreshToken == null) {
  print('No refresh token - user needs to login again');
}

// Check network connectivity
try {
  final result = await authManager.tryRefresh();
  print('Refresh result: $result');
} catch (e) {
  print('Refresh error: $e');
}
```

### Concurrent Refresh Issues

The SDK prevents this automatically:
```dart
// Multiple requests with expired token
// First request: starts refresh
// Second request: waits for first refresh to complete
// Both retry with new token
// No double-refresh occurs
```

## API Reference

### AuthManager

```dart
// Authentication
Future<AuthToken> login(String email, String password)
Future<AuthToken> socialLogin(String provider, String token)
Future<void> logout()

// Token Management
Future<String?> getAccessToken()
Future<String?> getRefreshToken()
Future<bool> setAccessToken(String token)
Future<bool> isTokenExpired()

// Token Refresh
Future<bool> tryRefresh()

// Cleanup
void dispose()
```

### TokenStorage Interface

```dart
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
```

## Example App

See [secure_token_storage_example.dart](example/secure_token_storage_example.dart) for complete implementation example.

## Migration Guide

### From InMemoryTokenStorage to SecureTokenStorage

```dart
// Old (development):
final authManager = AuthManager(); // Uses InMemoryTokenStorage

// New (production):
final authManager = AuthManager(
  storage: SecureTokenStorage(),
);
```

Tokens will be migrated to secure storage on next login.

## FAQ

**Q: Do I need to manually save tokens?**  
A: No, the SDK handles all token saving automatically.

**Q: What happens if refresh token expires?**  
A: User is logged out and must login again.

**Q: Can I access tokens after app restart?**  
A: Yes, with SecureTokenStorage. Tokens persist securely.

**Q: How often should I refresh tokens?**  
A: Automatically when token expires (60-second buffer).

**Q: Is it safe to store tokens on device?**  
A: Yes, SecureTokenStorage uses encrypted platform storage.

---

For more information, see [auth_sdk.md](auth_sdk.md) for authentication API specification.

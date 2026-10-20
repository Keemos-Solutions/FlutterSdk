import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:keemos_sdk/keemos_sdk.dart';
import 'package:test/test.dart';

class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic nextResponseData;
  int nextStatusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future? cancelFuture,
  ) async {
    lastOptions = options;
    final encoded = utf8.encode(jsonEncode(nextResponseData ?? {'data': {}}));
    return ResponseBody.fromBytes(encoded, nextStatusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      Headers.contentLengthHeader: ['${encoded.length}'],
    });
  }
}

void main() {
  group('AuthManager _parseAuthToken', () {
    late AuthManager authManager;

    setUp(() {
      authManager = AuthManager(dio: Dio());
    });

    test('parses tokens nested under data.tokens', () {
      final body = {
        'data': {
          'tokens': {
            'access_token': 'access_123',
            'refresh_token': 'refresh_123',
            'expires_in': 3600,
          },
        },
      };

      final token = authManager.parseAuthToken(body);
      expect(token.accessToken, 'access_123');
      expect(token.refreshToken, 'refresh_123');
      expect(token.expiresIn, 3600);
    });

    test('parses tokens nested under data.session', () {
      final body = {
        'data': {
          'session': {
            'access_token': 'access_session_123',
            'refresh_token': 'refresh_session_123',
            'expires_in': 7200,
            'session_token': 'kratos_sess_abc',
          },
        },
      };

      final token = authManager.parseAuthToken(body);
      expect(token.accessToken, 'access_session_123');
      expect(token.refreshToken, 'refresh_session_123');
      expect(token.expiresIn, 7200);
    });

    test('parses tokens under top-level session', () {
      final body = {
        'session': {
          'access_token': 'access_root_session',
          'refresh_token': 'refresh_root_session',
          'expires_in': 1800,
        },
      };

      final token = authManager.parseAuthToken(body);
      expect(token.accessToken, 'access_root_session');
      expect(token.refreshToken, 'refresh_root_session');
      expect(token.expiresIn, 1800);
    });

    test('parses tokens flat under data', () {
      final body = {
        'data': {
          'access_token': 'flat_access',
          'refresh_token': 'flat_refresh',
          'expires_in': 900,
        },
      };

      final token = authManager.parseAuthToken(body);
      expect(token.accessToken, 'flat_access');
      expect(token.refreshToken, 'flat_refresh');
      expect(token.expiresIn, 900);
    });
  });

  group('AuthManager login session token handling', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late InMemoryTokenStorage storage;
    late AuthManager authManager;

    setUp(() {
      dio = Dio();
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      storage = InMemoryTokenStorage();
      authManager = AuthManager(dio: dio, storage: storage);
    });

    test('extracts session_token from data.session and updates cache and storage', () async {
      adapter.nextResponseData = {
        'data': {
          'session': {
            'access_token': 'test_access_token',
            'refresh_token': 'test_refresh_token',
            'expires_in': 3600,
            'session_token': 'kratos_session_nested_token',
          },
        },
      };

      final authToken = await authManager.login('user@example.com', 'password123');

      expect(authToken.accessToken, 'test_access_token');
      expect(authToken.refreshToken, 'test_refresh_token');
      expect(authManager.kratosSessionTokenCache, 'kratos_session_nested_token');
      expect(await storage.readKratosSessionToken(), 'kratos_session_nested_token');
    });

    test('extracts session_token from data top-level and updates cache and storage', () async {
      adapter.nextResponseData = {
        'data': {
          'tokens': {
            'access_token': 'access_abc',
            'refresh_token': 'refresh_abc',
            'expires_in': 3600,
          },
          'session_token': 'kratos_top_level_token',
        },
      };

      final authToken = await authManager.login('user@example.com', 'password123');

      expect(authToken.accessToken, 'access_abc');
      expect(authManager.kratosSessionTokenCache, 'kratos_top_level_token');
      expect(await storage.readKratosSessionToken(), 'kratos_top_level_token');
    });

    test('login without session_token does not set kratosSessionTokenCache', () async {
      adapter.nextResponseData = {
        'data': {
          'tokens': {
            'access_token': 'access_no_kratos',
            'refresh_token': 'refresh_no_kratos',
            'expires_in': 3600,
          },
        },
      };

      final authToken = await authManager.login('user@example.com', 'password123');

      expect(authToken.accessToken, 'access_no_kratos');
      expect(authManager.kratosSessionTokenCache, isNull);
      expect(await storage.readKratosSessionToken(), isNull);
    });
  });
}

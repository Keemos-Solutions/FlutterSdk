import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:test/test.dart';
import 'package:keemos_sdk/src/auth.dart';
import 'package:keemos_sdk/src/client.dart';
import 'package:keemos_sdk/src/security/keemos_security_config.dart';
import 'package:keemos_sdk/src/security/keemos_security_guard.dart';
import 'package:keemos_sdk/src/security/security_violation_event.dart';

class FakeX509Certificate implements io.X509Certificate {
  @override
  final Uint8List der;

  FakeX509Certificate(this.der);

  @override
  String get subject => 'CN=keemos.vn';

  @override
  String get issuer => 'CN=Keemos CA';

  @override
  DateTime get startValidity => DateTime(2026, 1, 1);

  @override
  DateTime get endValidity => DateTime(2027, 1, 1);

  @override
  Uint8List get sha1 => Uint8List.fromList(List.filled(20, 0));

  @override
  String get pem => '-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----';
}

class MockRequestInterceptorHandler extends RequestInterceptorHandler {
  RequestOptions? passedOptions;
  DioException? rejectedException;

  @override
  void next(RequestOptions requestOptions) {
    passedOptions = requestOptions;
  }

  @override
  void reject(DioException error, [bool callNext = false]) {
    rejectedException = error;
  }
}

void main() {
  group('KeemosSecurityGuard & KeemosSecurityInterceptor', () {
    test('attaches interceptor to Dio instance at index 0', () {
      final dio = Dio();
      final config = KeemosSecurityConfig(isEnforced: true);
      KeemosSecurityGuard.attach(dio, config);

      expect(dio.interceptors.isNotEmpty, isTrue);
      expect(dio.interceptors.first, isA<KeemosSecurityInterceptor>());
      final interceptor = dio.interceptors.first as KeemosSecurityInterceptor;
      expect(interceptor.config, config);
    });

    test('calls onViolation and throws DioException when proxy detected and guardrail enforced', () {
      final dio = Dio();
      SecurityViolationEvent? capturedEvent;
      final config = KeemosSecurityConfig(
        isEnforced: true,
        blockProxies: true,
        onViolation: (e) => capturedEvent = e,
      );
      KeemosSecurityGuard.attach(dio, config);

      final interceptor = dio.interceptors.whereType<KeemosSecurityInterceptor>().first;
      interceptor.isProxyActiveForTesting = true;
      final options = RequestOptions(path: '/api/v1/test');

      expect(
        () => interceptor.checkProxyViolation(options),
        throwsA(isA<DioException>().having(
          (e) => e.type,
          'type',
          equals(DioExceptionType.connectionError),
        )),
      );
      expect(capturedEvent, isNotNull);
      expect(capturedEvent?.type, SecurityViolationType.proxyDetected);
      expect(capturedEvent?.message, contains('Active proxy detected'));
    });

    test('does not throw or notify when proxy detected but blockProxies is false', () {
      final dio = Dio();
      SecurityViolationEvent? capturedEvent;
      final config = KeemosSecurityConfig(
        isEnforced: true,
        blockProxies: false,
        onViolation: (e) => capturedEvent = e,
      );
      KeemosSecurityGuard.attach(dio, config);

      final interceptor = dio.interceptors.whereType<KeemosSecurityInterceptor>().first;
      interceptor.isProxyActiveForTesting = true;
      final options = RequestOptions(path: '/api/v1/test');

      expect(() => interceptor.checkProxyViolation(options), returnsNormally);
      expect(capturedEvent, isNull);
    });

    test('does not throw or notify when proxy detected but isEnforced is false', () {
      final dio = Dio();
      SecurityViolationEvent? capturedEvent;
      final config = KeemosSecurityConfig(
        isEnforced: false,
        blockProxies: true,
        onViolation: (e) => capturedEvent = e,
      );
      KeemosSecurityGuard.attach(dio, config);

      final interceptor = dio.interceptors.whereType<KeemosSecurityInterceptor>().first;
      interceptor.isProxyActiveForTesting = true;
      final options = RequestOptions(path: '/api/v1/test');

      expect(() => interceptor.checkProxyViolation(options), returnsNormally);
      expect(capturedEvent, isNull);
    });

    test('onRequest rejects handler when proxy is detected', () {
      final dio = Dio();
      SecurityViolationEvent? capturedEvent;
      final config = KeemosSecurityConfig(
        isEnforced: true,
        blockProxies: true,
        onViolation: (e) => capturedEvent = e,
      );
      KeemosSecurityGuard.attach(dio, config);

      final interceptor = dio.interceptors.whereType<KeemosSecurityInterceptor>().first;
      interceptor.isProxyActiveForTesting = true;

      final handler = MockRequestInterceptorHandler();
      final options = RequestOptions(path: '/api/v1/device/list');

      interceptor.onRequest(options, handler);

      expect(handler.rejectedException, isNotNull);
      expect(handler.rejectedException?.type, DioExceptionType.connectionError);
      expect(handler.passedOptions, isNull);
      expect(capturedEvent?.type, SecurityViolationType.proxyDetected);
    });

    test('onRequest calls handler.next when no proxy is active', () {
      final dio = Dio();
      final config = KeemosSecurityConfig(
        isEnforced: true,
        blockProxies: true,
      );
      KeemosSecurityGuard.attach(dio, config);

      final interceptor = dio.interceptors.whereType<KeemosSecurityInterceptor>().first;
      interceptor.isProxyActiveForTesting = false;

      final handler = MockRequestInterceptorHandler();
      final options = RequestOptions(path: '/api/v1/device/list');

      interceptor.onRequest(options, handler);

      expect(handler.rejectedException, isNull);
      expect(handler.passedOptions, options);
    });

    group('SPKI Certificate Pinning', () {
      final sampleDerBytes = Uint8List.fromList(utf8.encode('sample-cert-bytes-for-pinning'));
      final digest = sha256.convert(sampleDerBytes);
      final expectedHash = 'sha256/${base64.encode(digest.bytes)}';

      test('computeSpkiHash calculates valid sha256 formatted pin', () {
        final hash = KeemosSecurityGuard.computeSpkiHash(sampleDerBytes);
        expect(hash, expectedHash);
      });

      test('validateCertificate approves certificate when hash matches pinned list', () {
        SecurityViolationEvent? capturedEvent;
        final config = KeemosSecurityConfig(
          isEnforced: true,
          pinnedSpkiHashes: [expectedHash],
          onViolation: (e) => capturedEvent = e,
        );

        final cert = FakeX509Certificate(sampleDerBytes);
        final isValid = KeemosSecurityGuard.validateCertificate(cert, 'api.keemos.vn', config);

        expect(isValid, isTrue);
        expect(capturedEvent, isNull);
      });

      test('validateCertificate rejects certificate and fires onViolation on mismatch', () {
        SecurityViolationEvent? capturedEvent;
        final config = KeemosSecurityConfig(
          isEnforced: true,
          pinnedSpkiHashes: ['sha256/wronghashwronghashwronghashwronghashwrong='],
          onViolation: (e) => capturedEvent = e,
        );

        final cert = FakeX509Certificate(sampleDerBytes);
        final isValid = KeemosSecurityGuard.validateCertificate(cert, 'api.keemos.vn', config);

        expect(isValid, isFalse);
        expect(capturedEvent, isNotNull);
        expect(capturedEvent?.type, SecurityViolationType.spkiPinningMismatch);
        expect(capturedEvent?.message, contains('api.keemos.vn'));
      });

      test('validateCertificate rejects null certificate', () {
        SecurityViolationEvent? capturedEvent;
        final config = KeemosSecurityConfig(
          isEnforced: true,
          pinnedSpkiHashes: [expectedHash],
          onViolation: (e) => capturedEvent = e,
        );

        final isValid = KeemosSecurityGuard.validateCertificate(null, 'api.keemos.vn', config);
        expect(isValid, isFalse);
        expect(capturedEvent, isNull);
      });

      test('attach configures IOHttpClientAdapter when pinning hashes present and enforced', () {
        final dio = Dio();
        final config = KeemosSecurityConfig(
          isEnforced: true,
          pinnedSpkiHashes: [expectedHash],
        );
        KeemosSecurityGuard.attach(dio, config);

        expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
        final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
        expect(adapter.validateCertificate, isNotNull);
      });
    });

    group('KeemosClient integration', () {
      test('attaches security guard when securityConfig is provided', () {
        final dio = Dio();
        final authManager = AuthManager(storage: InMemoryTokenStorage());
        final securityConfig = KeemosSecurityConfig(
          isEnforced: true,
          pinnedSpkiHashes: ['sha256/testpin='],
        );

        final client = KeemosClient(
          dio: dio,
          authManager: authManager,
          securityConfig: securityConfig,
        );

        expect(client.securityConfig, equals(securityConfig));
        expect(
          dio.interceptors.any((i) => i is KeemosSecurityInterceptor),
          isTrue,
        );
      });

      test('does not attach security guard when securityConfig is null', () {
        final dio = Dio();
        final authManager = AuthManager(storage: InMemoryTokenStorage());

        final client = KeemosClient(
          dio: dio,
          authManager: authManager,
        );

        expect(client.securityConfig, isNull);
        expect(
          dio.interceptors.any((i) => i is KeemosSecurityInterceptor),
          isFalse,
        );
      });
    });
  });
}

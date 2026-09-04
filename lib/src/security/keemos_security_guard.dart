import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'keemos_security_config.dart';
import 'security_violation_event.dart';

/// Interceptor that enforces network security guardrails (e.g. proxy detection).
class KeemosSecurityInterceptor extends Interceptor {
  final KeemosSecurityConfig config;

  /// Test hook allowing unit tests to simulate an active proxy environment.
  bool isProxyActiveForTesting = false;

  KeemosSecurityInterceptor({required this.config});

  /// Evaluates whether an active proxy is detected and throws [DioException]
  /// with [DioExceptionType.connectionError] if violations are found.
  void checkProxyViolation(RequestOptions options) {
    if (!config.isEnforced || !config.blockProxies || kIsWeb) return;

    bool proxyFound = isProxyActiveForTesting;
    if (!proxyFound && !kIsWeb) {
      final httpProxy = io.Platform.environment['http_proxy'] ?? io.Platform.environment['HTTP_PROXY'];
      final httpsProxy = io.Platform.environment['https_proxy'] ?? io.Platform.environment['HTTPS_PROXY'];
      if ((httpProxy != null && httpProxy.isNotEmpty) || (httpsProxy != null && httpsProxy.isNotEmpty)) {
        proxyFound = true;
      }
    }

    if (proxyFound) {
      config.onViolation?.call(
        SecurityViolationEvent(
          type: SecurityViolationType.proxyDetected,
          message: 'Active proxy detected on outbound request: ${options.uri}',
        ),
      );
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Network connection security failure',
      );
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      checkProxyViolation(options);
      handler.next(options);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}

/// Security guard for attaching SPKI public key pinning and proxy detection to Dio.
class KeemosSecurityGuard {
  /// Computes the SPKI / DER SHA-256 hash formatted as `sha256/<base64>`.
  static String computeSpkiHash(List<int> derBytes) {
    final digest = sha256.convert(derBytes);
    return 'sha256/${base64.encode(digest.bytes)}';
  }

  /// Validates a server certificate against the pinned SPKI hashes in [config].
  static bool validateCertificate(
    io.X509Certificate? cert,
    String host,
    KeemosSecurityConfig config,
  ) {
    if (cert == null) return false;
    final hashBase64 = computeSpkiHash(cert.der);

    final matches = config.pinnedSpkiHashes.contains(hashBase64);
    if (!matches) {
      config.onViolation?.call(
        SecurityViolationEvent(
          type: SecurityViolationType.spkiPinningMismatch,
          message: 'SPKI pinning mismatch for host: $host',
        ),
      );
    }
    return matches;
  }

  /// Attaches security guardrails to the given [dio] instance.
  ///
  /// - Prepends [KeemosSecurityInterceptor] to reject requests if proxy is detected.
  /// - Configures [IOHttpClientAdapter] with SPKI SHA-256 pinning on native platforms.
  static void attach(Dio dio, KeemosSecurityConfig config) {
    // 1. Add security interceptor at index 0 to inspect before other interceptors
    dio.interceptors.insert(0, KeemosSecurityInterceptor(config: config));

    // 2. Setup TLS SPKI certificate pinning on native platforms
    if (!kIsWeb && config.isEnforced && config.pinnedSpkiHashes.isNotEmpty) {
      final adapter = dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.validateCertificate = (io.X509Certificate? cert, String host, int port) {
          return validateCertificate(cert, host, config);
        };
        adapter.createHttpClient = () {
          final client = io.HttpClient();
          client.badCertificateCallback = (io.X509Certificate cert, String host, int port) {
            return validateCertificate(cert, host, config);
          };
          return client;
        };
      }
    }
  }
}

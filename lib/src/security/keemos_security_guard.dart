import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
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
      
      if (!proxyFound) {
        try {
          final proxyString = io.HttpClient.findProxyFromEnvironment(options.uri);
          if (proxyString.isNotEmpty && !proxyString.toUpperCase().contains('DIRECT')) {
            proxyFound = true;
          }
        } catch (e) {
          // ignore error to ensure it never fails on unsupported platforms
        }
      }
    }

    if (proxyFound) {
      try {
        config.onViolation?.call(
          SecurityViolationEvent(
            type: SecurityViolationType.proxyDetected,
            message: 'Active proxy detected on outbound request: ${options.uri}',
          ),
        );
      } catch (e) {
        // isolate onViolation call so it never breaks the interceptor execution flow entirely,
        // although we throw immediately after anyway.
      }
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
  /// Computes the true SPKI SHA-256 hash formatted as `sha256/<base64>`.
  static String computeSpkiHash(List<int> derBytes) {
    try {
      final parser = ASN1Parser(Uint8List.fromList(derBytes));
      final sequence = parser.nextObject() as ASN1Sequence;
      final tbsCertificate = sequence.elements[0] as ASN1Sequence;
      
      for (var element in tbsCertificate.elements) {
        if (element is ASN1Sequence && element.elements.length == 2) {
          if (element.elements[0] is ASN1Sequence && element.elements[1] is ASN1BitString) {
            final spkiBytes = element.encodedBytes;
            final digest = sha256.convert(spkiBytes);
            return 'sha256/${base64.encode(digest.bytes)}';
          }
        }
      }
    } catch (e) {
      // Fallback below
    }
    return computeCertDerHash(derBytes);
  }

  /// Computes the certificate DER SHA-256 hash.
  static String computeCertDerHash(List<int> derBytes) {
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
    final spkiHash = computeSpkiHash(cert.der);
    final certDerHash = computeCertDerHash(cert.der);

    final matches = config.pinnedSpkiHashes.contains(spkiHash) ||
                    config.pinnedSpkiHashes.contains(certDerHash);
                    
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
      }
    }
  }
}

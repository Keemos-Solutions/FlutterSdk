import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('KeemosSecurityConfig', () {
    test('defaults isEnforced to !kDebugMode and blockProxies to true', () {
      final config = KeemosSecurityConfig(
        pinnedSpkiHashes: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
      );
      expect(config.pinnedSpkiHashes.length, 1);
      expect(config.pinnedSpkiHashes.first, 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
      expect(config.blockProxies, isTrue);
      expect(config.isEnforced, equals(!kDebugMode));
      expect(config.onViolation, isNull);
    });

    test('accepts explicit isEnforced value', () {
      final enforcedConfig = KeemosSecurityConfig(isEnforced: true);
      expect(enforcedConfig.isEnforced, isTrue);

      final unenforcedConfig = KeemosSecurityConfig(isEnforced: false);
      expect(unenforcedConfig.isEnforced, isFalse);
    });

    test('accepts custom violation callback and executes it', () {
      SecurityViolationEvent? capturedEvent;
      final config = KeemosSecurityConfig(
        isEnforced: true,
        onViolation: (e) => capturedEvent = e,
      );
      final event = SecurityViolationEvent(
        type: SecurityViolationType.proxyDetected,
        message: 'Proxy found',
      );
      config.onViolation?.call(event);
      expect(capturedEvent?.type, SecurityViolationType.proxyDetected);
      expect(capturedEvent?.message, 'Proxy found');
      expect(capturedEvent?.timestamp, isNotNull);
    });

    test('SecurityViolationEvent preserves custom timestamp and formats toString', () {
      final testTime = DateTime(2026, 9, 5, 2, 0, 0);
      final event = SecurityViolationEvent(
        type: SecurityViolationType.spkiPinningMismatch,
        message: 'Cert mismatch',
        timestamp: testTime,
      );
      expect(event.type, SecurityViolationType.spkiPinningMismatch);
      expect(event.message, 'Cert mismatch');
      expect(event.timestamp, testTime);
      expect(
        event.toString(),
        'SecurityViolationEvent(type: SecurityViolationType.spkiPinningMismatch, message: Cert mismatch, time: $testTime)',
      );
    });

    test('SecurityViolationType contains all required violation types', () {
      expect(SecurityViolationType.values, containsAll([
        SecurityViolationType.spkiPinningMismatch,
        SecurityViolationType.proxyDetected,
        SecurityViolationType.debuggerDetected,
        SecurityViolationType.rootDetected,
      ]));
      expect(SecurityViolationType.values.length, 4);
    });

    test('throws UnsupportedError when isRelease is true and isEnforced is false', () {
      expect(
        () => KeemosSecurityConfig(isEnforced: false, isRelease: true),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('allows isEnforced is true when isRelease is true', () {
      expect(
        () => KeemosSecurityConfig(isEnforced: true, isRelease: true),
        returnsNormally,
      );
    });

    test('allows isEnforced is false when isRelease is false', () {
      final config = KeemosSecurityConfig(isEnforced: false, isRelease: false);
      expect(config.isEnforced, isFalse);
    });
  });
}

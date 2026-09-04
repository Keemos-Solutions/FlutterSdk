import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode, visibleForTesting;
import 'security_violation_event.dart';

class KeemosSecurityConfig {
  final bool isEnforced;
  final List<String> pinnedSpkiHashes;
  final bool blockProxies;
  final void Function(SecurityViolationEvent event)? onViolation;

  KeemosSecurityConfig({
    bool? isEnforced,
    this.pinnedSpkiHashes = const [],
    this.blockProxies = true,
    this.onViolation,
    @visibleForTesting bool? isRelease,
  }) : isEnforced = isEnforced ?? !kDebugMode {
    final effectiveIsRelease = isRelease ?? kReleaseMode;
    if (effectiveIsRelease && !this.isEnforced) {
      throw UnsupportedError(
        'Security guardrails cannot be disabled in release builds.',
      );
    }
  }
}

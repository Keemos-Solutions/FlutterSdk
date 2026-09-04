import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
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
  }) : isEnforced = isEnforced ?? !kDebugMode {
    if (kReleaseMode && !this.isEnforced) {
      throw UnsupportedError(
        'Security guardrails cannot be disabled in release builds.',
      );
    }
  }
}

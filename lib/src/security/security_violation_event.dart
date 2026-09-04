enum SecurityViolationType {
  spkiPinningMismatch,
  proxyDetected,
  debuggerDetected,
  rootDetected,
}

class SecurityViolationEvent {
  final SecurityViolationType type;
  final String message;
  final DateTime timestamp;

  SecurityViolationEvent({
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'SecurityViolationEvent(type: $type, message: $message, time: $timestamp)';
}

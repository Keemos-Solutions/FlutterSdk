import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'keemos_ws_url.dart';

/// Server → client event (IoT platform WebSocket).
class KeemosWsInboundEvent {
  final String event;
  final String? deviceId;
  final Map<String, dynamic> data;
  final String? householdId;

  const KeemosWsInboundEvent({
    required this.event,
    this.deviceId,
    this.data = const {},
    this.householdId,
  });

  factory KeemosWsInboundEvent.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    Map<String, dynamic> data = {};
    if (rawData is Map<String, dynamic>) {
      data = Map<String, dynamic>.from(rawData);
    } else if (rawData is Map) {
      data = Map<String, dynamic>.from(
        rawData.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return KeemosWsInboundEvent(
      event: json['event']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString(),
      data: data,
      householdId:
          json['household_id']?.toString() ?? json['householdId']?.toString(),
    );
  }
}

typedef KeemosAccessTokenGetter = Future<String?> Function();

/// Parses one text WebSocket frame (may contain multiple newline-delimited JSON lines).
/// Empty lines are skipped; [`event` == `pong`] entries are omitted (heartbeat).
List<KeemosWsInboundEvent> parseKeemosWsTextFrame(String message) {
  final out = <KeemosWsInboundEvent>[];
  for (final raw in message.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    Map<String, dynamic>? map;
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {
      continue;
    }
    if (map == null) continue;
    final ev = KeemosWsInboundEvent.fromJson(map);
    if (ev.event == 'pong') continue;
    out.add(ev);
  }
  return out;
}

/// WebSocket client: `/api/v1/ws`, newline-delimited JSON, reconnect with backoff.
class KeemosDeviceWebSocketController {
  KeemosDeviceWebSocketController({
    required this.resolveBaseUrl,
    required this.getAccessToken,
    required this.onEvent,
  });

  final String Function() resolveBaseUrl;
  final KeemosAccessTokenGetter getAccessToken;
  final void Function(KeemosWsInboundEvent event) onEvent;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  String? _householdId;
  bool _disposed = false;

  static const _maxBackoffMs = 30000;
  static const _baseBackoffMs = 500;

  Future<void> start(String householdId) async {
    _householdId = householdId;
    _disposed = false;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final hid = _householdId;
    if (hid == null) return;

    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;

    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final uri = buildKeemosWebSocketUri(
      httpBaseUrl: resolveBaseUrl(),
      token: token,
      householdId: hid,
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _attempt = 0;
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    for (final ev in parseKeemosWsTextFrame(message)) {
      onEvent(ev);
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final jitter = Random().nextInt(400);
    final exp = min(
      _maxBackoffMs,
      _baseBackoffMs * (1 << min(_attempt, 6)),
    );
    _attempt++;
    _reconnectTimer = Timer(Duration(milliseconds: exp + jitter), () {
      if (!_disposed) _connect();
    });
  }

  void sendPing() {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode({'action': 'ping'}));
    } catch (_) {}
  }

  void sendSubscribe(String householdId) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(
        jsonEncode({'action': 'subscribe', 'household_id': householdId}),
      );
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _householdId = null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:centrifuge/centrifuge.dart' as centrifuge;

import '../client.dart';

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

/// Parses newline-delimited JSON text frames for legacy/raw WebSocket connections.
List<KeemosWsInboundEvent> parseKeemosWsTextFrame(String text) {
  final lines = const LineSplitter().convert(text);
  final events = <KeemosWsInboundEvent>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        if (decoded['event'] == 'pong') continue;
        events.add(KeemosWsInboundEvent.fromJson(decoded));
      }
    } catch (_) {}
  }
  return events;
}

/// Centrifugo-based WebSocket controller for real-time telemetry.
class KeemosDeviceWebSocketController {
  KeemosDeviceWebSocketController({
    required this.client,
    required this.onEvent,
  });

  final KeemosClient client;
  final void Function(KeemosWsInboundEvent event) onEvent;

  centrifuge.Client? _centrifugeClient;
  centrifuge.Subscription? _subscription;
  StreamSubscription<centrifuge.PublicationEvent>? _pubSub;
  StreamSubscription<centrifuge.ConnectedEvent>? _connectedSub;
  StreamSubscription<centrifuge.DisconnectedEvent>? _disconnectedSub;

  Timer? _reconnectTimer;
  int _attempt = 0;
  String? _householdId;
  bool _isConnecting = false;
  bool _disposed = false;

  static const _maxBackoffMs = 30000;
  static const _baseBackoffMs = 1000;

  Future<void> start(String householdId) async {
    developer.log('Starting WebSocket for household: $householdId', name: 'KeemosWS');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _householdId = householdId;
    _disposed = false;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _isConnecting) return;
    final hid = _householdId;
    if (hid == null) return;

    _isConnecting = true;
    await _cleanup();

    try {
      developer.log('Fetching connection token...', name: 'KeemosWS');
      final wsTokenResp = await client.post('/api/v1/ws/token');
      if (_disposed || _householdId != hid) return;

      final wsTokenData = wsTokenResp.data as Map<String, dynamic>;
      final connectionToken = wsTokenData['token'] as String;
      final centrifugoUrl = wsTokenData['centrifugo_url'] as String;

      developer.log('Initializing Centrifugo client with URL: $centrifugoUrl', name: 'KeemosWS');
      final config = centrifuge.ClientConfig(
        token: connectionToken,
        getToken: (event) async {
          developer.log('Refreshing expired connection token...', name: 'KeemosWS');
          try {
            final resp = await client.post('/api/v1/ws/token');
            final data = resp.data as Map<String, dynamic>;
            return data['token'] as String;
          } catch (e) {
            developer.log('Failed to refresh connection token: $e', name: 'KeemosWS', error: e);
            return '';
          }
        },
      );

      final cClient = centrifuge.createClient(centrifugoUrl, config);
      _centrifugeClient = cClient;

      _connectedSub = cClient.connected.listen((e) {
        developer.log('Successfully connected to Centrifugo server', name: 'KeemosWS');
        _attempt = 0;
      });

      _disconnectedSub = cClient.disconnected.listen((e) {
        developer.log('Disconnected from Centrifugo server (code: ${e.code}, reason: ${e.reason})', name: 'KeemosWS');
      });

      developer.log('Connecting to Centrifugo...', name: 'KeemosWS');
      await cClient.connect();

      if (_disposed || _centrifugeClient != cClient || _householdId != hid) return;

      developer.log('Fetching channel token for household: $hid', name: 'KeemosWS');
      final channelTokenResp = await client.post(
        '/api/v1/ws/channel-token',
        data: {'household_id': hid},
      );
      if (_disposed || _centrifugeClient != cClient || _householdId != hid) return;

      final channelTokenData = channelTokenResp.data as Map<String, dynamic>;
      final channelToken = channelTokenData['token'] as String;
      final channelName = channelTokenData['channel'] as String;

      developer.log('Subscribing to channel: $channelName', name: 'KeemosWS');
      final subConfig = centrifuge.SubscriptionConfig(
        token: channelToken,
        getToken: (event) async {
          developer.log('Refreshing expired channel token...', name: 'KeemosWS');
          try {
            final resp = await client.post(
              '/api/v1/ws/channel-token',
              data: {'household_id': hid},
            );
            final data = resp.data as Map<String, dynamic>;
            return data['token'] as String;
          } catch (e) {
            developer.log('Failed to refresh channel token: $e', name: 'KeemosWS', error: e);
            return '';
          }
        },
      );

      final sub = cClient.newSubscription(channelName, subConfig);
      _subscription = sub;

      _pubSub = sub.publication.listen((event) {
        try {
          final rawData = utf8.decode(event.data);
          final payload = jsonDecode(rawData);
          if (payload is Map) {
            final ev = KeemosWsInboundEvent.fromJson(Map<String, dynamic>.from(payload));
            onEvent(ev);
          }
        } catch (e) {
          developer.log('Error parsing websocket event payload: $e', name: 'KeemosWS', error: e);
        }
      });

      await sub.subscribe();
      developer.log('Subscription request sent for $channelName', name: 'KeemosWS');

    } catch (e) {
      developer.log('WebSocket connection error: $e', name: 'KeemosWS', error: e);
      if (!_disposed) {
        _scheduleReconnect();
      }
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final jitter = 100 + (DateTime.now().millisecondsSinceEpoch % 400);
    final exp = (1 << (_attempt > 6 ? 6 : _attempt)) * _baseBackoffMs;
    final backoff = exp < _maxBackoffMs ? exp : _maxBackoffMs;
    _attempt++;

    developer.log('Scheduling reconnect in ${backoff + jitter}ms (attempt $_attempt)', name: 'KeemosWS');
    _reconnectTimer = Timer(Duration(milliseconds: backoff + jitter), () {
      if (!_disposed) _connect();
    });
  }

  Future<void> _cleanup() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _pubSub?.cancel();
    _pubSub = null;
    await _connectedSub?.cancel();
    _connectedSub = null;
    await _disconnectedSub?.cancel();
    _disconnectedSub = null;

    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      try {
        await sub.unsubscribe();
      } catch (_) {}
    }

    final cClient = _centrifugeClient;
    _centrifugeClient = null;
    if (cClient != null) {
      try {
        await cClient.disconnect();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    developer.log('Disposing KeemosDeviceWebSocketController', name: 'KeemosWS');
    _disposed = true;
    _attempt = 0;
    await _cleanup();
    _householdId = null;
  }
}

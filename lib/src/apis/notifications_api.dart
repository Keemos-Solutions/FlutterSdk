import '../client.dart';

class NotificationsApi {
  final KeemosClient client;

  NotificationsApi(this.client);

  Future<List<Map<String, dynamic>>> listNotifications(
      {int? limit, int? offset}) async {
    final resp = await client.get('/api/v1/notifications', queryParameters: {
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    });
    return _extractNotificationRows(resp.data);
  }

  Future<bool> markRead(String notificationId) async {
    final resp =
        await client.post('/api/v1/notifications/$notificationId/read');
    await client.invalidateCacheByPrefix('/api/v1/notifications');
    return resp.statusCode != null &&
        resp.statusCode! >= 200 &&
        resp.statusCode! < 300;
  }

  /// Register an FCM token for the current user.
  Future<Map<String, dynamic>> registerFcmToken({
    required String token,
    String? deviceId,
    String? platform,
  }) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('token must be at least 1 character.');
    }

    final payload = <String, dynamic>{
      'token': token,
      if (deviceId != null) 'device_id': deviceId,
      if (platform != null) 'platform': platform,
    };

    final resp =
        await client.post('/api/v1/notifications/fcm-tokens', data: payload);
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    await client.invalidateCacheByPrefix('/api/v1/notifications/fcm-tokens');
    return data.cast<String, dynamic>();
  }

  /// Unregister an FCM token for the current user.
  Future<void> unregisterFcmToken({required String token}) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('token must be at least 1 character.');
    }

    await client.dio.delete(
      '/api/v1/notifications/fcm-tokens',
      data: {'token': token},
    );
    await client.invalidateCacheByPrefix('/api/v1/notifications/fcm-tokens');
  }

  /// List FCM tokens of the current user.
  Future<List<Map<String, dynamic>>> listFcmTokens() async {
    final resp = await client.get('/api/v1/notifications/fcm-tokens');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _extractNotificationRows(dynamic rawBody) {
    final body = _toStringDynamicMap(rawBody);
    final candidates = <dynamic>[
      rawBody,
      body['data'],
      body['items'],
      body['notifications'],
    ];

    final dataMap = _toStringDynamicMap(body['data']);
    if (dataMap.isNotEmpty) {
      candidates
        ..add(dataMap['items'])
        ..add(dataMap['notifications'])
        ..add(dataMap['rows'])
        ..add(dataMap['results']);
    }

    for (final candidate in candidates) {
      final rows = _toNotificationRows(candidate);
      if (rows.isNotEmpty) return rows;
    }
    return const [];
  }

  List<Map<String, dynamic>> _toNotificationRows(dynamic node) {
    if (node is List) {
      final rows = <Map<String, dynamic>>[];
      for (final item in node) {
        final map = _toStringDynamicMap(item);
        if (map.isNotEmpty) rows.add(map);
      }
      return rows;
    }

    if (node is Map) {
      final map = _toStringDynamicMap(node);
      if (map.isEmpty) return const [];

      final values = map.values
          .map(_toStringDynamicMap)
          .where((m) => m.isNotEmpty)
          .toList();
      if (values.length == map.length && values.isNotEmpty) {
        return values;
      }

      if (_looksLikeNotificationRow(map)) {
        return [map];
      }
    }

    return const [];
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic node) {
    if (node is Map<String, dynamic>) return node;
    if (node is Map) {
      return node.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  bool _looksLikeNotificationRow(Map<String, dynamic> map) {
    return map.containsKey('id') ||
        map.containsKey('notification_id') ||
        map.containsKey('title') ||
        map.containsKey('message') ||
        map.containsKey('body');
  }
}

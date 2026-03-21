import '../client.dart';

class NotificationsApi {
  final KeemosClient client;

  NotificationsApi(this.client);

  Future<List<Map<String, dynamic>>> listNotifications({int? limit, int? offset}) async {
    final resp = await client.get('/api/v1/notifications', queryParameters: {
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    });
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<bool> markRead(String notificationId) async {
    final resp = await client.post('/api/v1/notifications/$notificationId/read');
    await client.invalidateCacheByPrefix('/api/v1/notifications');
    return resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300;
  }
}

import '../client.dart';

class RoomsApi {
  final KeemosClient client;

  RoomsApi(this.client);

  /// List rooms in a household. If the server returns wrapped `data`, unwrap it.
  Future<List<Map<String, dynamic>>> listRooms(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/rooms');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Get a single room by id (best-effort; may return null when not found)
  Future<Map<String, dynamic>?> getRoom(String householdId, String roomId) async {
    final resp = await client.get('/api/v1/households/$householdId/rooms/$roomId');
    final body = resp.data as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return payload.cast<String, dynamic>();
  }
}

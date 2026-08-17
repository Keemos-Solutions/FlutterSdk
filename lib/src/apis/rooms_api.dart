import '../client.dart';

class RoomsApi {
  final KeemosClient client;

  RoomsApi(this.client);

  /// List rooms in a household. If the server returns wrapped `data`, unwrap it.
  Future<List<Map<String, dynamic>>> listRooms(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/rooms');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Get a single room by id (best-effort; may return null when not found)
  Future<Map<String, dynamic>?> getRoom(String householdId, String roomId) async {
    final resp = await client.get('/api/v1/households/$householdId/rooms/$roomId');
    final body = resp.data as Map<String, dynamic>;
    final payload = body['data'] as Map<String, dynamic>? ?? body;
    return Map<String, dynamic>.from(payload);
  }

  /// Create a room in a household (`POST /api/v1/households/{id}/rooms`).
  Future<Map<String, dynamic>> createRoom(
    String householdId,
    Map<String, dynamic> payload,
  ) async {
    final resp = await client.post('/api/v1/households/$householdId/rooms', data: payload);
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/rooms');
    return Map<String, dynamic>.from(data);
  }

  /// Update a room's information (`PUT /api/v1/households/{household_id}/rooms/{room_id}`).
  Future<Map<String, dynamic>> updateRoom(
    String householdId,
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    final resp = await client.put(
      '/api/v1/households/$householdId/rooms/$roomId',
      data: payload,
    );
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/rooms');
    return Map<String, dynamic>.from(data);
  }

  /// Delete a room (`DELETE /api/v1/households/{household_id}/rooms/{room_id}`).
  Future<void> deleteRoom(String householdId, String roomId) async {
    await client.delete('/api/v1/households/$householdId/rooms/$roomId');
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/rooms');
  }
}

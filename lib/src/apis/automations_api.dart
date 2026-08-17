import '../client.dart';

class AutomationsApi {
  final KeemosClient client;

  AutomationsApi(this.client);

  /// List automations for household. Route: GET /api/v1/households/{householdId}/automations
  Future<List<Map<String, dynamic>>> listAutomations(String householdId) async {
    final resp = await client.get('/api/v1/households/$householdId/automations');
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Get single automation by ID. Route: GET /api/v1/households/{householdId}/automations/{automationId}
  Future<Map<String, dynamic>> getAutomation(String householdId, String automationId) async {
    final resp = await client.get('/api/v1/households/$householdId/automations/$automationId');
    final body = resp.data as Map<String, dynamic>;
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  /// Create a new automation. Route: POST /api/v1/households/{householdId}/automations
  Future<Map<String, dynamic>> createAutomation(String householdId, Map<String, dynamic> data) async {
    final resp = await client.post('/api/v1/households/$householdId/automations', data: data);
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/automations');
    final body = resp.data as Map<String, dynamic>;
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  /// Update an existing automation. Route: PUT /api/v1/households/{householdId}/automations/{automationId}
  Future<Map<String, dynamic>> updateAutomation(
    String householdId,
    String automationId,
    Map<String, dynamic> data,
  ) async {
    final resp = await client.put('/api/v1/households/$householdId/automations/$automationId', data: data);
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/automations');
    final body = resp.data as Map<String, dynamic>;
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }

  /// Toggle enabled state of an automation. Route: PATCH /api/v1/households/{householdId}/automations/{automationId}/toggle
  Future<bool> toggleAutomation(
    String householdId,
    String automationId, {
    required bool enabled,
  }) async {
    final resp = await client.patch(
      '/api/v1/households/$householdId/automations/$automationId/toggle',
      data: {'enabled': enabled},
    );
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/automations');
    return resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300;
  }

  /// Delete an automation. Route: DELETE /api/v1/households/{householdId}/automations/{automationId}
  Future<void> deleteAutomation(String householdId, String automationId) async {
    await client.delete('/api/v1/households/$householdId/automations/$automationId');
    await client.invalidateCacheByPrefix('/api/v1/households/$householdId/automations');
  }
}

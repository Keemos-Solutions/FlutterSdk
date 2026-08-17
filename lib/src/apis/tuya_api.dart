import '../client.dart';
import '../generated/device_models.dart';
import '../models_integration.dart';

class TuyaApi {
  final KeemosClient client;

  TuyaApi(this.client);

  /// Initiates Tuya cloud OAuth linking for a household. Returns authorization URL.
  /// Route: POST /api/v1/integrations/tuya/link
  Future<TuyaLinkResult> initiateLink(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.post(
      '/api/v1/integrations/tuya/link',
      data: {'household_id': householdId},
    );
    final body = resp.data as Map<String, dynamic>;
    final data = (body['data'] is Map<String, dynamic>)
        ? body['data'] as Map<String, dynamic>
        : body;
    return TuyaLinkResult.fromJson(data);
  }

  /// Synchronizes devices from linked Tuya account into Keemos device inventory.
  /// Route: POST /api/v1/integrations/tuya/sync
  Future<List<Device>> syncDevices(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.post(
      '/api/v1/integrations/tuya/sync',
      data: {'household_id': householdId},
    );
    final body = resp.data as Map<String, dynamic>;
    final list = (body['data'] is List) ? body['data'] as List : <dynamic>[];

    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');

    return list
        .whereType<Map>()
        .map((e) => Device.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// List active external platform integrations for a household.
  /// Route: GET /api/v1/integrations?household_id={householdId}
  Future<List<HouseholdIntegration>> listIntegrations(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.get(
      '/api/v1/integrations',
      queryParameters: {'household_id': householdId},
    );
    final body = resp.data as Map<String, dynamic>;
    final list = (body['data'] is List) ? body['data'] as List : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => HouseholdIntegration.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Unlink an external integration by ID.
  /// Route: DELETE /api/v1/integrations/{id}
  Future<void> unlinkIntegration(String integrationId) async {
    if (integrationId.trim().isEmpty) {
      throw ArgumentError('integrationId is required');
    }
    await client.delete('/api/v1/integrations/$integrationId');
    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');
  }

  /// List webhook/sync events for an integration.
  /// Route: GET /api/v1/integrations/{id}/events
  Future<List<Map<String, dynamic>>> listEvents(
    String integrationId, {
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await client.get(
      '/api/v1/integrations/$integrationId/events',
      queryParameters: {'page': page, 'limit': limit},
    );
    final body = resp.data as Map<String, dynamic>;
    final data = (body['data'] is List) ? body['data'] as List : <dynamic>[];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

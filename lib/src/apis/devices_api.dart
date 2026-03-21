import '../cache.dart';
import '../client.dart';
import '../generated/device_models.dart';

class DevicesApi {
  final KeemosClient client;

  DevicesApi(this.client);

  /// Get current device state. Returns a [DeviceState] parsed from response.
  Future<DeviceState> getDeviceState(String deviceId) async {
    final resp = await client.get(
      '/api/v1/devices/$deviceId/state',
      cacheOptions: const CacheOptions(ttl: Duration(seconds: 20)),
    );
    final body = resp.data as Map<String, dynamic>;
    // Some APIs return { data: { ... } }, some return the object directly
    final payload = (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : body;
    return DeviceState.fromJson(payload);
  }

  /// List devices for a household. Delegates to households endpoint.
  Future<List<Device>> listDevicesInHousehold(String householdId) async {
    final resp = await client.get(
      '/api/v1/households/$householdId/devices',
      cacheOptions: const CacheOptions(ttl: Duration(seconds: 60)),
    );
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }
}

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

  /// Send a command to a device.
  /// 
  /// [callType] - 'oneway' or 'twoway'
  /// [deviceId] - ID of the device to control
  /// [command] - Command payload as a JSON object
  /// 
  /// Returns the server response. For 'twoway' the API returns the device response directly.
  Future<Map<String, dynamic>> sendCommand(
    String callType,
    String deviceId,
    Map<String, dynamic> command,
  ) async {
    if (!['oneway', 'twoway'].contains(callType)) {
      throw ArgumentError('callType must be either "oneway" or "twoway"');
    }

    final resp = await client.post(
      '/api/v1/commands/$callType/$deviceId',
      data: command,
    );
    final body = resp.data as Map<String, dynamic>;

    // API returns final response directly for twoway; return as-is for both modes
    return body;
  }

  /// Update device metadata/config.
  ///
  /// Supports updating any subset of fields via [name], [roomId], and [config].
  /// Returns the updated [Device].
  Future<Device> updateDevice(
    String deviceId, {
    String? name,
    String? roomId,
    Map<String, dynamic>? config,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (roomId != null) 'room_id': roomId,
      if (config != null) 'config': config,
    };

    if (payload.isEmpty) {
      throw ArgumentError('At least one field must be provided for updateDevice.');
    }

    final resp = await client.dio.patch('/api/v1/devices/$deviceId', data: payload);
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');

    return Device.fromJson(data);
  }
}

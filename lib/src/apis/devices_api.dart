import '../cache.dart';
import '../client.dart';
import '../generated/device_models.dart';

class DevicesApi {
  final KeemosClient client;

  DevicesApi(this.client);

  /// Get current device state từ GET /api/v1/devices/{deviceId}.
  /// Backend không có /state riêng — state được embed trong device object.
  Future<DeviceState> getDeviceState(String deviceId) async {
    final resp = await client.get(
      '/api/v1/devices/$deviceId',
      cacheOptions: const CacheOptions(ttl: Duration(seconds: 20)),
    );
    final body = resp.data as Map<String, dynamic>;
    // Thử lấy từ body['data']['state'], body['data'], hoặc body trực tiếp
    final data = (body['data'] is Map<String, dynamic>)
        ? body['data'] as Map<String, dynamic>
        : body;
    final statePayload = (data['state'] is Map<String, dynamic>)
        ? data['state'] as Map<String, dynamic>
        : data;
    return DeviceState.fromJson(statePayload);
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

  /// Turn power ON/OFF for a device (or specific switch gang).
  Future<Map<String, dynamic>> setPower(
    String deviceId,
    bool power, {
    int? gangIndex,
    String callType = 'oneway',
  }) {
    final params = gangIndex != null
        ? {'switch_$gangIndex': power}
        : {'power': power};
    return sendCommand(callType, deviceId, {
      'command_type': 'SET_POWER',
      'params': params,
    });
  }

  /// Set brightness percentage (1 - 100).
  Future<Map<String, dynamic>> setBrightness(
    String deviceId,
    int brightness, {
    String callType = 'oneway',
  }) {
    final clamped = brightness.clamp(1, 100);
    return sendCommand(callType, deviceId, {
      'command_type': 'SET_BRIGHTNESS',
      'params': {'brightness': clamped},
    });
  }

  /// Set light color temperature in Kelvin (2700K - 6500K).
  Future<Map<String, dynamic>> setColorTemperature(
    String deviceId,
    int kelvin, {
    String callType = 'oneway',
  }) {
    final clamped = kelvin.clamp(2700, 6500);
    return sendCommand(callType, deviceId, {
      'command_type': 'SET_COLOR_TEMP',
      'params': {'color_temp': clamped},
    });
  }

  /// Set target temperature for climate / thermostat devices.
  Future<Map<String, dynamic>> setThermostatTemperature(
    String deviceId,
    double targetTemperature, {
    String callType = 'oneway',
  }) {
    return sendCommand(callType, deviceId, {
      'command_type': 'SET_TEMPERATURE',
      'params': {'target_temperature': targetTemperature},
    });
  }

  /// Update device metadata/config.
  ///
  /// Supports updating metadata via [name] and [roomId], and configuration via [config].
  /// Returns the updated [Device].
  Future<Device> updateDevice(
    String deviceId, {
    String? name,
    String? roomId,
    Map<String, dynamic>? config,
  }) async {
    final patchPayload = <String, dynamic>{
      if (name != null) 'name': name,
      if (roomId != null) 'room_id': roomId,
    };

    if (patchPayload.isEmpty && config == null) {
      throw ArgumentError('At least one field must be provided for updateDevice.');
    }

    if (config != null) {
      await updateDeviceConfig(deviceId, config);
    }

    if (patchPayload.isNotEmpty) {
      final resp = await client.patch('/api/v1/devices/$deviceId', data: patchPayload);
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      await client.invalidateCacheByPrefix('/api/v1/devices');
      await client.invalidateCacheByPrefix('/api/v1/households');

      return Device.fromJson(data);
    }

    final resp = await client.get('/api/v1/devices/$deviceId', cacheOptions: const CacheOptions(forceRefresh: true));
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return Device.fromJson(data);
  }

  /// Update device configuration (JSONB) via PUT /api/v1/devices/{deviceId}/config.
  Future<Map<String, dynamic>> updateDeviceConfig(
    String deviceId,
    Map<String, dynamic> config,
  ) async {
    final resp = await client.put('/api/v1/devices/$deviceId/config', data: {'config': config});
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');

    return data;
  }
}

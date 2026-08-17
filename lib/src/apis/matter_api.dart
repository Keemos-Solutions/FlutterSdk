import '../cache.dart';
import '../client.dart';
import '../models_matter.dart';

/// Matter cloud APIs (inventory + opaque E2E fabric package / HFSK wraps).
///
/// Paths match core-api:
/// - POST   /api/v1/households/{id}/matter/devices
/// - PATCH  /api/v1/devices/{deviceId}/matter
/// - PUT/GET /api/v1/households/{id}/matter/fabric-package
/// - GET    /api/v1/households/{id}/matter/fabric-package/meta
/// - POST   /api/v1/households/{id}/matter/controllers/me
/// - GET    /api/v1/households/{id}/matter/controllers
/// - PUT    /api/v1/households/{id}/matter/hfsk-wraps/{userId}
/// - GET    /api/v1/households/{id}/matter/hfsk-wraps/me
class MatterApi {
  final KeemosClient client;

  MatterApi(this.client);

  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) {
        return Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return body;
    }
    if (body is Map) {
      return Map<String, dynamic>.from(
        body.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    throw StateError('Unexpected Matter API response: ${body.runtimeType}');
  }

  List<dynamic> _dataList(dynamic body) {
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
      return const [];
    }
    if (body is List) return body;
    return const [];
  }

  Future<void> _invalidateMatterCaches(String householdId) async {
    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');
    await client.invalidateCacheByPrefix(
      '/api/v1/households/$householdId/matter',
    );
  }

  /// POST /api/v1/households/{householdId}/matter/devices
  Future<RegisterMatterDeviceResult> registerDevice(
    String householdId,
    RegisterMatterDeviceRequest request,
  ) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    if (request.name.trim().isEmpty) {
      throw ArgumentError('name is required');
    }
    if (request.fabricId.trim().isEmpty || request.nodeId.trim().isEmpty) {
      throw ArgumentError('fabric_id and node_id are required');
    }

    final resp = await client.post(
      '/api/v1/households/$householdId/matter/devices',
      data: request.toJson(),
    );
    await _invalidateMatterCaches(householdId);
    return RegisterMatterDeviceResult.fromJson(_dataMap(resp.data));
  }

  /// PATCH /api/v1/devices/{deviceId}/matter
  Future<MatterDeviceBinding> patchDeviceMatter(
    String deviceId,
    PatchMatterDeviceRequest request,
  ) async {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError('deviceId is required');
    }
    final resp = await client.patch(
      '/api/v1/devices/$deviceId/matter',
      data: request.toJson(),
    );
    await client.invalidateCacheByPrefix('/api/v1/devices');
    await client.invalidateCacheByPrefix('/api/v1/households');
    return MatterDeviceBinding.fromJson(_dataMap(resp.data));
  }

  /// PUT /api/v1/households/{householdId}/matter/fabric-package
  Future<MatterFabricPackage> putFabricPackage(
    String householdId,
    PutFabricPackageRequest request,
  ) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    if (request.version < 1) {
      throw ArgumentError('version must be >= 1');
    }
    if (request.alg.trim().isEmpty ||
        request.keyId.trim().isEmpty ||
        request.nonceB64.trim().isEmpty ||
        request.ciphertextB64.trim().isEmpty) {
      throw ArgumentError(
        'alg, key_id, nonce_b64, and ciphertext_b64 are required',
      );
    }
    final maxB64Len = (maxMatterFabricCiphertextBytes * 4 / 3).ceil();
    if (request.ciphertextB64.length > maxB64Len) {
      throw ArgumentError(
        'Fabric package ciphertext exceeds maximum allowed size ($maxMatterFabricCiphertextBytes bytes)',
      );
    }

    final resp = await client.put(
      '/api/v1/households/$householdId/matter/fabric-package',
      data: request.toJson(),
    );
    await client.invalidateCacheByPrefix(
      '/api/v1/households/$householdId/matter/fabric-package',
    );
    return MatterFabricPackage.fromJson(_dataMap(resp.data));
  }

  /// GET /api/v1/households/{householdId}/matter/fabric-package (includes ciphertext)
  Future<MatterFabricPackage> getFabricPackage(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.get(
      '/api/v1/households/$householdId/matter/fabric-package',
      cacheOptions: const CacheOptions(enabled: false),
    );
    return MatterFabricPackage.fromJson(_dataMap(resp.data));
  }

  /// GET /api/v1/households/{householdId}/matter/fabric-package/meta
  Future<MatterFabricPackageMeta> getFabricPackageMeta(
    String householdId,
  ) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.get(
      '/api/v1/households/$householdId/matter/fabric-package/meta',
      cacheOptions: const CacheOptions(
        ttl: Duration(seconds: 30),
        forceRefresh: true,
      ),
    );
    return MatterFabricPackageMeta.fromJson(_dataMap(resp.data));
  }

  /// POST /api/v1/households/{householdId}/matter/controllers/me
  Future<MatterController> upsertControllerMe(
    String householdId,
    UpsertMatterControllerRequest request,
  ) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.post(
      '/api/v1/households/$householdId/matter/controllers/me',
      data: request.toJson(),
    );
    await client.invalidateCacheByPrefix(
      '/api/v1/households/$householdId/matter/controllers',
    );
    return MatterController.fromJson(_dataMap(resp.data));
  }

  /// GET /api/v1/households/{householdId}/matter/controllers
  Future<List<MatterController>> listControllers(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.get(
      '/api/v1/households/$householdId/matter/controllers',
      cacheOptions: const CacheOptions(ttl: Duration(seconds: 45)),
    );
    return _dataList(resp.data)
        .whereType<Map>()
        .map(
          (e) => MatterController.fromJson(
            Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          ),
        )
        .toList();
  }

  /// PUT /api/v1/households/{householdId}/matter/hfsk-wraps/{userId}
  Future<MatterHFSKWrap> putHFSKWrap(
    String householdId,
    String targetUserId,
    PutHFSKWrapRequest request,
  ) async {
    if (householdId.trim().isEmpty || targetUserId.trim().isEmpty) {
      throw ArgumentError('householdId and targetUserId are required');
    }
    if (request.wrapCiphertextB64.trim().isEmpty ||
        request.wrapAlg.trim().isEmpty) {
      throw ArgumentError('wrap_ciphertext_b64 and wrap_alg are required');
    }
    final maxWrapB64Len = (maxMatterHFSKWrapBytes * 4 / 3).ceil();
    if (request.wrapCiphertextB64.length > maxWrapB64Len) {
      throw ArgumentError(
        'HFSK wrap ciphertext exceeds maximum allowed size ($maxMatterHFSKWrapBytes bytes)',
      );
    }

    final resp = await client.put(
      '/api/v1/households/$householdId/matter/hfsk-wraps/$targetUserId',
      data: request.toJson(),
    );
    await client.invalidateCacheByPrefix(
      '/api/v1/households/$householdId/matter/hfsk-wraps',
    );
    return MatterHFSKWrap.fromJson(_dataMap(resp.data));
  }

  /// GET /api/v1/households/{householdId}/matter/hfsk-wraps/me
  Future<MatterHFSKWrap> getHFSKWrapMe(String householdId) async {
    if (householdId.trim().isEmpty) {
      throw ArgumentError('householdId is required');
    }
    final resp = await client.get(
      '/api/v1/households/$householdId/matter/hfsk-wraps/me',
      cacheOptions: const CacheOptions(enabled: false),
    );
    return MatterHFSKWrap.fromJson(_dataMap(resp.data));
  }
}

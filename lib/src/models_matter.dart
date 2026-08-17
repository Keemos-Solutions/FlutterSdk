/// Matter API models matching core-api DTOs / domain JSON
/// (`docs/MOBILE_MATTER_INTEGRATION.md`).

/// Inventory endpoints must never carry these plaintext secret keys.
const List<String> matterForbiddenSecretFields = [
  'setup_code',
  'discriminator',
  'noc',
  'private_key',
  'ipk',
  'fabric_key',
  'pairing_code',
];

/// Max decoded fabric package ciphertext size (bytes).
const int maxMatterFabricCiphertextBytes = 262144;

/// Max decoded HFSK wrap ciphertext size (bytes).
const int maxMatterHFSKWrapBytes = 8192;

const String matterFabricAlgAes256Gcm = 'AES-256-GCM';
const String matterFabricKeyIdHfskV1 = 'hfsk-v1';
const String matterControllerKindPhone = 'phone';
const String matterControllerKindHub = 'hub';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }
  return const {};
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _readMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) {
    if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
    if (e is Map) {
      return Map<String, dynamic>.from(
        e.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }).toList();
}

/// Throws [ArgumentError] if [fields] include forbidden secrets at any depth
/// (nested maps and lists), matching server inventory validation.
void assertNoMatterSecrets(Map<String, dynamic> fields) {
  void walk(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (matterForbiddenSecretFields.contains(key)) {
          throw ArgumentError(
            'Matter inventory must not include secret field "$key"',
          );
        }
        walk(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        walk(item);
      }
    }
  }

  walk(fields);
}

// ─── Endpoint / summary / binding ────────────────────────────────────────────

class MatterEndpoint {
  final int endpointId;
  final List<int> deviceTypes;
  final List<int> clusters;

  const MatterEndpoint({
    required this.endpointId,
    this.deviceTypes = const [],
    this.clusters = const [],
  });

  factory MatterEndpoint.fromJson(Map<String, dynamic> json) {
    List<int> asIntList(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) {
        if (e is int) return e;
        if (e is num) return e.toInt();
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).toList();
    }

    return MatterEndpoint(
      endpointId: _readInt(json['endpoint_id'] ?? json['endpointId']) ?? 0,
      deviceTypes: asIntList(json['device_types'] ?? json['deviceTypes']),
      clusters: asIntList(json['clusters']),
    );
  }

  Map<String, dynamic> toJson() => {
        'endpoint_id': endpointId,
        'device_types': deviceTypes,
        'clusters': clusters,
      };
}

/// Nested `matter` object on device list/get responses.
class MatterDeviceSummary {
  final String fabricId;
  final String nodeId;
  final List<Map<String, dynamic>> endpoints;
  final String networkType;
  final int vendorId;
  final int productId;
  final int? primaryDeviceType;
  final String? uniqueId;

  const MatterDeviceSummary({
    required this.fabricId,
    required this.nodeId,
    this.endpoints = const [],
    this.networkType = 'unknown',
    this.vendorId = 0,
    this.productId = 0,
    this.primaryDeviceType,
    this.uniqueId,
  });

  factory MatterDeviceSummary.fromJson(Map<String, dynamic> json) {
    return MatterDeviceSummary(
      fabricId: '${json['fabric_id'] ?? json['fabricId'] ?? ''}',
      nodeId: '${json['node_id'] ?? json['nodeId'] ?? ''}',
      endpoints: _readMapList(json['endpoints']),
      networkType: '${json['network_type'] ?? json['networkType'] ?? 'unknown'}',
      vendorId: _readInt(json['vendor_id'] ?? json['vendorId']) ?? 0,
      productId: _readInt(json['product_id'] ?? json['productId']) ?? 0,
      primaryDeviceType:
          _readInt(json['primary_device_type'] ?? json['primaryDeviceType']),
      uniqueId: json['unique_id']?.toString() ?? json['uniqueId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'fabric_id': fabricId,
        'node_id': nodeId,
        'endpoints': endpoints,
        'network_type': networkType,
        'vendor_id': vendorId,
        'product_id': productId,
        if (primaryDeviceType != null) 'primary_device_type': primaryDeviceType,
        if (uniqueId != null) 'unique_id': uniqueId,
      };
}

class MatterDeviceBinding {
  final String id;
  final String deviceId;
  final String householdId;
  final String fabricId;
  final String nodeId;
  final int vendorId;
  final int productId;
  final String networkType;
  final List<Map<String, dynamic>> endpoints;
  final int? primaryDeviceType;
  final String? uniqueId;
  final DateTime? commissionedAt;
  final DateTime? lastInterviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MatterDeviceBinding({
    required this.id,
    required this.deviceId,
    required this.householdId,
    required this.fabricId,
    required this.nodeId,
    this.vendorId = 0,
    this.productId = 0,
    this.networkType = 'unknown',
    this.endpoints = const [],
    this.primaryDeviceType,
    this.uniqueId,
    this.commissionedAt,
    this.lastInterviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory MatterDeviceBinding.fromJson(Map<String, dynamic> json) {
    return MatterDeviceBinding(
      id: '${json['id'] ?? ''}',
      deviceId: '${json['device_id'] ?? json['deviceId'] ?? ''}',
      householdId: '${json['household_id'] ?? json['householdId'] ?? ''}',
      fabricId: '${json['fabric_id'] ?? json['fabricId'] ?? ''}',
      nodeId: '${json['node_id'] ?? json['nodeId'] ?? ''}',
      vendorId: _readInt(json['vendor_id'] ?? json['vendorId']) ?? 0,
      productId: _readInt(json['product_id'] ?? json['productId']) ?? 0,
      networkType: '${json['network_type'] ?? json['networkType'] ?? 'unknown'}',
      endpoints: _readMapList(json['endpoints']),
      primaryDeviceType:
          _readInt(json['primary_device_type'] ?? json['primaryDeviceType']),
      uniqueId: json['unique_id']?.toString() ?? json['uniqueId']?.toString(),
      commissionedAt:
          _readDateTime(json['commissioned_at'] ?? json['commissionedAt']),
      lastInterviewedAt: _readDateTime(
        json['last_interviewed_at'] ?? json['lastInterviewedAt'],
      ),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _readDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'household_id': householdId,
        'fabric_id': fabricId,
        'node_id': nodeId,
        'vendor_id': vendorId,
        'product_id': productId,
        'network_type': networkType,
        'endpoints': endpoints,
        if (primaryDeviceType != null) 'primary_device_type': primaryDeviceType,
        if (uniqueId != null) 'unique_id': uniqueId,
        'commissioned_at': commissionedAt?.toIso8601String(),
        'last_interviewed_at': lastInterviewedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

// ─── Register / patch ────────────────────────────────────────────────────────

class RegisterMatterDeviceRequest {
  final String name;
  final String fabricId;
  final String nodeId;
  final String? roomId;
  final String? profileId;
  final int vendorId;
  final int productId;
  final String? uniqueId;
  final String? networkType;
  final List<Map<String, dynamic>>? endpoints;
  final int? primaryDeviceType;
  final Map<String, dynamic>? state;

  const RegisterMatterDeviceRequest({
    required this.name,
    required this.fabricId,
    required this.nodeId,
    this.roomId,
    this.profileId,
    this.vendorId = 0,
    this.productId = 0,
    this.uniqueId,
    this.networkType,
    this.endpoints,
    this.primaryDeviceType,
    this.state,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'fabric_id': fabricId,
      'node_id': nodeId,
      'vendor_id': vendorId,
      'product_id': productId,
      if (roomId != null) 'room_id': roomId,
      if (profileId != null) 'profile_id': profileId,
      if (uniqueId != null) 'unique_id': uniqueId,
      if (networkType != null) 'network_type': networkType,
      if (endpoints != null) 'endpoints': endpoints,
      if (primaryDeviceType != null) 'primary_device_type': primaryDeviceType,
      if (state != null) 'state': state,
    };
    assertNoMatterSecrets(json);
    return json;
  }
}

class RegisterMatterDeviceResult {
  /// Raw device object from register response (parse with [Device.fromJson] if needed).
  final Map<String, dynamic> device;
  final MatterDeviceBinding binding;

  const RegisterMatterDeviceResult({
    required this.device,
    required this.binding,
  });

  factory RegisterMatterDeviceResult.fromJson(Map<String, dynamic> json) {
    final deviceRaw = _readMap(json['device']);
    final bindingRaw = _readMap(json['binding']);
    return RegisterMatterDeviceResult(
      device: deviceRaw,
      binding: MatterDeviceBinding.fromJson(bindingRaw),
    );
  }
}

class PatchMatterDeviceRequest {
  final List<Map<String, dynamic>>? endpoints;
  final String? networkType;
  final int? primaryDeviceType;
  final String? uniqueId;
  final int? vendorId;
  final int? productId;

  const PatchMatterDeviceRequest({
    this.endpoints,
    this.networkType,
    this.primaryDeviceType,
    this.uniqueId,
    this.vendorId,
    this.productId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      if (endpoints != null) 'endpoints': endpoints,
      if (networkType != null) 'network_type': networkType,
      if (primaryDeviceType != null) 'primary_device_type': primaryDeviceType,
      if (uniqueId != null) 'unique_id': uniqueId,
      if (vendorId != null) 'vendor_id': vendorId,
      if (productId != null) 'product_id': productId,
    };
    if (json.isEmpty) {
      throw ArgumentError('At least one field is required for patchMatterDevice');
    }
    assertNoMatterSecrets(json);
    return json;
  }
}

// ─── Fabric package ──────────────────────────────────────────────────────────

class PutFabricPackageRequest {
  final int version;
  final String alg;
  final String keyId;
  final String nonceB64;
  final String ciphertextB64;
  final String? aad;

  const PutFabricPackageRequest({
    required this.version,
    required this.alg,
    required this.keyId,
    required this.nonceB64,
    required this.ciphertextB64,
    this.aad,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'alg': alg,
        'key_id': keyId,
        'nonce_b64': nonceB64,
        'ciphertext_b64': ciphertextB64,
        if (aad != null) 'aad': aad,
      };
}

class MatterFabricPackage {
  final int version;
  final String alg;
  final String keyId;
  final String nonceB64;
  final String? ciphertextB64;
  final String? aad;
  final String? createdByUserId;
  final DateTime? createdAt;

  const MatterFabricPackage({
    required this.version,
    required this.alg,
    required this.keyId,
    required this.nonceB64,
    this.ciphertextB64,
    this.aad,
    this.createdByUserId,
    this.createdAt,
  });

  factory MatterFabricPackage.fromJson(Map<String, dynamic> json) {
    return MatterFabricPackage(
      version: _readInt(json['version']) ?? 0,
      alg: '${json['alg'] ?? ''}',
      keyId: '${json['key_id'] ?? json['keyId'] ?? ''}',
      nonceB64: '${json['nonce_b64'] ?? json['nonceB64'] ?? ''}',
      ciphertextB64:
          json['ciphertext_b64']?.toString() ?? json['ciphertextB64']?.toString(),
      aad: json['aad']?.toString(),
      createdByUserId: json['created_by_user_id']?.toString() ??
          json['createdByUserId']?.toString(),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'alg': alg,
        'key_id': keyId,
        'nonce_b64': nonceB64,
        if (ciphertextB64 != null) 'ciphertext_b64': ciphertextB64,
        if (aad != null) 'aad': aad,
        if (createdByUserId != null) 'created_by_user_id': createdByUserId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

class MatterFabricPackageMeta {
  final int version;
  final String alg;
  final String keyId;
  final String? aad;
  final String? createdByUserId;
  final DateTime? createdAt;

  const MatterFabricPackageMeta({
    required this.version,
    required this.alg,
    required this.keyId,
    this.aad,
    this.createdByUserId,
    this.createdAt,
  });

  factory MatterFabricPackageMeta.fromJson(Map<String, dynamic> json) {
    return MatterFabricPackageMeta(
      version: _readInt(json['version']) ?? 0,
      alg: '${json['alg'] ?? ''}',
      keyId: '${json['key_id'] ?? json['keyId'] ?? ''}',
      aad: json['aad']?.toString(),
      createdByUserId: json['created_by_user_id']?.toString() ??
          json['createdByUserId']?.toString(),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'alg': alg,
        'key_id': keyId,
        if (aad != null) 'aad': aad,
        if (createdByUserId != null) 'created_by_user_id': createdByUserId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

// ─── Controllers ─────────────────────────────────────────────────────────────

class UpsertMatterControllerRequest {
  final String kind;
  final String? label;
  final int? fabricPackageVersion;
  final String? hubDeviceId;

  const UpsertMatterControllerRequest({
    required this.kind,
    this.label,
    this.fabricPackageVersion,
    this.hubDeviceId,
  });

  Map<String, dynamic> toJson() {
    if (kind != matterControllerKindPhone && kind != matterControllerKindHub) {
      throw ArgumentError('kind must be "phone" or "hub"');
    }
    if (kind == matterControllerKindHub &&
        (hubDeviceId == null || hubDeviceId!.isEmpty)) {
      throw ArgumentError('hub_device_id is required when kind is hub');
    }
    return {
      'kind': kind,
      if (label != null) 'label': label,
      if (fabricPackageVersion != null)
        'fabric_package_version': fabricPackageVersion,
      if (hubDeviceId != null) 'hub_device_id': hubDeviceId,
    };
  }
}

class MatterController {
  final String id;
  final String householdId;
  final String kind;
  final String? userId;
  final String? hubDeviceId;
  final String? label;
  final int? fabricPackageVersion;
  final String? status;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;

  const MatterController({
    required this.id,
    required this.householdId,
    required this.kind,
    this.userId,
    this.hubDeviceId,
    this.label,
    this.fabricPackageVersion,
    this.status,
    this.lastSyncedAt,
    this.createdAt,
  });

  factory MatterController.fromJson(Map<String, dynamic> json) {
    return MatterController(
      id: '${json['id'] ?? ''}',
      householdId: '${json['household_id'] ?? json['householdId'] ?? ''}',
      kind: '${json['kind'] ?? ''}',
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      hubDeviceId:
          json['hub_device_id']?.toString() ?? json['hubDeviceId']?.toString(),
      label: json['label']?.toString(),
      fabricPackageVersion: _readInt(
        json['fabric_package_version'] ?? json['fabricPackageVersion'],
      ),
      status: json['status']?.toString(),
      lastSyncedAt:
          _readDateTime(json['last_synced_at'] ?? json['lastSyncedAt']),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'household_id': householdId,
        'kind': kind,
        if (userId != null) 'user_id': userId,
        if (hubDeviceId != null) 'hub_device_id': hubDeviceId,
        if (label != null) 'label': label,
        if (fabricPackageVersion != null)
          'fabric_package_version': fabricPackageVersion,
        if (status != null) 'status': status,
        if (lastSyncedAt != null)
          'last_synced_at': lastSyncedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

// ─── HFSK wraps ──────────────────────────────────────────────────────────────

class PutHFSKWrapRequest {
  final String wrapCiphertextB64;
  final String wrapAlg;

  const PutHFSKWrapRequest({
    required this.wrapCiphertextB64,
    required this.wrapAlg,
  });

  Map<String, dynamic> toJson() => {
        'wrap_ciphertext_b64': wrapCiphertextB64,
        'wrap_alg': wrapAlg,
      };
}

class MatterHFSKWrap {
  final String userId;
  final String wrapAlg;
  final String wrapCiphertextB64;
  final DateTime? updatedAt;

  const MatterHFSKWrap({
    required this.userId,
    required this.wrapAlg,
    required this.wrapCiphertextB64,
    this.updatedAt,
  });

  factory MatterHFSKWrap.fromJson(Map<String, dynamic> json) {
    return MatterHFSKWrap(
      userId: '${json['user_id'] ?? json['userId'] ?? ''}',
      wrapAlg: '${json['wrap_alg'] ?? json['wrapAlg'] ?? ''}',
      wrapCiphertextB64:
          '${json['wrap_ciphertext_b64'] ?? json['wrapCiphertextB64'] ?? ''}',
      updatedAt: _readDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'wrap_alg': wrapAlg,
        'wrap_ciphertext_b64': wrapCiphertextB64,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

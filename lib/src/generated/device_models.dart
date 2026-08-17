import '../models_matter.dart';

class Device {
  final String id;
  final String? householdId;
  final String? roomId;
  final String? userId;
  final String? profileId;
  final String? name;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? connectionType;
  final String? status;
  final Map<String, dynamic> state;
  final Map<String, dynamic> config;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? room;

  /// Present when the device has a `matter_device_bindings` row.
  final MatterDeviceSummary? matter;

  Device({
    required this.id,
    this.householdId,
    this.roomId,
    this.userId,
    this.profileId,
    this.name,
    this.serialNumber,
    this.firmwareVersion,
    this.connectionType,
    this.status,
    this.state = const {},
    this.config = const {},
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
    this.profile,
    this.room,
    this.matter,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    MatterDeviceSummary? matter;
    final rawMatter = json['matter'];
    if (rawMatter is Map<String, dynamic>) {
      matter = MatterDeviceSummary.fromJson(rawMatter);
    } else if (rawMatter is Map) {
      matter = MatterDeviceSummary.fromJson(
        Map<String, dynamic>.from(
          rawMatter.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }

    return Device(
      id: json['id'] ?? json['device_id'] ?? json['deviceId'] ?? '',
      householdId: json['household_id'] ?? json['householdId'],
      roomId: json['room_id'] ?? json['roomId'],
      userId: json['user_id'] ?? json['userId'],
      profileId: json['profile_id'] ?? json['profileId'],
      name: json['name'],
      serialNumber: json['serial_number'] ?? json['serialNumber'],
      firmwareVersion: json['firmware_version'] ?? json['firmwareVersion'],
      connectionType: json['connection_type'] ?? json['connectionType'],
      status: json['status'],
      state: _readMap(json['state']),
      config: _readMap(json['config']),
      lastSeenAt: _readDateTime(json['last_seen_at'] ?? json['lastSeenAt']),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _readDateTime(json['updated_at'] ?? json['updatedAt']),
      profile: _readNullableMap(json['profile']),
      room: _readNullableMap(json['room']),
      matter: matter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'household_id': householdId,
        'room_id': roomId,
        'user_id': userId,
        'profile_id': profileId,
        'name': name,
        'serial_number': serialNumber,
        'firmware_version': firmwareVersion,
        'connection_type': connectionType,
        'status': status,
        'state': state,
        'config': config,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'profile': profile,
        'room': room,
        if (matter != null) 'matter': matter!.toJson(),
      };
}

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

Map<String, dynamic>? _readNullableMap(dynamic value) {
  if (value == null) {
    return null;
  }
  return _readMap(value);
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

class DeviceState {
  final Map<String, dynamic> attributes;
  final DateTime? updatedAt;

  DeviceState({required this.attributes, this.updatedAt});

  factory DeviceState.fromJson(Map<String, dynamic> json) => DeviceState(
        attributes: (json['attributes'] as Map<String, dynamic>?) ?? (json['state'] as Map<String, dynamic>?) ?? Map<String, dynamic>.from(json),
        updatedAt: _readDateTime(json['updated_at'] ?? json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'attributes': attributes,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

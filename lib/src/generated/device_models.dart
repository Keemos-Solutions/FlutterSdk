class Device {
  final String id;
  final String? name;
  final String? householdId;

  Device({required this.id, this.name, this.householdId});

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? json['device_id'] ?? json['deviceId'] ?? '',
        name: json['name'],
        householdId: json['household_id'] ?? json['householdId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'household_id': householdId,
      };
}

class DeviceState {
  final Map<String, dynamic> attributes;
  final DateTime? updatedAt;

  DeviceState({required this.attributes, this.updatedAt});

  factory DeviceState.fromJson(Map<String, dynamic> json) => DeviceState(
        attributes: (json['attributes'] as Map<String, dynamic>?) ?? (json['state'] as Map<String, dynamic>?) ?? Map<String, dynamic>.from(json),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
      );

  Map<String, dynamic> toJson() => {
        'attributes': attributes,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

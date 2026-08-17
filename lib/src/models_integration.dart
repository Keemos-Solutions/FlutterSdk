/// Integration models matching core-api DTOs.
class TuyaLinkResult {
  final String authUrl;

  const TuyaLinkResult({required this.authUrl});

  factory TuyaLinkResult.fromJson(Map<String, dynamic> json) {
    return TuyaLinkResult(
      authUrl: json['auth_url'] as String? ?? json['authUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'auth_url': authUrl};
}

/// Represents an external platform integration (e.g. Tuya, Alexa, Google Home).
class HouseholdIntegration {
  final String id;
  final String householdId;
  final String integrationType;
  final String status;
  final String? externalAccountId;
  final Map<String, dynamic> metadata;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HouseholdIntegration({
    required this.id,
    required this.householdId,
    required this.integrationType,
    required this.status,
    this.externalAccountId,
    this.metadata = const {},
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory HouseholdIntegration.fromJson(Map<String, dynamic> json) {
    return HouseholdIntegration(
      id: json['id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? json['householdId']?.toString() ?? '',
      integrationType: json['integration_type']?.toString() ?? json['integrationType']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      externalAccountId: json['external_account_id']?.toString() ?? json['externalAccountId']?.toString(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.tryParse(json['last_synced_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'household_id': householdId,
        'integration_type': integrationType,
        'status': status,
        if (externalAccountId != null) 'external_account_id': externalAccountId,
        'metadata': metadata,
        if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

enum HouseholdType {
  house('house'),
  apartment('apartment'),
  condo('condo'),
  townhouse('townhouse'),
  villa('villa'),
  office('office'),
  other('other');

  final String wireValue;
  const HouseholdType(this.wireValue);

  static HouseholdType fromJson(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    for (final t in HouseholdType.values) {
      if (t.wireValue == raw) return t;
    }
    return HouseholdType.other;
  }
}

class Household {
  final String householdId;
  final String name;
  final String? address;
  final HouseholdType? type;

  Household({
    required this.householdId,
    required this.name,
    this.address,
    this.type,
  });

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        householdId: json['household_id'] ?? json['householdId'] ?? json['id'] ?? '',
        name: json['name'] ?? '',
        address: json['address'],
        type: json['type'] == null ? null : HouseholdType.fromJson(json['type']),
      );

  Map<String, dynamic> toJson() => {
        'household_id': householdId,
        'name': name,
        if (address != null) 'address': address,
        if (type != null) 'type': type!.wireValue,
      };
}

class HouseholdListResponse {
  final List<Household> items;

  HouseholdListResponse({required this.items});

  factory HouseholdListResponse.fromJson(List<dynamic> json) => HouseholdListResponse(
        items: json.map((e) => Household.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class HouseholdMember {
  final String userId;
  final String email;
  final String name;
  final String role;

  HouseholdMember({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        userId: json['user_id'] ?? json['userId'] ?? json['id'] ?? '',
        email: (json['user'] != null 
            ? (json['user'] as Map<String, dynamic>)['email'] 
            : json['email']) ?? '',
        name: (json['user'] != null 
            ? (json['user'] as Map<String, dynamic>)['full_name'] 
            : json['full_name']) ?? json['fullName'] ?? json['name'] ?? '',
        role: json['role'] ?? json['household_role'] ?? json['householdRole'] ?? 'member',
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'full_name': name,
        'role': role,
      };
}

class InvitationCodeResponse {
  final String code;
  final String? expiresAt;

  InvitationCodeResponse({required this.code, this.expiresAt});

  factory InvitationCodeResponse.fromJson(Map<String, dynamic> json) => InvitationCodeResponse(
        code: json['code'] ?? json['invitation_code'] ?? json['invitationCode'] ?? '',
        expiresAt: json['expires_at'] ?? json['expiresAt'],
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'expires_at': expiresAt,
      };
}

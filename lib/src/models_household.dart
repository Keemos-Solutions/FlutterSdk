class Household {
  final String householdId;
  final String name;

  Household({required this.householdId, required this.name});

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        householdId: json['household_id'] ?? json['householdId'] ?? '',
        name: json['name'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'household_id': householdId,
        'name': name,
      };
}

class HouseholdListResponse {
  final List<Household> items;

  HouseholdListResponse({required this.items});

  factory HouseholdListResponse.fromJson(List<dynamic> json) => HouseholdListResponse(
        items: json.map((e) => Household.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

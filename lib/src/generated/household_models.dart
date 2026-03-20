class HouseholdModel {
  final String id;
  final String? name;

  HouseholdModel({required this.id, this.name});

  factory HouseholdModel.fromJson(Map<String, dynamic> json) => HouseholdModel(
        id: json['id'] ?? json['household_id'] ?? json['householdId'] ?? '',
        name: json['name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

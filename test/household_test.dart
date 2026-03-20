import 'package:test/test.dart';
import 'package:keemos_sdk/src/models_household.dart';

void main() {
  test('Household serialization', () {
    final json = {'household_id': 'hh_abc123', 'name': 'Nhà Anh Hùng'};
    final h = Household.fromJson(json);
    expect(h.householdId, 'hh_abc123');
    expect(h.name, 'Nhà Anh Hùng');
  });
}

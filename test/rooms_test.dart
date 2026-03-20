import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('Household / Rooms basic models', () {
    test('HouseholdModel.fromJson roundtrip', () {
      final json = {'id': 'hh-1', 'name': 'Home'};
      final hh = HouseholdModel.fromJson(json);
      expect(hh.id, 'hh-1');
      expect(hh.name, 'Home');

      final out = hh.toJson();
      expect(out['id'], 'hh-1');
      expect(out['name'], 'Home');
    });
  });
}

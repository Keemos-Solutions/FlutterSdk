import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('Device models', () {
    test('Device.fromJson and toJson roundtrip', () {
      final json = {
        'id': 'dev-1',
        'name': 'Test Device',
        'household_id': 'hh-1',
      };

      final device = Device.fromJson(json);
      expect(device.id, 'dev-1');
      expect(device.name, 'Test Device');
      expect(device.householdId, 'hh-1');

      final out = device.toJson();
      expect(out['id'], 'dev-1');
      expect(out['household_id'], 'hh-1');
    });

    test('DeviceState.fromJson parses attributes and timestamp', () {
      final now = DateTime.now().toUtc();
      final json = {
        'attributes': {'power': true, 'level': 42},
        'updated_at': now.toIso8601String(),
      };

      final state = DeviceState.fromJson(json);
      expect(state.attributes['power'], isTrue);
      expect(state.attributes['level'], 42);
      expect(state.updatedAt, isNotNull);
      expect(state.updatedAt!.toUtc().difference(now).inSeconds.abs(), lessThan(2));
    });
  });
}

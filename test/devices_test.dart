import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('Device models', () {
    test('Device.fromJson and toJson roundtrip with full backend fields', () {
      final lastSeenAt = DateTime.utc(2026, 5, 1, 10, 0, 0);
      final createdAt = DateTime.utc(2026, 5, 1, 9, 0, 0);
      final updatedAt = DateTime.utc(2026, 5, 1, 11, 0, 0);

      final json = {
        'id': 'dev-1',
        'household_id': 'hh-1',
        'room_id': 'room-1',
        'user_id': 'user-1',
        'profile_id': 'profile-1',
        'name': 'Test Device',
        'serial_number': 'SN-001',
        'firmware_version': '1.2.3',
        'connection_type': 'wifi',
        'status': 'online',
        'state': {'power': true, 'level': 42},
        'config': {'unit': 'celsius'},
        'last_seen_at': lastSeenAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'profile': {'id': 'profile-1', 'name': 'Default profile'},
        'room': {'id': 'room-1', 'name': 'Living room'},
      };

      final device = Device.fromJson(json);
      expect(device.id, 'dev-1');
      expect(device.householdId, 'hh-1');
      expect(device.roomId, 'room-1');
      expect(device.userId, 'user-1');
      expect(device.profileId, 'profile-1');
      expect(device.name, 'Test Device');
      expect(device.serialNumber, 'SN-001');
      expect(device.firmwareVersion, '1.2.3');
      expect(device.connectionType, 'wifi');
      expect(device.status, 'online');
      expect(device.state['power'], isTrue);
      expect(device.state['level'], 42);
      expect(device.config['unit'], 'celsius');
      expect(device.lastSeenAt, lastSeenAt);
      expect(device.createdAt, createdAt);
      expect(device.updatedAt, updatedAt);
      expect(device.profile?['name'], 'Default profile');
      expect(device.room?['name'], 'Living room');

      final out = device.toJson();
      expect(out['id'], 'dev-1');
      expect(out['household_id'], 'hh-1');
      expect(out['room_id'], 'room-1');
      expect(out['user_id'], 'user-1');
      expect(out['profile_id'], 'profile-1');
      expect(out['serial_number'], 'SN-001');
      expect(out['firmware_version'], '1.2.3');
      expect(out['connection_type'], 'wifi');
      expect(out['status'], 'online');
      expect(out['state'], {'power': true, 'level': 42});
      expect(out['config'], {'unit': 'celsius'});
      expect(out['last_seen_at'], lastSeenAt.toIso8601String());
      expect(out['created_at'], createdAt.toIso8601String());
      expect(out['updated_at'], updatedAt.toIso8601String());
      expect(out['profile'], {'id': 'profile-1', 'name': 'Default profile'});
      expect(out['room'], {'id': 'room-1', 'name': 'Living room'});
    });

    test('Device.fromJson keeps legacy id fallbacks', () {
      final device = Device.fromJson({
        'deviceId': 'dev-legacy',
        'name': 'Legacy Device',
      });

      expect(device.id, 'dev-legacy');
      expect(device.name, 'Legacy Device');
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

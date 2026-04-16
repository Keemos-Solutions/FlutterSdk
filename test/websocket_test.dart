import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('buildKeemosWebSocketUri', () {
    test('https → wss, default path /api/v1/ws, token + household_id', () {
      final u = buildKeemosWebSocketUri(
        httpBaseUrl: 'https://api.keemos.vn',
        token: 'jwt-abc',
        householdId: 'hh_abc123',
      );
      expect(u.scheme, 'wss');
      expect(u.host, 'api.keemos.vn');
      expect(u.path, '/api/v1/ws');
      expect(u.queryParameters['token'], 'jwt-abc');
      expect(u.queryParameters['household_id'], 'hh_abc123');
    });

    test('http → ws', () {
      final u = buildKeemosWebSocketUri(
        httpBaseUrl: 'http://127.0.0.1:8080',
        token: 't',
      );
      expect(u.scheme, 'ws');
      expect(u.host, '127.0.0.1');
      expect(u.port, 8080);
      expect(u.path, '/api/v1/ws');
    });

    test('prefix path from REST base', () {
      final u = buildKeemosWebSocketUri(
        httpBaseUrl: 'https://example.com/api/v1',
        token: 'x',
        householdId: 'h1',
      );
      expect(u.path, '/api/v1/api/v1/ws');
    });

    test('omits household_id when null or empty', () {
      final a = buildKeemosWebSocketUri(
        httpBaseUrl: 'https://a.test',
        token: 't',
        householdId: null,
      );
      expect(a.queryParameters.containsKey('household_id'), isFalse);

      final b = buildKeemosWebSocketUri(
        httpBaseUrl: 'https://a.test',
        token: 't',
        householdId: '',
      );
      expect(b.queryParameters.containsKey('household_id'), isFalse);
    });
  });

  group('KeemosWsInboundEvent.fromJson', () {
    test('device.state_updated (doc example)', () {
      final ev = KeemosWsInboundEvent.fromJson({
        'household_id': 'hh_abc123',
        'event': 'device.state_updated',
        'device_id': 'dev-1',
        'data': {'power': true},
      });
      expect(ev.householdId, 'hh_abc123');
      expect(ev.event, 'device.state_updated');
      expect(ev.deviceId, 'dev-1');
      expect(ev.data['power'], isTrue);
    });

    test('camelCase keys', () {
      final ev = KeemosWsInboundEvent.fromJson({
        'event': 'device.online',
        'deviceId': 'd2',
        'householdId': 'hh',
        'data': {'online': true},
      });
      expect(ev.deviceId, 'd2');
      expect(ev.householdId, 'hh');
      expect(ev.data['online'], isTrue);
    });
  });

  group('parseKeemosWsTextFrame', () {
    test('newline-delimited batch in one frame', () {
      const frame = '''
{"event":"device.state_updated","device_id":"a","data":{"x":1}}
{"event":"device.state_updated","device_id":"b","data":{"x":2}}
''';
      final list = parseKeemosWsTextFrame(frame);
      expect(list.length, 2);
      expect(list[0].deviceId, 'a');
      expect(list[0].data['x'], 1);
      expect(list[1].deviceId, 'b');
    });

    test('skips pong', () {
      final list = parseKeemosWsTextFrame(
        '{"event":"pong"}\n{"event":"device.state_updated","device_id":"z","data":{}}',
      );
      expect(list.length, 1);
      expect(list[0].deviceId, 'z');
    });

    test('skips invalid JSON line, keeps valid', () {
      final list = parseKeemosWsTextFrame(
        'not json\n{"event":"device.state_updated","device_id":"ok","data":{}}\n',
      );
      expect(list.length, 1);
      expect(list[0].deviceId, 'ok');
    });
  });
}

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic nextResponseData;
  int nextStatusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future? cancelFuture,
  ) async {
    lastOptions = options;
    final encoded = utf8.encode(jsonEncode(nextResponseData ?? {'data': {}}));
    return ResponseBody.fromBytes(encoded, nextStatusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      Headers.contentLengthHeader: ['${encoded.length}'],
    });
  }
}

void main() {
  group('Tuya and Integration Models', () {
    test('TuyaLinkResult.fromJson and toJson roundtrip', () {
      final res = TuyaLinkResult.fromJson({
        'auth_url': 'https://auth.tuya.com/oauth/authorize?client_id=123',
      });
      expect(res.authUrl, 'https://auth.tuya.com/oauth/authorize?client_id=123');
      expect(res.toJson()['auth_url'], res.authUrl);
    });

    test('HouseholdIntegration.fromJson and toJson roundtrip', () {
      final integration = HouseholdIntegration.fromJson({
        'id': 'int_1',
        'household_id': 'hh_1',
        'integration_type': 'tuya',
        'status': 'active',
        'external_account_id': 'tuya_user_123',
        'metadata': {'region': 'sg'},
        'last_synced_at': '2026-08-17T10:00:00.000Z',
      });

      expect(integration.id, 'int_1');
      expect(integration.householdId, 'hh_1');
      expect(integration.integrationType, 'tuya');
      expect(integration.status, 'active');
      expect(integration.externalAccountId, 'tuya_user_123');
      expect(integration.metadata['region'], 'sg');
      expect(integration.lastSyncedAt, isNotNull);

      final json = integration.toJson();
      expect(json['id'], 'int_1');
      expect(json['integration_type'], 'tuya');
      expect(json['external_account_id'], 'tuya_user_123');
    });
  });

  group('TuyaApi client endpoints', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late KeemosClient client;

    setUp(() {
      dio = Dio();
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      final authManager = AuthManager(dio: Dio());
      client = KeemosClient(dio: dio, authManager: authManager);
    });

    test('initiateLink calls POST /api/v1/integrations/tuya/link', () async {
      adapter.nextResponseData = {
        'success': true,
        'data': {
          'auth_url': 'https://auth.tuya.com/oauth/authorize?client_id=abc',
        },
      };

      final result = await client.tuya.initiateLink('hh_123');
      expect(adapter.lastOptions?.path, '/api/v1/integrations/tuya/link');
      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.data, {'household_id': 'hh_123'});
      expect(result.authUrl, contains('auth.tuya.com'));
    });

    test('syncDevices calls POST /api/v1/integrations/tuya/sync', () async {
      adapter.nextResponseData = {
        'success': true,
        'data': [
          {
            'id': 'dev_tuya_1',
            'name': 'Tuya Smart Light',
            'connection_type': 'tuya_cloud',
            'state': {'power': true, 'brightness': 80},
          }
        ],
      };

      final devices = await client.tuya.syncDevices('hh_123');
      expect(adapter.lastOptions?.path, '/api/v1/integrations/tuya/sync');
      expect(devices.length, 1);
      expect(devices.first.name, 'Tuya Smart Light');
      expect(devices.first.connectionType, 'tuya_cloud');
    });

    test('listIntegrations calls GET /api/v1/integrations', () async {
      adapter.nextResponseData = {
        'data': [
          {
            'id': 'int_1',
            'household_id': 'hh_123',
            'integration_type': 'tuya',
            'status': 'active',
          }
        ]
      };

      final list = await client.tuya.listIntegrations('hh_123');
      expect(adapter.lastOptions?.path, '/api/v1/integrations');
      expect(adapter.lastOptions?.queryParameters['household_id'], 'hh_123');
      expect(list.length, 1);
      expect(list.first.integrationType, 'tuya');
    });

    test('unlinkIntegration calls DELETE /api/v1/integrations/:id', () async {
      adapter.nextResponseData = {'message': 'Integration unlinked'};

      await client.tuya.unlinkIntegration('int_1');
      expect(adapter.lastOptions?.path, '/api/v1/integrations/int_1');
      expect(adapter.lastOptions?.method, 'DELETE');
    });
  });

  group('Device command helpers', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late KeemosClient client;

    setUp(() {
      dio = Dio();
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      final authManager = AuthManager(dio: Dio());
      client = KeemosClient(dio: dio, authManager: authManager);
    });

    test('setPower dispatches SET_POWER command', () async {
      await client.devices.setPower('dev_1', true);
      expect(adapter.lastOptions?.path, '/api/v1/commands/oneway/dev_1');
      expect(adapter.lastOptions?.data, {
        'command_type': 'SET_POWER',
        'params': {'power': true},
      });

      await client.devices.setPower('dev_1', false, gangIndex: 2);
      expect(adapter.lastOptions?.data, {
        'command_type': 'SET_POWER',
        'params': {'switch_2': false},
      });
    });

    test('setBrightness clamps and dispatches SET_BRIGHTNESS', () async {
      await client.devices.setBrightness('dev_1', 75);
      expect(adapter.lastOptions?.data, {
        'command_type': 'SET_BRIGHTNESS',
        'params': {'brightness': 75},
      });
    });

    test('setColorTemperature clamps and dispatches SET_COLOR_TEMP', () async {
      await client.devices.setColorTemperature('dev_1', 4000);
      expect(adapter.lastOptions?.data, {
        'command_type': 'SET_COLOR_TEMP',
        'params': {'color_temp': 4000},
      });
    });

    test('setThermostatTemperature dispatches SET_TEMPERATURE', () async {
      await client.devices.setThermostatTemperature('dev_1', 24.5);
      expect(adapter.lastOptions?.data, {
        'command_type': 'SET_TEMPERATURE',
        'params': {'target_temperature': 24.5},
      });
    });
  });
}

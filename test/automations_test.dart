import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:keemos_sdk/keemos_sdk.dart';
import 'package:test/test.dart';

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
  group('AutomationsApi client endpoints', () {
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

    test('listAutomations calls GET /api/v1/households/:id/automations', () async {
      adapter.nextResponseData = {
        'data': [
          {'id': 'auto_1', 'name': 'Morning Scene'},
        ],
      };

      final res = await client.automations.listAutomations('hh_123');
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations');
      expect(adapter.lastOptions?.method, 'GET');
      expect(res.length, 1);
      expect(res.first['name'], 'Morning Scene');
    });

    test('getAutomation calls GET /api/v1/households/:id/automations/:id', () async {
      adapter.nextResponseData = {
        'data': {'id': 'auto_1', 'name': 'Morning Scene'},
      };

      final res = await client.automations.getAutomation('hh_123', 'auto_1');
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1');
      expect(adapter.lastOptions?.method, 'GET');
      expect(res['id'], 'auto_1');
    });

    test('createAutomation calls POST /api/v1/households/:id/automations', () async {
      adapter.nextResponseData = {
        'data': {'id': 'auto_new', 'name': 'New Auto'},
      };

      final res = await client.automations.createAutomation('hh_123', {
        'name': 'New Auto',
        'trigger_type': 'manual',
      });
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations');
      expect(adapter.lastOptions?.method, 'POST');
      expect(res['id'], 'auto_new');
    });

    test('updateAutomation calls PUT /api/v1/households/:id/automations/:id', () async {
      adapter.nextResponseData = {
        'data': {'id': 'auto_1', 'name': 'Updated Auto'},
      };

      final res = await client.automations.updateAutomation('hh_123', 'auto_1', {
        'name': 'Updated Auto',
      });
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1');
      expect(adapter.lastOptions?.method, 'PUT');
      expect(res['name'], 'Updated Auto');
    });

    test('toggleAutomation calls PATCH /api/v1/households/:id/automations/:id/toggle', () async {
      adapter.nextStatusCode = 200;
      adapter.nextResponseData = {'status': 'success'};

      final ok = await client.automations.toggleAutomation(
        'hh_123',
        'auto_1',
        enabled: true,
      );
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1/toggle');
      expect(adapter.lastOptions?.method, 'PATCH');
      expect(adapter.lastOptions?.data, {'enabled': true});
      expect(ok, isTrue);
    });

    test('deleteAutomation calls DELETE /api/v1/households/:id/automations/:id', () async {
      adapter.nextResponseData = {'status': 'success'};

      await client.automations.deleteAutomation('hh_123', 'auto_1');
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1');
      expect(adapter.lastOptions?.method, 'DELETE');
    });

    test('triggerAutomation calls POST /api/v1/households/:id/automations/:id/trigger and returns true on 2xx', () async {
      adapter.nextStatusCode = 200;
      adapter.nextResponseData = {'status': 'success'};

      final ok = await client.automations.triggerAutomation('hh_123', 'auto_1');
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1/trigger');
      expect(adapter.lastOptions?.method, 'POST');
      expect(ok, isTrue);
    });

    test('triggerAutomation returns false on non-2xx status code', () async {
      adapter.nextStatusCode = 400;
      adapter.nextResponseData = {'error': 'Failed to trigger'};

      final ok = await client.automations.triggerAutomation('hh_123', 'auto_1');
      expect(adapter.lastOptions?.path, '/api/v1/households/hh_123/automations/auto_1/trigger');
      expect(adapter.lastOptions?.method, 'POST');
      expect(ok, isFalse);
    });
  });
}

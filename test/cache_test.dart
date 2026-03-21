import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:keemos_sdk/keemos_sdk.dart';
import 'package:test/test.dart';

class _FakeAdapter implements HttpClientAdapter {
  int getCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future? cancelFuture) async {
    if (options.method == 'GET') {
      getCalls++;
      final body = {'data': {'value': getCalls}};
      final encoded = utf8.encode(jsonEncode(body));
      return ResponseBody.fromBytes(encoded, 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['${encoded.length}'],
      });
    }
    return ResponseBody.fromString('{}', 200);
  }
}

void main() {
  group('CacheManager with KeemosClient', () {
    late Dio dio;
    late KeemosClient client;
    late _FakeAdapter adapter;

    setUp(() {
      dio = Dio();
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      final authManager = AuthManager(dio: Dio());
      client = KeemosClient(
        dio: dio,
        authManager: authManager,
        cacheManager: CacheManager(store: MemoryCacheStore()),
      );
    });

    test('returns cached response on subsequent GET within TTL', () async {
      final first = await client.get('/api/v1/households');
      expect(first.data['data']['value'], 1);
      expect(adapter.getCalls, 1);

      final second = await client.get('/api/v1/households');
      expect(second.data['data']['value'], 1);
      expect(adapter.getCalls, 1, reason: 'should be served from cache');
      expect(second.extra['cached'], isTrue);
    });

    test('stale-while-revalidate serves stale then refreshes', () async {
      final first = await client.get(
        '/api/v1/devices/test/state',
        cacheOptions: const CacheOptions(ttl: Duration(milliseconds: 10)),
      );
      expect(first.data['data']['value'], 1);

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 15));
      final second = await client.get(
        '/api/v1/devices/test/state',
        cacheOptions: const CacheOptions(ttl: Duration(milliseconds: 10)),
      );
      expect(second.data['data']['value'], 1, reason: 'stale copy returned');
      expect(second.extra['stale'], isTrue);

      await Future.delayed(const Duration(milliseconds: 30));
      final third = await client.get(
        '/api/v1/devices/test/state',
        cacheOptions: const CacheOptions(ttl: Duration(seconds: 1)),
      );
      expect(third.data['data']['value'], greaterThanOrEqualTo(2));
    });

    test('invalidate prefix clears cached entries', () async {
      await client.get('/api/v1/notifications');
      expect(adapter.getCalls, 1);

      await client.invalidateCacheByPrefix('/api/v1/notifications');
      await client.get('/api/v1/notifications');
      expect(adapter.getCalls, 2, reason: 'cache should be cleared for prefix');
    });
  });
}

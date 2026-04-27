import 'dart:async';

import 'package:dio/dio.dart';
import 'auth.dart';
import 'apis/households_api.dart';
import 'apis/devices_api.dart';
import 'apis/rooms_api.dart';
import 'apis/automations_api.dart';
import 'apis/notifications_api.dart';
import 'cache.dart';

class CachePolicyEntry {
  final String prefix;
  final CacheOptions options;

  const CachePolicyEntry(this.prefix, this.options);
}

class KeemosClient {
  final Dio dio;
  final AuthManager authManager;
  final CacheManager? cacheManager;
  final List<CachePolicyEntry> cachePolicies;
  final CacheOptions defaultCacheOptions;

  KeemosClient({
    Dio? dio,
    required this.authManager,
    CacheManager? cacheManager,
    List<CachePolicyEntry>? cachePolicies,
    CacheOptions? defaultCacheOptions,
  })  : dio = dio ?? Dio(),
        cacheManager = cacheManager ?? CacheManager(),
        cachePolicies = cachePolicies ?? _defaultCachePolicies,
        defaultCacheOptions = defaultCacheOptions ?? const CacheOptions(ttl: Duration(seconds: 45)) {
    this.dio.options.baseUrl = 'https://api.keemos.vn';
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await authManager.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    }, onError: (error, handler) async {
      // Handle 401 Unauthorized - try to refresh token
      if (error.response?.statusCode == 401 && error.requestOptions.path != '/api/v1/auth/refresh') {
        final refreshed = await authManager.tryRefresh();
        if (refreshed) {
          final token = await authManager.getAccessToken();
          if (token != null && token.isNotEmpty) {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final cloneReq = await this.dio.fetch(opts);
              return handler.resolve(cloneReq);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
      }
      return handler.next(error);
    }));
    // initialize API wrappers for ergonomic usage: client.household.getHousehold(...)
    household = HouseholdsApi(this);
    devices = DevicesApi(this);
    rooms = RoomsApi(this);
    automations = AutomationsApi(this);
    notifications = NotificationsApi(this);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, CacheOptions? cacheOptions}) async {
    final manager = cacheManager;
    final effectiveOptions = _resolveCacheOptions(path, cacheOptions);
    final key = _buildCacheKey('GET', path, queryParameters);

    if (manager != null && effectiveOptions.enabled && !effectiveOptions.forceRefresh) {
      final entry = await manager.read(key);
      if (entry != null) {
        if (!entry.isExpired) {
          return _responseFromCache(entry, path, queryParameters);
        }
        if (effectiveOptions.staleWhileRevalidate) {
          unawaited(_refreshAndStore(key, path, queryParameters, effectiveOptions));
          return _responseFromCache(entry, path, queryParameters, stale: true);
        }
      }
    }

    final resp = await dio.get(path, queryParameters: queryParameters);
    if (manager != null && effectiveOptions.enabled) {
      final entry = CacheEntry(data: resp.data, createdAt: DateTime.now(), ttl: effectiveOptions.ttl);
      await manager.write(key, entry);
    }
    return resp;
  }

  Future<void> invalidateCacheByPrefix(String pathPrefix) async {
    final manager = cacheManager;
    if (manager == null) return;
    await manager.invalidateByPrefix('GET:$pathPrefix');
  }

  CacheOptions _resolveCacheOptions(String path, CacheOptions? incoming) {
    CacheOptions base = defaultCacheOptions;
    for (final rule in cachePolicies) {
      if (path.startsWith(rule.prefix)) {
        base = rule.options;
        break;
      }
    }
    if (incoming == null) return base;
    return base.copyWith(
      enabled: incoming.enabled,
      ttl: incoming.ttl,
      staleWhileRevalidate: incoming.staleWhileRevalidate,
      forceRefresh: incoming.forceRefresh,
    );
  }

  String _buildCacheKey(String method, String path, Map<String, dynamic>? queryParameters) {
    final buffer = StringBuffer('$method:$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final sortedKeys = queryParameters.keys.toList()..sort();
      final qp = <String, dynamic>{};
      for (final k in sortedKeys) {
        qp[k] = queryParameters[k];
      }
      final query = Uri(queryParameters: qp.map((k, v) => MapEntry(k, '$v'))).query;
      buffer.write('?$query');
    }
    return buffer.toString();
  }

  Future<void> _refreshAndStore(
    String key,
    String path,
    Map<String, dynamic>? queryParameters,
    CacheOptions options,
  ) async {
    try {
      final resp = await dio.get(path, queryParameters: queryParameters);
      final entry = CacheEntry(data: resp.data, createdAt: DateTime.now(), ttl: options.ttl);
      await cacheManager?.write(key, entry);
    } catch (_) {
      // ignore refresh errors; stale data already returned
    }
  }

  Response _responseFromCache(CacheEntry entry, String path, Map<String, dynamic>? queryParameters, {bool stale = false}) {
    return Response(
      data: entry.data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters ?? {}),
      extra: {'cached': true, 'stale': stale},
    );
  }

  // ergonomic API wrappers
  late final HouseholdsApi household;
  late final DevicesApi devices;
  late final RoomsApi rooms;
  late final AutomationsApi automations;
  late final NotificationsApi notifications;
}

const List<CachePolicyEntry> _defaultCachePolicies = [
  CachePolicyEntry(
    '/api/v1/households',
    CacheOptions(ttl: Duration(minutes: 5), staleWhileRevalidate: true),
  ),
  CachePolicyEntry(
    '/api/v1/households/',
    CacheOptions(ttl: Duration(minutes: 2), staleWhileRevalidate: true),
  ),
  CachePolicyEntry(
    '/api/v1/devices',
    CacheOptions(ttl: Duration(seconds: 45), staleWhileRevalidate: true),
  ),
  CachePolicyEntry(
    '/api/v1/automations',
    CacheOptions(ttl: Duration(minutes: 2), staleWhileRevalidate: true),
  ),
  CachePolicyEntry(
    '/api/v1/notifications',
    CacheOptions(ttl: Duration(seconds: 45), staleWhileRevalidate: true),
  ),
  CachePolicyEntry(
    '/api/v1/auth/profile',
    CacheOptions(ttl: Duration(minutes: 2), staleWhileRevalidate: true),
  ),
];

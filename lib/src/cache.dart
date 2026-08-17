import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Options applied per request to control caching behavior.
class CacheOptions {
  final bool enabled;
  final Duration ttl;
  final bool staleWhileRevalidate;
  final bool forceRefresh;

  const CacheOptions({
    this.enabled = true,
    this.ttl = const Duration(minutes: 1),
    this.staleWhileRevalidate = true,
    this.forceRefresh = false,
  });

  CacheOptions copyWith({
    bool? enabled,
    Duration? ttl,
    bool? staleWhileRevalidate,
    bool? forceRefresh,
  }) {
    return CacheOptions(
      enabled: enabled ?? this.enabled,
      ttl: ttl ?? this.ttl,
      staleWhileRevalidate: staleWhileRevalidate ?? this.staleWhileRevalidate,
      forceRefresh: forceRefresh ?? this.forceRefresh,
    );
  }
}

/// A cached entry with TTL metadata.
class CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({required this.data, required this.createdAt, required this.ttl});

  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'ttlMs': ttl.inMilliseconds,
    };
  }

  static CacheEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final createdAtStr = json['createdAt'] as String?;
    final ttlMs = json['ttlMs'] as int?;
    if (createdAtStr == null || ttlMs == null) return null;
    return CacheEntry(
      data: json['data'],
      createdAt: DateTime.parse(createdAtStr),
      ttl: Duration(milliseconds: ttlMs),
    );
  }
}

/// Minimal interface for cache stores (memory, file, or custom backends).
abstract class CacheStore {
  Future<CacheEntry?> read(String key);
  Future<void> write(String key, CacheEntry entry);
  Future<void> delete(String key);
  Future<void> clear();
  Future<Iterable<String>> keys();
}

/// In-memory cache store with a simple max entry cap (oldest evicted first).
class MemoryCacheStore implements CacheStore {
  final int maxEntries;
  final _entries = <String, CacheEntry>{};

  MemoryCacheStore({this.maxEntries = 200});

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<CacheEntry?> read(String key) async {
    return _entries[key];
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      // Evict oldest inserted entry.
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey);
    }
    _entries[key] = entry;
  }

  @override
  Future<Iterable<String>> keys() async => _entries.keys;
}

/// Tiered cache store: memory front plus persistent backing store.
class TieredCacheStore implements CacheStore {
  final CacheStore memoryStore;
  final CacheStore persistentStore;

  TieredCacheStore({CacheStore? memoryStore, required this.persistentStore})
      : memoryStore = memoryStore ?? MemoryCacheStore();

  @override
  Future<void> clear() async {
    await Future.wait([memoryStore.clear(), persistentStore.clear()]);
  }

  @override
  Future<void> delete(String key) async {
    await Future.wait([memoryStore.delete(key), persistentStore.delete(key)]);
  }

  @override
  Future<CacheEntry?> read(String key) async {
    final mem = await memoryStore.read(key);
    if (mem != null) return mem;
    final disk = await persistentStore.read(key);
    if (disk == null) return null;
    // hydrate memory for faster subsequent reads
    unawaited(memoryStore.write(key, disk));
    return disk;
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    await Future.wait([memoryStore.write(key, entry), persistentStore.write(key, entry)]);
  }

  @override
  Future<Iterable<String>> keys() async {
    final memKeys = await memoryStore.keys();
    final diskKeys = await persistentStore.keys();
    return {...memKeys, ...diskKeys};
  }
}

/// File-based cache store for persistence. Stores entries as a single JSON file.
class FileCacheStore implements CacheStore {
  final File file;
  final int maxEntries;
  Map<String, CacheEntry>? _cache;
  bool _initialized = false;

  FileCacheStore(String path, {this.maxEntries = 200}) : file = File(path);

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;
    if (await file.exists()) {
      try {
        final text = await file.readAsString();
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        _cache = <String, CacheEntry>{};
        decoded.forEach((k, v) {
          final entry = CacheEntry.fromJson(v as Map<String, dynamic>?);
          if (entry != null) {
            _cache![k] = entry;
          }
        });
      } catch (_) {
        _cache = <String, CacheEntry>{};
      }
    } else {
      await file.create(recursive: true);
      _cache = <String, CacheEntry>{};
    }
  }

  Future<void> _flush() async {
    if (_cache == null) return;
    final payload = _cache!.map((k, v) => MapEntry(k, v.toJson()));
    await file.writeAsString(jsonEncode(payload));
  }

  @override
  Future<void> clear() async {
    await _ensureLoaded();
    _cache!.clear();
    await _flush();
  }

  @override
  Future<void> delete(String key) async {
    await _ensureLoaded();
    _cache!.remove(key);
    await _flush();
  }

  @override
  Future<CacheEntry?> read(String key) async {
    await _ensureLoaded();
    return _cache![key];
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    await _ensureLoaded();
    if (_cache!.length >= maxEntries && !_cache!.containsKey(key)) {
      final oldestKey = _cache!.keys.first;
      _cache!.remove(oldestKey);
    }
    _cache![key] = entry;
    await _flush();
  }

  @override
  Future<Iterable<String>> keys() async {
    await _ensureLoaded();
    return _cache!.keys;
  }
}

/// Coordinates reads/writes and invalidations over a cache store.
class CacheManager {
  final CacheStore store;

  CacheManager({CacheStore? store}) : store = store ?? MemoryCacheStore();

  factory CacheManager.tiered({CacheStore? memoryStore, required CacheStore persistentStore}) {
    return CacheManager(store: TieredCacheStore(memoryStore: memoryStore, persistentStore: persistentStore));
  }

  Future<CacheEntry?> read(String key, {bool allowExpired = false}) async {
    final entry = await store.read(key);
    if (entry == null) return null;
    if (entry.isExpired && !allowExpired) {
      await store.delete(key);
      return null;
    }
    return entry;
  }

  Future<void> write(String key, CacheEntry entry) => store.write(key, entry);

  Future<void> invalidate(String key) => store.delete(key);

  Future<void> invalidateByPrefix(String prefix) async {
    final ks = List.of(await store.keys());
    for (final k in ks) {
      if (k.startsWith(prefix)) {
        await store.delete(k);
      }
    }
  }

  Future<void> clear() => store.clear();
}

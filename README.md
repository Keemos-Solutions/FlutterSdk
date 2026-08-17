# Keemos SDK (user-only)

This repository contains a Pure Dart SDK for Keemos IoT user APIs (auth, households, devices, rooms, automations, notifications, **Matter**).

What is included:
- `lib/` core SDK entrypoint and API wrappers
- Matter cloud API: `client.matter` (`MatterApi`) + models in `models_matter.dart` — matches `MOBILE_MATTER_INTEGRATION.md` / core-api
- `openapi-user-only.yaml` filtered spec used as a source of truth
- `test/` unit tests (including `matter_test.dart`)
- GitHub Actions CI (format/analyze/test)

### Matter (`client.matter`)

| Method | Path |
|--------|------|
| `registerDevice` | `POST /households/{id}/matter/devices` |
| `patchDeviceMatter` | `PATCH /devices/{id}/matter` |
| `putFabricPackage` / `getFabricPackage` / `getFabricPackageMeta` | fabric-package |
| `upsertControllerMe` / `listControllers` | controllers |
| `putHFSKWrap` / `getHFSKWrapMe` | HFSK wraps |

`Device.matter` is optional nested inventory (`MatterDeviceSummary`). Secrets never go on inventory APIs.

Next: generate full models from OpenAPI or implement more API wrappers.

How to generate models (best practice)

1. Install OpenAPI Generator CLI:

```bash
npm install @openapitools/openapi-generator-cli -g
```

2. Run the helper script:

```bash
./tools/generate_from_openapi.sh
```

This will create a `generated/` directory with Dart/Dio client code. Best practice: generate models and low-level client, then hand-polish wrappers in `lib/src/apis/` to provide a stable, ergonomic surface.

Example usage (simple script):

```bash
dart example/usage.dart
```

Caching
-------

- Built-in GET caching with TTL and stale-while-revalidate.
- Default: in-memory cache with sensible per-endpoint TTLs; override via `cacheOptions` on `client.get`.
- For persistence, supply a tiered cache manager:

```dart
final cacheFile = File('${Directory.systemTemp.path}/keemos_cache.json');
final client = KeemosClient(
	authManager: AuthManager(),
	cacheManager: CacheManager.tiered(
		persistentStore: FileCacheStore(cacheFile.path),
	),
);
```

- Invalidate after writes when needed: `await client.invalidateCacheByPrefix('/api/v1/devices');`
- Force refresh a single call: `client.get(path, cacheOptions: const CacheOptions(forceRefresh: true));`

Generated modules and tests
---------------------------

- Generated model classes are under `lib/src/generated/` (auth, device, household).
- Lightweight API wrappers for Devices, Rooms, Automations and Notifications live in `lib/src/apis/`.

Run tests
--------

Install dependencies and run the unit tests:

```bash
dart pub get
dart test
```


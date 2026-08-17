import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:keemos_sdk/keemos_sdk.dart';

void main() {
  group('Matter models', () {
    test('MatterDeviceSummary roundtrip', () {
      final json = {
        'fabric_id': '1',
        'node_id': '1234567890',
        'endpoints': [
          {
            'endpoint_id': 1,
            'device_types': [269],
            'clusters': [6, 8],
          }
        ],
        'network_type': 'wifi',
        'vendor_id': 4660,
        'product_id': 1,
        'primary_device_type': 269,
        'unique_id': 'uid-1',
      };

      final summary = MatterDeviceSummary.fromJson(json);
      expect(summary.fabricId, '1');
      expect(summary.nodeId, '1234567890');
      expect(summary.networkType, 'wifi');
      expect(summary.vendorId, 4660);
      expect(summary.primaryDeviceType, 269);
      expect(summary.uniqueId, 'uid-1');
      expect(summary.endpoints, isNotEmpty);

      final out = summary.toJson();
      expect(out['fabric_id'], '1');
      expect(out['node_id'], '1234567890');
      expect(out['primary_device_type'], 269);
    });

    test('Device.fromJson parses nested matter summary', () {
      final device = Device.fromJson({
        'id': 'dev-1',
        'name': 'Bulb',
        'connection_type': 'matter',
        'state': {'on': true},
        'config': {},
        'matter': {
          'fabric_id': '1',
          'node_id': '99',
          'endpoints': [],
          'network_type': 'thread',
          'vendor_id': 1,
          'product_id': 2,
        },
      });

      expect(device.connectionType, 'matter');
      expect(device.matter, isNotNull);
      expect(device.matter!.fabricId, '1');
      expect(device.matter!.nodeId, '99');
      expect(device.matter!.networkType, 'thread');
      expect(device.toJson()['matter']['fabric_id'], '1');
    });

    test('Device.fromJson omits matter when absent', () {
      final device = Device.fromJson({
        'id': 'dev-2',
        'name': 'Switch',
        'connection_type': 'wifi',
      });
      expect(device.matter, isNull);
      expect(device.toJson().containsKey('matter'), isFalse);
    });

    test('RegisterMatterDeviceRequest forbids secret fields via assert', () {
      expect(
        () => assertNoMatterSecrets({'setup_code': '123'}),
        throwsArgumentError,
      );
      expect(
        () => assertNoMatterSecrets({'name': 'ok', 'fabric_id': '1'}),
        returnsNormally,
      );
      expect(
        () => assertNoMatterSecrets({
          'name': 'ok',
          'state': {'on': true, 'setup_code': 'hidden'},
        }),
        throwsArgumentError,
      );
      expect(
        () => assertNoMatterSecrets({
          'endpoints': [
            {
              'endpoint_id': 1,
              'private_key': 'nope',
            },
          ],
        }),
        throwsArgumentError,
      );
    });

    test('RegisterMatterDeviceRequest toJson shape', () {
      final req = RegisterMatterDeviceRequest(
        name: 'Living Room Bulb',
        fabricId: '1',
        nodeId: '1234567890',
        roomId: 'room-1',
        vendorId: 4660,
        productId: 1,
        networkType: 'wifi',
        endpoints: [
          {
            'endpoint_id': 1,
            'device_types': [269],
            'clusters': [6, 8],
          }
        ],
        primaryDeviceType: 269,
        state: {'on': true},
      );

      final json = req.toJson();
      expect(json['name'], 'Living Room Bulb');
      expect(json['fabric_id'], '1');
      expect(json['node_id'], '1234567890');
      expect(json['room_id'], 'room-1');
      expect(json['vendor_id'], 4660);
      expect(json['network_type'], 'wifi');
      expect(json['primary_device_type'], 269);
      expect(json['state']['on'], isTrue);
      expect(json['endpoints'], isA<List>());
    });

    test('PutFabricPackageRequest toJson uses standard field names', () {
      final req = PutFabricPackageRequest(
        version: 1,
        alg: matterFabricAlgAes256Gcm,
        keyId: matterFabricKeyIdHfskV1,
        nonceB64: 'bm9uY2U=',
        ciphertextB64: 'Y2lwaGVy',
        aad: 'hh-1',
      );
      final json = req.toJson();
      expect(json['version'], 1);
      expect(json['alg'], 'AES-256-GCM');
      expect(json['key_id'], 'hfsk-v1');
      expect(json['nonce_b64'], 'bm9uY2U=');
      expect(json['ciphertext_b64'], 'Y2lwaGVy');
      expect(json['aad'], 'hh-1');
    });

    test('MatterFabricPackage and meta fromJson', () {
      final pkg = MatterFabricPackage.fromJson({
        'version': 2,
        'alg': 'AES-256-GCM',
        'key_id': 'hfsk-v1',
        'nonce_b64': 'n',
        'ciphertext_b64': 'c',
        'aad': 'hh',
        'created_by_user_id': 'u1',
        'created_at': '2026-07-18T10:00:00Z',
      });
      expect(pkg.version, 2);
      expect(pkg.ciphertextB64, 'c');
      expect(pkg.createdByUserId, 'u1');

      final meta = MatterFabricPackageMeta.fromJson({
        'version': 2,
        'alg': 'AES-256-GCM',
        'key_id': 'hfsk-v1',
        'aad': 'hh',
        'created_by_user_id': 'u1',
        'created_at': '2026-07-18T10:00:00Z',
      });
      expect(meta.version, 2);
      expect(meta.alg, 'AES-256-GCM');
    });

    test('UpsertMatterControllerRequest validates kind and hub id', () {
      expect(
        () => const UpsertMatterControllerRequest(kind: 'phone').toJson(),
        returnsNormally,
      );
      expect(
        () => const UpsertMatterControllerRequest(kind: 'tablet').toJson(),
        throwsArgumentError,
      );
      expect(
        () => const UpsertMatterControllerRequest(kind: 'hub').toJson(),
        throwsArgumentError,
      );
      final hub = const UpsertMatterControllerRequest(
        kind: 'hub',
        hubDeviceId: 'hub-1',
        fabricPackageVersion: 3,
        label: 'Kitchen Hub',
      ).toJson();
      expect(hub['kind'], 'hub');
      expect(hub['hub_device_id'], 'hub-1');
      expect(hub['fabric_package_version'], 3);
    });

    test('RegisterMatterDeviceResult and binding parse', () {
      final result = RegisterMatterDeviceResult.fromJson({
        'device': {
          'id': 'dev-1',
          'name': 'Bulb',
          'connection_type': 'matter',
          'state': {'on': true},
        },
        'binding': {
          'id': 'b1',
          'device_id': 'dev-1',
          'household_id': 'hh-1',
          'fabric_id': '1',
          'node_id': '9',
          'vendor_id': 1,
          'product_id': 2,
          'network_type': 'wifi',
          'endpoints': [],
          'commissioned_at': '2026-07-18T10:00:00Z',
          'created_at': '2026-07-18T10:00:00Z',
          'updated_at': '2026-07-18T10:00:00Z',
        },
      });
      expect(result.device['id'], 'dev-1');
      expect(result.binding.deviceId, 'dev-1');
      expect(result.binding.fabricId, '1');
      expect(result.binding.nodeId, '9');
    });

    test('MatterHFSKWrap and PutHFSKWrapRequest', () {
      final wrap = MatterHFSKWrap.fromJson({
        'user_id': 'u1',
        'wrap_alg': 'crypto_box_seal',
        'wrap_ciphertext_b64': 'abc',
        'updated_at': '2026-07-18T10:00:00Z',
      });
      expect(wrap.userId, 'u1');
      expect(wrap.wrapAlg, 'crypto_box_seal');

      final put = const PutHFSKWrapRequest(
        wrapCiphertextB64: 'abc',
        wrapAlg: 'crypto_box_seal',
      ).toJson();
      expect(put['wrap_ciphertext_b64'], 'abc');
      expect(put['wrap_alg'], 'crypto_box_seal');
    });

    test('constants match integration guide limits', () {
      expect(maxMatterFabricCiphertextBytes, 262144);
      expect(maxMatterHFSKWrapBytes, 8192);
      expect(
        matterForbiddenSecretFields,
        containsAll([
          'setup_code',
          'discriminator',
          'noc',
          'private_key',
          'ipk',
          'fabric_key',
          'pairing_code',
        ]),
      );
    });

    test('PatchMatterDeviceRequest requires at least one field', () {
      expect(
        () => const PatchMatterDeviceRequest().toJson(),
        throwsArgumentError,
      );
      final json = const PatchMatterDeviceRequest(
        networkType: 'thread',
        vendorId: 10,
      ).toJson();
      expect(json['network_type'], 'thread');
      expect(json['vendor_id'], 10);
    });
  });

  group('MatterApi client tests', () {
    late Dio dio;
    late KeemosClient client;

    setUp(() {
      dio = Dio();
      final authManager = AuthManager(dio: Dio());
      client = KeemosClient(dio: dio, authManager: authManager);
    });

    test('putFabricPackage throws ArgumentError on oversized ciphertext', () async {
      final oversizedCiphertext = 'A' * ((maxMatterFabricCiphertextBytes * 4 / 3).ceil() + 10);
      final req = PutFabricPackageRequest(
        version: 1,
        alg: 'AES-256-GCM',
        keyId: 'hfsk-v1',
        nonceB64: 'nonce',
        ciphertextB64: oversizedCiphertext,
      );

      expect(
        () => client.matter.putFabricPackage('hh_123', req),
        throwsArgumentError,
      );
    });

    test('putHFSKWrap throws ArgumentError on oversized wrap ciphertext', () async {
      final oversizedCiphertext = 'B' * ((maxMatterHFSKWrapBytes * 4 / 3).ceil() + 10);
      final req = PutHFSKWrapRequest(
        wrapCiphertextB64: oversizedCiphertext,
        wrapAlg: 'crypto_box_seal',
      );

      expect(
        () => client.matter.putHFSKWrap('hh_123', 'usr_456', req),
        throwsArgumentError,
      );
    });
  });
}

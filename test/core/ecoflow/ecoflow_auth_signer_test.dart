import 'package:flutter_test/flutter_test.dart';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_auth_signer.dart';

void main() {
  group('EcoFlowSignedHeadersFactory', () {
    test('builds stable sorted sign string and sha256 signature', () {
      final factory = EcoFlowSignedHeadersFactory();

      final signed = factory.create(
        accessKey: 'ak_test',
        secretKey: 'sk_test',
        nonce: '123456',
        timestampMillis: 1710000000000,
        params: {
          'z': 1,
          'a': {
            'd': 4,
            'b': 2,
          },
        },
      );

      expect(
        signed.signBaseString,
        'accessKey=ak_test&nonce=123456&params={"a":{"b":2,"d":4},"z":1}&timestamp=1710000000000',
      );
      expect(signed.signature.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(signed.signature), isTrue);
      expect(signed.headers['sign'], signed.signature);
      expect(signed.headers['accessKey'], 'ak_test');
      expect(signed.headers['nonce'], '123456');
      expect(signed.headers['timestamp'], '1710000000000');
    });

    test('changes sign when nonce or timestamp changes', () {
      final factory = EcoFlowSignedHeadersFactory();

      final first = factory.create(
        accessKey: 'ak_test',
        secretKey: 'sk_test',
        nonce: '111111',
        timestampMillis: 1710000000000,
      );

      final second = factory.create(
        accessKey: 'ak_test',
        secretKey: 'sk_test',
        nonce: '222222',
        timestampMillis: 1710000001000,
      );

      expect(first.signature, isNot(second.signature));
      expect(first.headers['nonce'], isNot(second.headers['nonce']));
      expect(first.headers['timestamp'], isNot(second.headers['timestamp']));
    });
  });
}

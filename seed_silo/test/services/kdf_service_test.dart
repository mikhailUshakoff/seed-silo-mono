import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seed_silo/services/kdf_service.dart';

KdfParams _params({
  int algorithm = KdfService.argon2idAlgorithm,
  int memoryKib = 64 * 1024,
  int iterations = 3,
  int parallelism = 1,
  int saltSize = KdfService.saltSize,
}) =>
    KdfParams(
      algorithm: algorithm,
      memoryKib: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
      salt: Uint8List.fromList(List.generate(saltSize, (i) => i)),
    );

void main() {
  group('KdfService.deriveKeyUnchecked', () {
    test('matches the utils/key-encryption known vector', () async {
      // Same vector as test_derive_key_known_vector in
      // utils/key-encryption/src/main.rs.
      final key = await KdfService().deriveKeyUnchecked(
        Uint8List.fromList(utf8.encode('password')),
        _params(memoryKib: 1024, iterations: 2, parallelism: 1),
      );
      expect(hex.encode(key),
          '82b64c8aa46eb41006d80da81b932b36d7b0e7b86bde93fd475a2f3b15478e02');
    });

    test('zeroes the password', () async {
      final password = Uint8List.fromList(utf8.encode('password'));
      await KdfService().deriveKeyUnchecked(
          password, _params(memoryKib: 1024, iterations: 1));
      expect(password, everyElement(0));
    });
  });

  group('KdfService.validate', () {
    test('accepts the default provisioning params', () {
      expect(() => KdfService().validate(_params()), returnsNormally);
    });

    for (final entry in {
      'unknown algorithm': _params(algorithm: 0x02),
      'short salt': _params(saltSize: 16),
      'memory too low': _params(memoryKib: KdfService.minMemoryKib - 1),
      'memory too high': _params(memoryKib: KdfService.maxMemoryKib + 1),
      'zero iterations': _params(iterations: 0),
      'too many iterations': _params(iterations: KdfService.maxIterations + 1),
      'zero parallelism': _params(parallelism: 0),
      'too much parallelism':
          _params(parallelism: KdfService.maxParallelism + 1),
    }.entries) {
      test('rejects ${entry.key}', () {
        expect(() => KdfService().validate(entry.value),
            throwsA(isA<KdfException>()));
      });
    }

    test('deriveKey zeroes the password when params are rejected', () async {
      final password = Uint8List.fromList(utf8.encode('password'));
      await expectLater(KdfService().deriveKey(password, _params(saltSize: 0)),
          throwsA(isA<KdfException>()));
      expect(password, everyElement(0));
    });
  });
}

import 'dart:isolate';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';
import 'package:seed_silo/utils/nullify.dart';

/// Password KDF parameters stored on the device (KDF_* in the firmware's
/// input.h), as returned by CMD_GET_KDF_PARAMS.
class KdfParams {
  final int algorithm;
  final int memoryKib;
  final int iterations;
  final int parallelism;
  final Uint8List salt;

  KdfParams({
    required this.algorithm,
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });
}

/// Thrown when the device reports KDF parameters the app refuses to use.
class KdfException implements Exception {
  final String message;

  KdfException(this.message);

  @override
  String toString() => message;
}

/// Derives the 32-byte AES key the device expects from the user's password.
/// Must produce the same key as utils/key-encryption (Argon2id v1.3).
class KdfService {
  static final KdfService _instance = KdfService._internal();
  factory KdfService() => _instance;
  KdfService._internal();

  /// KDF_ARGON2ID in firmware/include/core/constants.h.
  static const int argon2idAlgorithm = 0x01;

  static const int saltSize = 32;
  static const int keySize = 32;

  // Accepted ranges; must match utils/key-encryption. The upper bounds stop a
  // faulty device from making the app allocate unbounded memory; the lower
  // bounds stop it from silently weakening the KDF.
  static const int minMemoryKib = 19 * 1024;
  static const int maxMemoryKib = 1024 * 1024;
  static const int minIterations = 1;
  static const int maxIterations = 16;
  static const int minParallelism = 1;
  static const int maxParallelism = 16;

  /// Throws [KdfException] if [params] are unsupported or out of range.
  void validate(KdfParams params) {
    if (params.algorithm != argon2idAlgorithm) {
      throw KdfException('Unsupported KDF algorithm 0x'
          '${params.algorithm.toRadixString(16).padLeft(2, '0')}; '
          'update the app');
    }
    if (params.salt.length != saltSize) {
      throw KdfException('Invalid KDF salt length ${params.salt.length}');
    }
    if (params.memoryKib < minMemoryKib || params.memoryKib > maxMemoryKib) {
      throw KdfException('KDF memory cost ${params.memoryKib} KiB is out of '
          'range [$minMemoryKib, $maxMemoryKib]');
    }
    if (params.iterations < minIterations ||
        params.iterations > maxIterations) {
      throw KdfException('KDF iterations ${params.iterations} is out of '
          'range [$minIterations, $maxIterations]');
    }
    if (params.parallelism < minParallelism ||
        params.parallelism > maxParallelism) {
      throw KdfException('KDF parallelism ${params.parallelism} is out of '
          'range [$minParallelism, $maxParallelism]');
    }
  }

  /// Argon2id([password], salt) -> [keySize] bytes. [password] is zeroed.
  /// Runs in a separate isolate so the UI stays responsive; the isolate's
  /// copy of the password is zeroed too. Argon2's working memory is
  /// allocated inside hashlib and can not be wiped; it is released when the
  /// isolate exits. Throws [KdfException] if [params] fail [validate].
  Future<Uint8List> deriveKey(Uint8List password, KdfParams params) async {
    try {
      validate(params);
      return await deriveKeyUnchecked(password, params);
    } finally {
      nullifyUint8List(password);
    }
  }

  /// [deriveKey] without the range checks, for tests with cheap parameters.
  /// [password] is zeroed.
  Future<Uint8List> deriveKeyUnchecked(
      Uint8List password, KdfParams params) async {
    final passwordCopy = Uint8List.fromList(password);
    nullifyUint8List(password);
    final salt = Uint8List.fromList(params.salt);
    final memoryKib = params.memoryKib;
    final iterations = params.iterations;
    final parallelism = params.parallelism;
    try {
      return await Isolate.run(() {
        try {
          return Argon2(
            type: Argon2Type.argon2id,
            version: Argon2Version.v13,
            memorySizeKB: memoryKib,
            iterations: iterations,
            parallelism: parallelism,
            hashLength: keySize,
            salt: salt,
          ).convert(passwordCopy).bytes;
        } finally {
          nullifyUint8List(passwordCopy);
        }
      });
    } finally {
      nullifyUint8List(passwordCopy);
    }
  }
}

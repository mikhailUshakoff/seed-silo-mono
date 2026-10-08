import 'dart:typed_data';

import 'package:seed_silo/services/serial_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:web3dart/web3dart.dart';

class Version {
  final int major;
  final int minor;
  final int patch;

  Version(this.major, this.minor, this.patch);
}

/// Error returned by the device (or the transport) while executing a command.
/// [code] is the firmware error code from `firmware/include/core/constants.h`,
/// or null when the device could not be reached / sent a malformed response.
class HardwareWalletException implements Exception {
  final int? code;
  final String message;

  HardwareWalletException(this.message, {this.code});

  factory HardwareWalletException.fromCode(int code) =>
      HardwareWalletException(_messages[code] ?? 'Unknown device error',
          code: code);

  static const Map<int, String> _messages = {
    0x02: 'Unknown command',
    0x03: 'Wrong data format',
    0x04: 'Wrong recovery ID',
    0x05: 'Invalid parameters',
    0x06: 'Invalid password position',
    0x07: 'Failed to set up encryption key',
    0x08: 'Decryption failed (wrong password or position?)',
    0x09: 'Failed to create public key',
    0x0a: 'Failed to serialize public key',
    0x0b: 'Failed to create signature',
    0x0c: 'Failed to serialize signature',
    0x0d: 'Transaction was rejected on the device',
    0x0e: 'Not a type-2 (EIP-1559) transaction',
    0x0f: 'Failed to parse RLP list',
    0x10: 'Invalid RLP list length',
    0x11: 'Failed to parse RLP field',
    0x12: 'Transaction data is not an EIP-20 transfer',
  };

  @override
  String toString() => code == null
      ? message
      : '$message (code 0x${code!.toRadixString(16).padLeft(2, '0')})';
}

/// Thrown by [HardwareWalletService.getSignature] when the pending request was
/// cancelled via [HardwareWalletService.cancelSignature]. [deviceResponded] is
/// false when the device did not answer the interrupting request in time, so
/// its state is unknown.
class HardwareWalletCancelledException extends HardwareWalletException {
  final bool deviceResponded;

  HardwareWalletCancelledException({this.deviceResponded = true})
      : super('Signing cancelled');
}

class HardwareWalletService {
  static final HardwareWalletService _instance =
      HardwareWalletService._internal();
  factory HardwareWalletService() => _instance;

  HardwareWalletService._internal();

  // Command bytes; must match CMD_* in firmware/include/core/constants.h.

  /// CMD_GET_VERSION: replies [versionResponseSize] bytes.
  static const int getVersionCmd = 0x01;

  /// CMD_GET_PUBKEY: replies [publicKeyResponseSize] bytes.
  static const int getUncompressedPublicKeyCmd = 0x02;

  /// CMD_SIGN: replies [signatureSuccessResponseSize] bytes on success,
  /// [signatureFailedResponseSize] on error or rejection.
  static const int getSignatureCmd = 0x03;

  // Response layout. Every response starts with a status byte; on error the
  // status byte (an error code) is the whole response.

  /// Status byte at the start of every response.
  static const int statusCodeSize = 1;

  /// Version payload: major, minor, patch, one byte each.
  static const int versionSize = 3;

  /// Signature payload: r (32 bytes) || s (32 bytes) || v (1 byte).
  static const int signatureSize = 65;

  /// Size of each of the r and s signature components.
  static const int signatureComponentSize = 32;

  /// Offsets of r, s and v inside a successful signature response.
  static const int signatureRPos = statusCodeSize;
  static const int signatureSPos = signatureRPos + signatureComponentSize;
  static const int signatureVPos = signatureSPos + signatureComponentSize;

  /// Uncompressed SEC1 public key as written by
  /// secp256k1_ec_pubkey_serialize: 0x04 prefix || X (32) || Y (32).
  static const int publicKeySize = 65;

  /// The 0x04 prefix marking a SEC1 uncompressed public key.
  static const int publicKeyPrefixSize = 1;

  /// Offset of X || Y (the key without its 0x04 prefix) in a public key
  /// response; that 64-byte form is what Ethereum addresses are hashed from.
  static const int publicKeyPos = statusCodeSize + publicKeyPrefixSize;

  /// Full successful responses: status byte + payload.
  static const int versionResponseSize = statusCodeSize + versionSize;
  static const int publicKeyResponseSize = statusCodeSize + publicKeySize;
  static const int signatureSuccessResponseSize =
      statusCodeSize + signatureSize;

  /// Error or rejection response to a sign request: the status byte only.
  static const int signatureFailedResponseSize = statusCodeSize;

  // Responses to the version request sent by [_interruptSignature]. If the
  // user pressed a device button just before it arrived, the answer to the
  // sign request comes first, followed by the version response.

  /// Signature, then version response.
  static const int signatureSuccessAndVersionResponseSize =
      signatureSuccessResponseSize + versionResponseSize;

  /// Rejection, then version response.
  static const int signatureFailedAndVersionResponseSize =
      signatureFailedResponseSize + versionResponseSize;

  /// Offset of the version response's status byte in each of the replies
  /// above.
  static const int statusInVersionResponsePos = 0;
  static const int statusInSignatureSuccessAndVersionResponsePos =
      signatureSuccessResponseSize;
  static const int statusInSignatureFailedAndVersionResponsePos =
      signatureFailedResponseSize;

  // Status codes; must match CORE_* in firmware/include/core/constants.h.

  /// Largest raw transaction the device accepts for signing; must match
  /// MAX_MSG_LEN in firmware/include/core/command_handlers.h. The device
  /// only checks it after reading the length prefix, leaving the message
  /// bytes unread on the port, so oversized messages must never be sent.
  static const int maxMessageSize = 1024;

  /// CORE_SUCCESS.
  static const int successCode = 0x01;

  /// CORE_ERR_TX_REJECTED: the user rejected the transaction on the device.
  static const int txRejectedCode = 0x0d;

  /// Delay between polls of the serial port.
  static const Duration readTimeout = Duration(milliseconds: 500);

  /// How long to wait for the device to answer a version request.
  static const Duration versionTimeout = Duration(seconds: 5);

  /// How long to wait for the device to answer a public key request.
  static const Duration publicKeyTimeout = Duration(seconds: 5);

  bool _cancelSignatureRequested = false;

  /// Returns null if the device can not be reached or does not answer within
  /// [versionTimeout].
  Future<Version?> getVersion() async {
    final ok = await SerialService().write([getVersionCmd]);
    if (ok == null) return null;
    try {
      final stopwatch = Stopwatch()..start();
      Uint8List? buffer = Uint8List(0);
      while (buffer!.isEmpty) {
        if (stopwatch.elapsed >= versionTimeout) return null;
        await Future.delayed(readTimeout);
        // null: port is not open and can not be reopened.
        buffer = await SerialService().read(statusCodeSize);
        if (buffer == null) return null;
      }
      if (buffer.length == statusCodeSize && buffer[0] == successCode) {
        buffer = await SerialService().read(versionSize);
        if (buffer != null && buffer.length == versionSize) {
          return Version(buffer[0], buffer[1], buffer[2]);
        }
      }
      return null;
    } catch (_) {
      // Port vanished mid-read (e.g. device unplugged).
      return null;
    } finally {
      SerialService().close();
    }
  }

  Uint8List _intToUint16(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  Uint8List _intToUint8(int value) {
    final bytes = ByteData(1);
    bytes.setUint8(0, value);
    return bytes.buffer.asUint8List();
  }

  /// Requests a transaction signature from the device. Display-capable devices
  /// wait for user approval; devices without confirmation UI may respond
  /// immediately. Throws [HardwareWalletException] on transport/device errors,
  /// or [HardwareWalletCancelledException] after [cancelSignature].
  Future<MsgSignature> getSignature(
      Uint8List password, int pos, Uint8List rawTransaction) async {
    _cancelSignatureRequested = false;
    // The firmware checks the maximum message size and just returns
    // CORE_ERR_WRONG_DATA_FORMAT. For better UX, check it here before
    // sending anything to the device.
    if (rawTransaction.isEmpty || rawTransaction.length > maxMessageSize) {
      nullifyUint8List(password);
      throw HardwareWalletException(
          'Transaction is ${rawTransaction.length} bytes; the device accepts '
          '1 to $maxMessageSize bytes');
    }
    final request = [getSignatureCmd];
    request.addAll(password);
    nullifyUint8List(password);
    request.addAll(_intToUint8(pos));
    request.addAll(_intToUint16(rawTransaction.length));
    request.addAll(rawTransaction);

    final ok = await SerialService().write(request);
    nullifyListInt(request);
    if (ok == null) {
      throw HardwareWalletException('Can not connect to the device');
    }

    Uint8List? buffer = Uint8List(0);
    try {
      while (buffer!.isEmpty) {
        await Future.delayed(readTimeout);
        buffer = await SerialService().read(signatureSuccessResponseSize);
        // null: port is not open and can not be reopened.
        if (buffer == null) {
          throw HardwareWalletException('Lost connection to the device');
        }
        if (buffer.isEmpty && _cancelSignatureRequested) {
          _cancelSignatureRequested = false;
          throw HardwareWalletCancelledException(
              deviceResponded: await _interruptSignature());
        }
      }
    } on HardwareWalletException {
      rethrow;
    } catch (_) {
      // Port vanished mid-read (e.g. device unplugged).
      throw HardwareWalletException('Lost connection to the device');
    } finally {
      _cancelSignatureRequested = false;
      SerialService().close();
    }

    if (buffer[0] != successCode) {
      throw HardwareWalletException.fromCode(buffer[0]);
    }
    if (buffer.length != signatureSuccessResponseSize) {
      throw HardwareWalletException('Unexpected device response');
    }

    // signature
    final r = buffer.sublist(signatureRPos, signatureSPos);
    final s = buffer.sublist(signatureSPos, signatureVPos);
    final v = buffer[signatureVPos];

    final sig = MsgSignature(BigInt.parse(bytesToHex(r), radix: 16),
        BigInt.parse(bytesToHex(s), radix: 16), v);
    return sig;
  }

  /// Sends a version request to drop the signature pending on the device and
  /// drains the reply. Returns false if the device did not answer as
  /// expected, so its state is unknown.
  ///
  /// Any new command makes the device leave its confirmation screen. But the
  /// device checks its buttons before the serial port, so if the user pressed
  /// one just before the request arrived, that answer is sent first:
  ///   version reply only:           01 maj min patch
  ///   rejected, then version:       0d 01 maj min patch
  ///   signed, then version:         01 [r s v: 65 bytes] 01 maj min patch
  /// All three count as cancelled; a signature received here is discarded,
  /// so nothing gets broadcast.
  Future<bool> _interruptSignature() async {
    final ok = await SerialService().write([getVersionCmd]);
    if (ok == null) return false;

    final response = <int>[];
    try {
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed < versionTimeout) {
        await Future.delayed(readTimeout);
        final chunk =
            await SerialService().read(signatureSuccessAndVersionResponseSize);
        if (chunk == null) return false;
        // Stop once the device has said something and then gone quiet.
        if (chunk.isEmpty && response.isNotEmpty) break;
        response.addAll(chunk);
      }
    } catch (_) {
      // Port vanished mid-read (e.g. device unplugged).
      return false;
    } finally {
      SerialService().close();
    }

    final versionAt = switch (response.length) {
      versionResponseSize => statusInVersionResponsePos,
      signatureFailedAndVersionResponseSize
          when response[0] == txRejectedCode =>
        statusInSignatureFailedAndVersionResponsePos,
      signatureSuccessAndVersionResponseSize when response[0] == successCode =>
        statusInSignatureSuccessAndVersionResponsePos,
      _ => -1,
    };
    return versionAt >= 0 && response[versionAt] == successCode;
  }

  /// Interrupts a [getSignature] call that is waiting for user confirmation
  /// on the device. If the device already answered, the answer wins and
  /// [getSignature] completes normally.
  void cancelSignature() {
    _cancelSignatureRequested = true;
  }

  /// Throws [HardwareWalletException] on transport/device errors, or if the
  /// device does not answer within [publicKeyTimeout].
  Future<Uint8List> getUncompressedPublicKey(
      Uint8List password, int pos) async {
    final request = [getUncompressedPublicKeyCmd];
    request.addAll(password);
    nullifyUint8List(password);
    request.addAll(_intToUint8(pos));
    final ok = await SerialService().write(request);
    nullifyListInt(request);
    if (ok == null) {
      throw HardwareWalletException('Can not connect to the device');
    }

    Uint8List? buffer = Uint8List(0);
    try {
      final stopwatch = Stopwatch()..start();
      while (buffer!.isEmpty) {
        if (stopwatch.elapsed >= publicKeyTimeout) {
          throw HardwareWalletException('Device did not respond');
        }
        await Future.delayed(readTimeout);
        buffer = await SerialService().read(publicKeyResponseSize);
        // null: port is not open and can not be reopened.
        if (buffer == null) {
          throw HardwareWalletException('Lost connection to the device');
        }
      }
    } on HardwareWalletException {
      rethrow;
    } catch (_) {
      // Port vanished mid-read (e.g. device unplugged).
      throw HardwareWalletException('Lost connection to the device');
    } finally {
      SerialService().close();
    }

    if (buffer[0] != successCode) {
      throw HardwareWalletException.fromCode(buffer[0]);
    }
    if (buffer.length != publicKeyResponseSize) {
      throw HardwareWalletException('Unexpected device response');
    }

    return buffer.sublist(publicKeyPos);
  }

  void dispose() {
    SerialService().close();
  }
}

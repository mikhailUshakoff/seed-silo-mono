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
/// cancelled via [HardwareWalletService.cancelSignature].
class HardwareWalletCancelledException extends HardwareWalletException {
  HardwareWalletCancelledException() : super('Signing cancelled');
}

class HardwareWalletService {
  static final HardwareWalletService _instance =
      HardwareWalletService._internal();
  factory HardwareWalletService() => _instance;

  HardwareWalletService._internal();

  static const int getVersionCmd = 0x01;
  static const int getUncompressedPublicKeyCmd = 0x02;
  static const int getSignatureCmd = 0x03;

  static const int successCode = 0x01;

  static const Duration readTimeout = Duration(milliseconds: 500);

  bool _cancelSignatureRequested = false;

  Future<Version?> getVersion() async {
    final ok = await SerialService().write([getVersionCmd]);
    if (ok == null) return null;
    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(1);
    }
    if (buffer.length == 1 && buffer[0] == successCode) {
      buffer = await SerialService().read(3);
      SerialService().close();
      if (buffer != null && buffer.length == 3) {
        return Version(buffer[0], buffer[1], buffer[2]);
      }
    }
    return null;
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

    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(66);
      if ((buffer == null || buffer.isEmpty) && _cancelSignatureRequested) {
        _cancelSignatureRequested = false;
        // Any new command makes the device drop the pending signature, so a
        // version request interrupts its confirmation screen. getVersion()
        // also consumes the reply and closes the port.
        await getVersion();
        throw HardwareWalletCancelledException();
      }
    }

    _cancelSignatureRequested = false;
    SerialService().close();

    if (buffer[0] != successCode) {
      throw HardwareWalletException.fromCode(buffer[0]);
    }
    if (buffer.length != 66) {
      throw HardwareWalletException('Unexpected device response');
    }

    // signature
    final r = buffer.sublist(1, 33);
    final s = buffer.sublist(33, 65);
    final v = buffer[65];

    final sig = MsgSignature(BigInt.parse(bytesToHex(r), radix: 16),
        BigInt.parse(bytesToHex(s), radix: 16), v);
    return sig;
  }

  /// Interrupts a [getSignature] call that is waiting for user confirmation
  /// on the device. If the device already answered, the answer wins and
  /// [getSignature] completes normally.
  void cancelSignature() {
    _cancelSignatureRequested = true;
  }

  Future<Uint8List?> getUncompressedPublicKey(
      Uint8List password, int pos) async {
    final request = [getUncompressedPublicKeyCmd];
    request.addAll(password);
    nullifyUint8List(password);
    request.addAll(_intToUint8(pos));
    final ok = await SerialService().write(request);
    nullifyListInt(request);
    if (ok == null) return null;

    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(66);
    }

    SerialService().close();

    if (buffer.length == 66 && buffer[0] == successCode) {
      return buffer.sublist(2);
    }

    return null;
  }

  void dispose() {
    SerialService().close();
  }
}

import 'dart:typed_data';

import 'package:seed_silo/services/serial_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:web3dart/crypto.dart';

class Version {
  final int major;
  final int minor;
  final int patch;

  Version(this.major, this.minor, this.patch);
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

  Future<MsgSignature?> getSignature(
      Uint8List password, int pos, Uint8List rawTransaction) async {
    final request = [getSignatureCmd];
    request.addAll(password);
    nullifyUint8List(password);
    request.addAll(_intToUint8(pos));
    request.addAll(_intToUint16(rawTransaction.length));
    request.addAll(rawTransaction);

    final ok = await SerialService().write(request);
    nullifyListInt(request);
    if (ok == null) return null;

    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(66);
    }

    SerialService().close();

    if (buffer.length != 66 || buffer[0] != successCode) {
      return null;
    }

    // signature
    final r = buffer.sublist(1, 33);
    final s = buffer.sublist(33, 65);
    final v = buffer[65];

    final sig = MsgSignature(BigInt.parse(bytesToHex(r), radix: 16),
        BigInt.parse(bytesToHex(s), radix: 16), v);
    return sig;
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

    if (buffer.length == 66 || buffer[0] == successCode) {
      return buffer.sublist(2);
    }

    return null;
  }

  void dispose() {
    SerialService().close();
  }
}

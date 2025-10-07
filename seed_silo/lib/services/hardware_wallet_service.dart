import 'dart:typed_data';

import 'package:seed_silo/services/serial_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:web3dart/crypto.dart';

class HardwareWalletService {
  static final HardwareWalletService _instance =
      HardwareWalletService._internal();
  factory HardwareWalletService() => _instance;

  HardwareWalletService._internal();

  static const int getVersionCmd = 0x01;
  static const int getUncompressedPublicKeyCmd = 0x02;
  static const int getSignatureCmd = 0x03;

  static const Duration readTimeout = Duration(milliseconds: 500);

  Future<int?> getVersion() async {
    final ok = await SerialService().write([getVersionCmd]);
    if (ok == null) return null;

    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(1);
    }

    SerialService().close();

    if (buffer.length == 1 && buffer[0] == 0xF0) {
      return 1;
    }

    return null;
  }

  Uint8List _intTo2Bytes(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  Future<MsgSignature?> getSignature(
      Uint8List password, Uint8List rawTransaction) async {
    final request = [getSignatureCmd];
    request.addAll(password);
    nullifyUint8List(password);
    request.addAll(_intTo2Bytes(rawTransaction.length));
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

    if (buffer.length != 66 || buffer[0] != 0xF0) {
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

  Future<Uint8List?> getUncompressedPublicKey(Uint8List password) async {
    final request = [getUncompressedPublicKeyCmd];
    request.addAll(password);
    nullifyUint8List(password);
    final ok = await SerialService().write(request);
    nullifyListInt(request);
    if (ok == null) return null;

    Uint8List? buffer;
    while (buffer == null || buffer.isEmpty) {
      await Future.delayed(readTimeout);
      buffer = await SerialService().read(66);
    }

    SerialService().close();

    if (buffer.length == 66 || buffer[0] == 0xF0) {
      return buffer.sublist(2);
    }

    return null;
  }

  void dispose() {
    SerialService().close();
  }
}

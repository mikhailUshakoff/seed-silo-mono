import 'dart:typed_data';

import 'package:seed_silo/services/serial_service.dart';
import 'package:web3dart/crypto.dart';

class HardwareWalletService {
  static final HardwareWalletService _instance = HardwareWalletService._internal();
  factory HardwareWalletService() => _instance;

  HardwareWalletService._internal();

  static const int getVersionCmd = 0x01;
  static const int getUncompressedPublicKeyCmd = 0x02;
  static const int getSignatureCmd = 0x03;

  Future<int?> getVersion() async {
    await SerialService().write([getVersionCmd]);

    await Future.delayed(Duration(seconds: 1));

    final buffer = await SerialService().read(1);
    if (buffer[0] == 0xF0) {
      return 1;
    }

    return null;
  }


  Uint8List intTo2Bytes(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  Future<MsgSignature?> getSignature(String password, Uint8List rawTransaction) async {
    final keccakHash = keccak256(Uint8List.fromList(password.codeUnits));
    final request = [getSignatureCmd];
    request.addAll(keccakHash);
    request.addAll(intTo2Bytes(rawTransaction.length));
    request.addAll(rawTransaction);

    await SerialService().write(request);

    await Future.delayed(Duration(seconds: 2));

    final buffer = await SerialService().read(66);

    if (buffer[0] != 0xF0) {
      return null;
    }

    // signature
    final r = buffer.sublist(1, 33);
    final s = buffer.sublist(33, 65);
    final v = buffer[65];

    final sig = MsgSignature(
      BigInt.parse(bytesToHex(r),radix: 16),
      BigInt.parse(bytesToHex(s),radix: 16),
      v
    );
    return sig;
  }

  Future<Uint8List?> getUncompressedPublicKey(String password) async {
    final keccakHash = keccak256(Uint8List.fromList(password.codeUnits));
    final request = [getUncompressedPublicKeyCmd];
    request.addAll(keccakHash);
    await SerialService().write(request);

    await Future.delayed(Duration(seconds: 2));

    final buffer = await SerialService().read(66);
    // String hexResponse = buffer.map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}').join(', ');
    if (buffer[0] == 0xF0) {
      return buffer.sublist(2);
    }

    return null;
  }

  void dispose() {
    SerialService().close();
    print('Cleaning up HardwareWalletService');
  }
}

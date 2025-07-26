import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class SerialService {
  static final SerialService _instance = SerialService._internal();
  factory SerialService() => _instance;

  SerialService._internal();

  SerialPort? _port;

  bool get isConnected => _port?.isOpen ?? false;

  SerialPort? get port => _port;

  /// Explicit connect if you want to show a loader in UI
  Future<bool> connect() async {
    if (isConnected) return true;

    //TODO select port to connect
    final ports = SerialPort.availablePorts;
    if (ports.isEmpty) return false;

    _port = SerialPort(ports.first);
    if (!_port!.openReadWrite()) return false;

    final config = SerialPortConfig()
      ..baudRate = 115200
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none);

    _port!.config = config;

    return _port!.isOpen;
  }

  Future<int?> write(List<int> data) async {
    if (!isConnected) {
      final ok = await connect();
      if (!ok) return null;
    }

    try {
      return _port!.write(Uint8List.fromList(data));
    } catch (e) {
      _port?.close();
      return null;
    }
  }

  Future<Uint8List?> read(int length) async {
    if (!isConnected) {
      final ok = await connect();
      if (!ok) return null;
    }
    return _port!.read(length);
  }

  void close() {
    _port?.close();
    _port = null;
  }
}

import 'dart:typed_data';

void nullifyUint8List(Uint8List list) {
  list.fillRange(0, list.length, 0);
}

void nullifyListInt(List<int> list) {
  list.fillRange(0, list.length, 0);
  list.clear();
}

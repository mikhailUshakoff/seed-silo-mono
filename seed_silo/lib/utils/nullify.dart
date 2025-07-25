import 'dart:typed_data';

void nullify(Uint8List list) {
    for (int i = 0; i < list.length; i++) {
      list[i] = 0;
    }
}
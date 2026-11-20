import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/main.dart' show orientationsFor;

void main() {
  test('HP (< 600 dp): portrait & landscape diizinkan', () {
    final o = orientationsFor(375);
    expect(o, contains(DeviceOrientation.portraitUp));
    expect(o, contains(DeviceOrientation.landscapeLeft));
  });

  test('tablet (>= 600 dp): hanya landscape', () {
    expect(orientationsFor(800),
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    expect(orientationsFor(600), isNot(contains(DeviceOrientation.portraitUp)));
  });
}

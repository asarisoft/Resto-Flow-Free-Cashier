import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_motion.dart';

void main() {
  Future<Duration> read(WidgetTester t, {required bool disable}) async {
    late Duration d;
    await t.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(builder: (c) {
        d = AppMotion.of(c, AppMotion.slow);
        return const SizedBox();
      }),
    ));
    return d;
  }

  testWidgets('durasi normal bila animasi aktif', (t) async {
    expect(await read(t, disable: false), AppMotion.slow);
  });

  testWidgets('durasi 0 bila disableAnimations', (t) async {
    expect(await read(t, disable: true), Duration.zero);
  });
}

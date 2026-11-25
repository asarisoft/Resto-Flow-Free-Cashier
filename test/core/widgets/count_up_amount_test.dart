import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/widgets/amount_text.dart';
import 'package:kasir_resto/core/widgets/pop_on_change.dart';

void main() {
  Widget host(int amount, {bool disable = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PopOnChange(value: amount, child: CountUpAmount(amount: amount)),
        ),
      );

  testWidgets('count-up berakhir tepat di nilai int rupiah', (t) async {
    await t.pumpWidget(host(15000));
    expect(find.text(formatRupiah(15000)), findsOneWidget);
    await t.pumpWidget(host(45000));
    await t.pump(const Duration(milliseconds: 60));
    expect(find.text(formatRupiah(45000)), findsNothing); // masih jalan
    await t.pumpAndSettle();
    expect(find.text(formatRupiah(45000)), findsOneWidget);
  });

  testWidgets('disableAnimations: langsung ke nilai akhir', (t) async {
    await t.pumpWidget(host(15000, disable: true));
    await t.pumpWidget(host(45000, disable: true));
    await t.pump();
    expect(find.text(formatRupiah(45000)), findsOneWidget);
  });
}

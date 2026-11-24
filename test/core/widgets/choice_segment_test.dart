import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/widgets/choice_segment.dart';

void main() {
  testWidgets('shows options and reports the tapped one', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChoiceSegment<int>(
          value: 58,
          options: const [(58, '58 mm'), (80, '80 mm')],
          onChanged: (v) => picked = v,
        ),
      ),
    ));
    expect(find.text('58 mm'), findsOneWidget);
    await tester.tap(find.text('80 mm'));
    expect(picked, 80);
  });

  testWidgets('wadah inset, segmen terpilih oranye, tinggi >= 48, semantics selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChoiceSegment<int>(
          value: 58,
          options: const [(58, '58 mm'), (80, '80 mm')],
          onChanged: (_) {},
        ),
      ),
    ));
    final wrap = tester.widget<DecoratedBox>(find.byKey(const ValueKey('segment-container')));
    expect((wrap.decoration as BoxDecoration).color, AppColors.inset);
    final sel = tester.widget<DecoratedBox>(find.byKey(const ValueKey('segment-58')));
    expect((sel.decoration as BoxDecoration).gradient, isNull);
    expect((sel.decoration as BoxDecoration).color, AppColors.primary);
    expect(tester.getSize(find.byKey(const ValueKey('segment-80'))).height, greaterThanOrEqualTo(48));
    final h = tester.ensureSemantics();
    expect(tester.getSemantics(find.text('58 mm')), containsSemantics(label: '58 mm', isButton: true, isSelected: true, hasSelectedState: true));
    h.dispose();
  });
}

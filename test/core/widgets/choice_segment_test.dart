import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

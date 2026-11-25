import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';

/// Format rupiah (int) → "Rp 15.000". Satu format untuk seluruh app.
String formatRupiah(int amount) => AmountText._format.format(amount);

class AmountText extends StatelessWidget {
  final int amount;
  final TextStyle? style;
  final bool showZero;

  static final _format = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  const AmountText({
    super.key,
    required this.amount,
    this.style,
    this.showZero = true,
  });

  @override
  Widget build(BuildContext context) {
    if (amount == 0 && !showZero) return const SizedBox.shrink();
    return Text(
      _format.format(amount),
      style: (style ?? AppTypography.textTheme.bodyLarge)
          ?.apply(fontFeatures: [const FontFeature.tabularFigures()]),
    );
  }
}

class AmountTotal extends StatelessWidget {
  final int amount;

  const AmountTotal({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Text(
      AmountText._format.format(amount),
      style: AppTypography.textTheme.displayMedium
          ?.apply(fontFeatures: [const FontFeature.tabularFigures()]),
    );
  }
}

/// [AmountText] yang berubah halus (count-up). Nilai tetap `int` rupiah dan
/// selalu berakhir tepat di [amount]; tanpa animasi saat pertama tampil.
class CountUpAmount extends StatelessWidget {
  final int amount;
  final TextStyle? style;

  const CountUpAmount({super.key, required this.amount, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(end: amount),
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.curve,
      builder: (_, v, __) => AmountText(amount: v, style: style),
    );
  }
}

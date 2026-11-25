import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';

/// Tombol − qty +, target sentuh >= 48 dp.
/// [compact] = kapsul tunggal "− 2 +" (tampak 36 dp) untuk kartu/baris produk.
class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  /// Nama item untuk label aksesibilitas ("Kurangi Nama"); null = "Kurangi".
  final String? name;
  final bool compact;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.name,
    this.compact = false,
  });

  static final _style = IconButton.styleFrom(
    minimumSize: const Size(48, 48),
    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
    foregroundColor: AppColors.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  static final _flatStyle = IconButton.styleFrom(
    minimumSize: const Size(48, 48),
    foregroundColor: AppColors.primary,
  );

  @override
  Widget build(BuildContext context) {
    final style = compact ? _flatStyle : _style;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: name == null ? 'Kurangi' : 'Kurangi $name',
          style: style,
          icon: const Icon(AppIcons.remove),
          onPressed: () => onChanged(value - 1),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: compact ? 28 : 40),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: name == null ? 'Tambah' : 'Tambah $name',
          style: style,
          icon: const Icon(AppIcons.add),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
    if (!compact) return row;
    // Kapsul 36 dp di belakang tombol 48 dp (area sentuh tetap 48).
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          top: 6,
          bottom: 6,
          child: DecoratedBox(
            key: const ValueKey('qty-capsule'),
            decoration: ClayDecoration.box(radius: 18, compact: true),
          ),
        ),
        row,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

/// Tombol − qty +, target sentuh >= 48dp.
class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const QtyStepper({super.key, required this.value, required this.onChanged});

  static final _style = IconButton.styleFrom(
    minimumSize: const Size(48, 48),
    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
    foregroundColor: AppColors.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Kurangi',
          style: _style,
          icon: const Icon(AppIcons.remove),
          onPressed: () => onChanged(value - 1),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Tambah',
          style: _style,
          icon: const Icon(AppIcons.add),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

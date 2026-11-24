import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';

/// Pilihan 1-dari-N (mis. 58/80 mm, Hari Ini/Bulan Ini): wadah lekuk,
/// segmen terpilih = kotak oranye menonjol.
class ChoiceSegment<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const ChoiceSegment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      key: const ValueKey('segment-container'),
      decoration: ClayDecoration.inset(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              Semantics(
                  button: true,
                  selected: o.$1 == value,
                  excludeSemantics: true,
                  label: o.$2,
                  onTap: () => onChanged(o.$1),
                  child: DecoratedBox(
                    key: ValueKey('segment-${o.$1}'),
                    decoration: o.$1 == value
                        ? BoxDecoration(color: AppColors.primary, borderRadius: radius, boxShadow: const [
                            BoxShadow(color: AppColors.clayShadow, offset: Offset(4, 5), blurRadius: 10),
                          ])
                        : const BoxDecoration(),
                    child: Material(
                      type: MaterialType.transparency,
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onChanged(o.$1),
                        borderRadius: radius,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            widthFactor: 1,
                            child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              o.$2,
                              textAlign: TextAlign.center,
                              style: AppTypography.textTheme.labelLarge?.copyWith(
                                color: o.$1 == value ? AppColors.onPrimary : AppColors.textSecondary,
                              ),
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

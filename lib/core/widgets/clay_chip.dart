import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';

/// Chip clay kecil (filter periode, tab kategori). Area sentuh selalu >= 48 dp;
/// [height] = tinggi tampak. Terpilih = [selectedColor] + teks putih.
class ClayChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final Color selectedColor;

  const ClayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.height = 48,
    this.selectedColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              key: ValueKey('chip-$label'),
              decoration: ClayDecoration.box(
                color: selected ? selectedColor : AppColors.surface,
                radius: 14,
                compact: true,
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: radius,
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: AppIcons.sm, color: fg),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: AppTypography.textTheme.bodyMedium?.copyWith(
                              color: fg,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

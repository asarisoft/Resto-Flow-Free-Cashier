import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';
import '../utils/period.dart';

/// Pilihan periode: Hari ini / Bulan ini / Bulan lalu / Semua / rentang tanggal.
class PeriodFilterBar extends StatelessWidget {
  final PeriodSelection value;
  final ValueChanged<PeriodSelection> onChanged;

  const PeriodFilterBar({super.key, required this.value, required this.onChanged});

  static const _presets = [
    PeriodPreset.today,
    PeriodPreset.thisMonth,
    PeriodPreset.lastMonth,
    PeriodPreset.all,
  ];

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final current = value.range(now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
      // Bawaan Flutter layar penuh; dibatasi jadi modal di tengah.
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
        ),
      ),
    );
    if (picked != null) onChanged(PeriodSelection.custom(picked));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final isCustom = value.preset == PeriodPreset.custom;
    final r = value.range(DateTime.now());
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in _presets)
          _PeriodChip(
            label: PeriodSelection(p).label,
            selected: value.preset == p,
            onTap: () => onChanged(PeriodSelection(p)),
          ),
        _PeriodChip(
          icon: AppIcons.calendar,
          label: isCustom && r != null
              ? '${fmt.format(r.start)} – ${fmt.format(r.end)}'
              : 'Pilih tanggal',
          selected: isCustom,
          onTap: () => _pickRange(context),
        ),
      ],
    );
  }
}

/// Chip clay kecil, tinggi >= 48 dp. Terpilih = gelap, teks putih.
class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.selected, required this.onTap, this.icon});

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
      child: DecoratedBox(
        key: ValueKey('chip-$label'),
        decoration: ClayDecoration.box(
          color: selected ? AppColors.textPrimary : AppColors.surface,
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
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
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

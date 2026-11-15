import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_icons.dart';
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
          ChoiceChip(
            label: Text(PeriodSelection(p).label),
            selected: value.preset == p,
            onSelected: (_) => onChanged(PeriodSelection(p)),
          ),
        ChoiceChip(
          avatar: const Icon(AppIcons.calendar, size: AppIcons.sm),
          label: Text(isCustom && r != null
              ? '${fmt.format(r.start)} – ${fmt.format(r.end)}'
              : 'Pilih tanggal'),
          selected: isCustom,
          onSelected: (_) => _pickRange(context),
        ),
      ],
    );
  }
}

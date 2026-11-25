import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_icons.dart';
import 'clay_chip.dart';
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
          ClayChip(
            label: PeriodSelection(p).label,
            selected: value.preset == p,
            onTap: () => onChanged(PeriodSelection(p)),
          ),
        ClayChip(
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

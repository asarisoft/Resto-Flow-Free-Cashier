import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/period.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_panel.dart';
import '../../core/widgets/period_filter_bar.dart';
import '../../models/shift.dart';
import 'shift_detail.dart';
import 'shift_providers.dart';

/// Shift yang dibuka dalam [period], urutan terbaru dulu (urutan input dipertahankan).
List<Shift> filterShiftsByPeriod(List<Shift> all, PeriodSelection period, DateTime now) =>
    all.where((s) => period.contains(s.openedAt, now)).toList();

String shiftTimeLabel(Shift s) {
  final f = DateFormat('dd/MM HH:mm');
  return '${f.format(s.openedAt)} → ${s.closedAt == null ? 'Masih buka' : f.format(s.closedAt!)}';
}

class ShiftHistoryPage extends ConsumerStatefulWidget {
  const ShiftHistoryPage({super.key});

  @override
  ConsumerState<ShiftHistoryPage> createState() => _ShiftHistoryPageState();
}

class _ShiftHistoryPageState extends ConsumerState<ShiftHistoryPage> {
  PeriodSelection _period = PeriodSelection.thisMonth;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shiftHistoryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Shift'),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(List<Shift> all) {
    final rows = filterShiftsByPeriod(all, _period, DateTime.now());
    final t = AppTypography.textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilterPanel(
              summary: _period.label,
              onReset: _period == PeriodSelection.thisMonth
                  ? null
                  : () => setState(() => _period = PeriodSelection.thisMonth),
              top: PeriodFilterBar(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              fields: const [],
            ),
            const SizedBox(height: 16),
            AppDataTable<Shift>(
              pageSize: 25,
              rowLabel: (s) => 'Detail shift ${shiftTimeLabel(s)}',
              onRowTap: (s) => showShiftDetail(context, s),
              empty: EmptyState(
                icon: AppIcons.search,
                title: all.isEmpty ? 'Belum ada shift' : 'Tidak ada shift pada periode ini',
                subtitle: all.isEmpty ? null : 'Ubah atau reset filter',
              ),
              rows: rows,
              columns: [
                AppColumn<Shift>(
                  label: 'Jam',
                  primary: true,
                  flex: 2,
                  minWidth: 180,
                  cell: (s) => Text(shiftTimeLabel(s)),
                ),
                AppColumn<Shift>(
                  label: 'Dibuka oleh',
                  minWidth: 120,
                  cell: (s) => Text(s.openedBy),
                ),
                AppColumn<Shift>(
                  label: 'Modal awal',
                  minWidth: 120,
                  numeric: true,
                  cell: (s) => AmountText(amount: s.openingCash),
                ),
                AppColumn<Shift>(
                  label: 'Laci',
                  minWidth: 120,
                  numeric: true,
                  cell: (s) => s.isOpen ? const Text('—') : AmountText(amount: s.countedCash ?? 0),
                ),
                AppColumn<Shift>(
                  label: 'Seharusnya',
                  minWidth: 120,
                  numeric: true,
                  cell: (s) => s.isOpen ? const Text('—') : AmountText(amount: s.expectedCash ?? 0),
                ),
                AppColumn<Shift>(
                  label: 'Selisih',
                  primary: true,
                  minWidth: 120,
                  numeric: true,
                  cell: (s) {
                    if (s.isOpen) return const Text('—');
                    final diff = (s.countedCash ?? 0) - (s.expectedCash ?? 0);
                    return AmountText(
                      amount: diff,
                      style: t.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: diff >= 0 ? AppColors.success : AppColors.error,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

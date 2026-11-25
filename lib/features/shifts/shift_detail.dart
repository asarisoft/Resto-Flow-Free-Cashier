import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/adaptive_sheet.dart';
import '../../core/widgets/amount_text.dart';
import '../../models/shift.dart';
import '../reports/report_providers.dart';
import 'shift_calc.dart';

/// Rincian satu shift: rekap + jumlah transaksi pada rentang buka..tutup.
class ShiftDetailData {
  final ShiftRecap recap;
  final int txCount;
  const ShiftDetailData(this.recap, this.txCount);
}

/// Pakai query & [computeShiftRecap] yang sama dengan dialog Tutup Shift,
/// supaya angkanya persis. Shift terbuka → sampai [now].
Future<ShiftDetailData> loadShiftDetail(WidgetRef ref, Shift s, {DateTime? now}) async {
  final reports = ref.read(reportsDaoProvider);
  final end = s.closedAt ?? now ?? DateTime.now();
  final revenue = await reports.sumRevenueByMethod(s.openedAt, end);
  final expense = await reports.sumExpensesCreatedBetween(s.openedAt, end);
  final count = await reports.countTransactions(s.openedAt, end);
  final recap = computeShiftRecap(
    openingCash: s.openingCash,
    revenueByMethod: revenue,
    totalExpense: expense,
    countedCash: s.countedCash ?? 0,
  );
  return ShiftDetailData(recap, count);
}

/// Detail shift: bottom sheet di HP, dialog di tablet.
Future<void> showShiftDetail(BuildContext context, Shift shift) =>
    showAdaptiveSheet(
      context,
      builder: (_, asSheet) => asSheet
          ? ShiftDetailView(shift: shift)
          : Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ShiftDetailView(shift: shift),
              ),
            ),
    );

class ShiftDetailView extends ConsumerStatefulWidget {
  final Shift shift;
  const ShiftDetailView({super.key, required this.shift});

  @override
  ConsumerState<ShiftDetailView> createState() => _ShiftDetailViewState();
}

class _ShiftDetailViewState extends ConsumerState<ShiftDetailView> {
  late final Future<ShiftDetailData> _future = loadShiftDetail(ref, widget.shift);

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme;
    final s = widget.shift;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    Widget text(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: t.bodyLarge)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
    Widget money(String label, int v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: t.bodyLarge)),
              const SizedBox(width: 8),
              AmountText(
                amount: v,
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Detail Shift', style: t.titleLarge),
          const SizedBox(height: 12),
          text('Dibuka', fmt.format(s.openedAt)),
          text('Ditutup', s.closedAt == null ? 'Masih buka' : fmt.format(s.closedAt!)),
          text('Dibuka oleh', s.openedBy),
          money('Modal awal', s.openingCash),
          const Divider(height: 20),
          FutureBuilder<ShiftDetailData>(
            future: _future,
            builder: (_, snap) {
              if (snap.hasError) return Text('Error: ${snap.error}');
              final d = snap.data;
              if (d == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final r = d.recap;
              // Shift selesai: yang tersimpan = acuan resmi.
              final expected = s.expectedCash ?? r.expectedCash;
              final counted = s.countedCash;
              final diff = counted == null ? null : counted - expected;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  money('Omzet tunai', r.cashRevenue),
                  money('Omzet non-tunai', r.totalRevenue - r.cashRevenue),
                  text('Jumlah transaksi', '${d.txCount}'),
                  money('Pengeluaran', r.totalExpense),
                  const Divider(height: 20),
                  money('Kas seharusnya', expected),
                  if (counted != null) money('Uang di laci', counted),
                  if (diff != null)
                    money('Selisih', diff,
                        color: diff >= 0 ? AppColors.success : AppColors.error),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ),
        ],
      ),
    );
  }
}

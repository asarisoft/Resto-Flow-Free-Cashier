import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/filter_panel.dart';
import '../../core/widgets/period_filter_bar.dart';
import '../../core/widgets/search_field.dart';
import 'transaction_detail_dialog.dart';
import 'transaction_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/amount_text.dart';
import '../../models/transaction.dart' as models;
import '../../printer/printer_service.dart';
import '../../printer/receipt_builder.dart';
import '../../features/settings/settings_providers.dart';
import '../reports/report_providers.dart';
import '../reports/report_repository.dart';
import '../../core/theme/app_icons.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  TransactionFilter _filter = const TransactionFilter();

  /// Rentang untuk ringkasan (SQL). "Semua" = rentang sangat lebar.
  DateTimeRange get _range =>
      _filter.period.range(DateTime.now()) ?? DateTimeRange(start: DateTime(2000), end: DateTime(2100));

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final summaryAsync = ref.watch(reportSummaryProvider(_range));
    final txnsAsync = ref.watch(transactionsInRangeProvider(_filter.period.range(DateTime.now())));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilterPanel(
                onReset: _filter.isDefault ? null : () => setState(() => _filter = const TransactionFilter()),
                children: [
                  PeriodFilterBar(
                    value: _filter.period,
                    onChanged: (p) => setState(() => _filter = _filter.copyWith(period: p)),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey(_filter.method),
                          initialValue: _filter.method,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Metode bayar'),
                          items: const [
                            DropdownMenuItem<String?>(value: null, child: Text('Semua metode')),
                            DropdownMenuItem<String?>(value: 'cash', child: Text('Tunai')),
                            DropdownMenuItem<String?>(value: 'qris', child: Text('QRIS')),
                            DropdownMenuItem<String?>(value: 'card', child: Text('Kartu')),
                          ],
                          onChanged: (v) => setState(() => _filter =
                              v == null ? _filter.copyWith(clearMethod: true) : _filter.copyWith(method: v)),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: SearchField(
                          hint: 'Cari no. struk / nama item',
                          value: _filter.query,
                          onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (s) => _SummaryCards(summary: s),
              ),
              const SizedBox(height: 24),
              Text('Transaksi', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              txnsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (all) {
                  final txns = applyTransactionFilter(all, _filter);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${txns.length} transaksi · Total ${formatRupiah(totalOf(txns))}',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      AppDataTable<models.Transaction>(
                        pageSize: 25,
                        rows: txns,
                        rowLabel: (t) => 'Transaksi nomor ${t.number}',
                        onRowTap: (t) => showDialog(
                          context: context,
                          builder: (_) => TransactionDetailDialog(txn: t, onReprint: () => _reprint(t)),
                        ),
                        empty: all.isEmpty
                            ? const EmptyState(icon: AppIcons.receipt, title: 'Belum ada transaksi')
                            : const EmptyState(
                                icon: AppIcons.search,
                                title: 'Tidak ada transaksi yang cocok',
                                subtitle: 'Ubah atau reset filter',
                              ),
                        columns: [
                          AppColumn(label: 'No.', minWidth: 80, cell: (t) => Text('#${t.number}')),
                          AppColumn(
                            label: 'Tanggal',
                            flex: 2,
                            minWidth: 150,
                            cell: (t) => Text(DateFormat('dd/MM/yyyy HH:mm').format(t.createdAt)),
                          ),
                          AppColumn(label: 'Item', minWidth: 70, numeric: true, cell: (t) => Text('${t.items.length}')),
                          AppColumn(
                            label: 'Metode',
                            minWidth: 100,
                            cell: (t) => Text(paymentLabel(t.paymentMethod)),
                          ),
                          AppColumn(
                            label: 'Total',
                            flex: 2,
                            minWidth: 130,
                            numeric: true,
                            cell: (t) => AmountText(
                              amount: t.total,
                              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppColumn(
                            label: 'Laba',
                            flex: 2,
                            minWidth: 120,
                            numeric: true,
                            cell: (t) => AmountText(
                              amount: t.profit,
                              style: textTheme.bodyLarge?.copyWith(
                                color: t.profit >= 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          AppColumn(
                            label: '',
                            minWidth: 64,
                            numeric: true,
                            cell: (t) => IconButton(
                              tooltip: 'Cetak ulang',
                              icon: const Icon(AppIcons.print),
                              onPressed: () => _reprint(t),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reprint(models.Transaction txn) async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null) return;
    try {
      final bytes = ReceiptBuilder.fromTransaction(txn, profile);
      final printer = PrinterService();
      if (printer.isConnected) {
        await printer.printBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Struk dicetak ulang')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer tidak terhubung')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak: $e')),
        );
      }
    }
  }
}

class _SummaryCards extends StatelessWidget {
  final ReportSummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = constraints.maxWidth >= 500;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _card(
              'Omzet',
              summary.totalRevenue,
              AppIcons.trendingUp,
              AppColors.success,
              isWide, textTheme,
            ),
            _card(
              'Laba Kotor',
              summary.totalProfit,
              AppIcons.trendingUp,
              AppColors.success,
              isWide, textTheme,
            ),
            _card(
              'Pengeluaran',
              summary.totalExpense,
              AppIcons.expense,
              AppColors.warning,
              isWide, textTheme,
            ),
            _card(
              'Laba Bersih',
              summary.netProfit,
              AppIcons.wallet,
              summary.netProfit >= 0
                  ? AppColors.success
                  : AppColors.error,
              isWide, textTheme,
            ),
            _card(
              'Transaksi',
              summary.transactionCount,
              AppIcons.receipt,
              AppColors.primary,
              isWide, textTheme,
              isCount: true,
            ),
            _card(
              'Rata-rata',
              summary.averagePerTransaction,
              AppIcons.cart,
              AppColors.primary,
              isWide, textTheme,
            ),
          ],
        );
      },
    );
  }

  Widget _card(String label, int value, IconData icon, Color color,
      bool isWide, TextTheme tt,
      {bool isCount = false}) {
    return SizedBox(
      width: isWide ? 220 : double.infinity,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppIcons.md, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            isCount
                ? Text('$value',
                    style: tt.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))
                : AmountText(
                    amount: value,
                    style: tt.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ],
        ),
      ),
    );
  }
}

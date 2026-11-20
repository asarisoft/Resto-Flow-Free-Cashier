import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/bar_chart.dart';
import '../../core/widgets/choice_segment.dart';
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
import '../../core/services/csv_share.dart';
import 'report_export.dart';
import 'report_insights.dart';
import '../auth/auth_controller.dart';
import '../pos/pos_providers.dart';
import '../users/users_providers.dart';
import '../activity_log/activity_log_providers.dart';

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
    final canVoid = ref.watch(canVoidTransactionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Ekspor CSV',
            icon: const Icon(AppIcons.export),
            onPressed: () => _export(txnsAsync.valueOrNull ?? const []),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilterPanel(
                onReset: _filter.isDefault ? null : () => setState(() => _filter = const TransactionFilter()),
                top: PeriodFilterBar(
                  value: _filter.period,
                  onChanged: (p) => setState(() => _filter = _filter.copyWith(period: p)),
                ),
                fields: [
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
                  SearchField(
                    hint: 'Cari no. struk / nama item',
                    value: _filter.query,
                    onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
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
              const _RevenueChart(),
              const SizedBox(height: 24),
              TopProductsCard(range: _range),
              const SizedBox(height: 24),
              HourlyCard(range: _range),
              const SizedBox(height: 24),
              Text('Transaksi', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              txnsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (all) {
                  final txns = applyTransactionFilter(all, _filter);
                  // Transaksi void tetap tampil (tanda BATAL) tapi tidak dihitung.
                  final counted = txns.where((t) => !t.isVoid).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${counted.length} transaksi · Total ${formatRupiah(totalOf(counted))}',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      AppDataTable<models.Transaction>(
                        pageSize: 25,
                        rows: txns,
                        rowLabel: (t) => 'Transaksi nomor ${t.number ?? '-'}',
                        onRowTap: (t) => showDialog(
                          context: context,
                          builder: (dialogCtx) => TransactionDetailDialog(
                            txn: t,
                            onReprint: () => _reprint(t),
                            onShare: () => _share(t),
                            canVoid: canVoid,
                            onVoid: () async {
                              final ok = await _confirmVoid(t);
                              if (ok && dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                            },
                          ),
                        ),
                        empty: all.isEmpty
                            ? const EmptyState(icon: AppIcons.receipt, title: 'Belum ada transaksi')
                            : const EmptyState(
                                icon: AppIcons.search,
                                title: 'Tidak ada transaksi yang cocok',
                                subtitle: 'Ubah atau reset filter',
                              ),
                        columns: [
                          AppColumn(label: 'No.', minWidth: 80, cell: (t) => Text(t.number == null ? '-' : '#${t.number}')),
                          AppColumn(
                            label: 'Status',
                            minWidth: 140,
                            cell: (t) => t.isVoid
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('BATAL',
                                          style: textTheme.labelSmall?.copyWith(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w700)),
                                      if (t.voidReason != null && t.voidReason!.isNotEmpty)
                                        Text(t.voidReason!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall?.copyWith(
                                                color: AppColors.textSecondary)),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
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

  Future<void> _export(List<models.Transaction> all) async {
    final rows =
        applyTransactionFilter(all, _filter).where((t) => !t.isVoid).toList();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor')));
      return;
    }
    try {
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      await shareCsv('transaksi_$stamp.csv', transactionsCsv(rows));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekspor gagal: $e')));
    }
  }

  Future<bool> _confirmVoid(models.Transaction txn) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => _VoidDialog(txn: txn),
        ) ??
        false;
  }

  /// Bagikan struk sebagai teks lewat share sheet (user pilih WhatsApp dll).
  void _share(models.Transaction txn) async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null) return;
    try {
      await SharePlus.instance.share(ShareParams(
        text: ReceiptBuilder.shareText(txn, profile),
        subject: 'Struk #${txn.number ?? '-'}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan: $e')),
        );
      }
    }
  }

  void _reprint(models.Transaction txn) async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null) return;
    try {
      final bytes = await ReceiptBuilder.buildReceipt(txn, profile);
      final printer = ref.read(printerServiceProvider);
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
        // Kartu mengisi lebar penuh: HP 2 kolom, tablet 3, layar lebar 6.
        final cols = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 500
                ? 3
                : 2;
        final width = (constraints.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _card(
              'Omzet',
              summary.totalRevenue,
              AppIcons.trendingUp,
              AppColors.success,
              width, textTheme,
            ),
            _card(
              'Laba Kotor',
              summary.totalProfit,
              AppIcons.trendingUp,
              AppColors.success,
              width, textTheme,
            ),
            _card(
              'Pengeluaran',
              summary.totalExpense,
              AppIcons.expense,
              AppColors.warning,
              width, textTheme,
            ),
            _card(
              'Laba Bersih',
              summary.netProfit,
              AppIcons.wallet,
              summary.netProfit >= 0
                  ? AppColors.success
                  : AppColors.error,
              width, textTheme,
            ),
            _card(
              'Transaksi',
              summary.transactionCount,
              AppIcons.receipt,
              AppColors.primary,
              width, textTheme,
              isCount: true,
            ),
            _card(
              'Rata-rata',
              summary.averagePerTransaction,
              AppIcons.cart,
              AppColors.primary,
              width, textTheme,
            ),
          ],
        );
      },
    );
  }

  Widget _card(String label, int value, IconData icon, Color color,
      double width, TextTheme tt,
      {bool isCount = false}) {
    return SizedBox(
      width: width,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: isCount
                  ? Text('$value',
                      style: tt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700))
                  : AmountText(
                      amount: value,
                      style: tt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends ConsumerStatefulWidget {
  const _RevenueChart();

  @override
  ConsumerState<_RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends ConsumerState<_RevenueChart> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  bool _daily = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    // Dihitung tiap build (bukan sekali) agar ikut pindah bulan/tahun saat
    // app terbuka melewati pergantian bulan.
    final now = DateTime.now();
    final valuesAsync = _daily
        ? ref.watch(dailyRevenueProvider(DateTime(now.year, now.month)))
        : ref.watch(monthlyRevenueProvider(DateTime(now.year)));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Grafik Omzet', style: textTheme.titleMedium),
              ),
              ChoiceSegment<bool>(
                value: _daily,
                options: const [(true, 'Harian'), (false, 'Bulanan')],
                onChanged: (v) => setState(() => _daily = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          valuesAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (values) => BarChart(
              data: [
                for (var i = 0; i < values.length; i++)
                  BarChartDatum(
                    label: _daily ? '${i + 1}' : _months[i],
                    value: values[i],
                    detail: _daily
                        ? '${i + 1} ${_months[now.month - 1]} ${now.year} · ${formatRupiah(values[i])}'
                        : '${_months[i]} ${now.year} · ${formatRupiah(values[i])}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoidDialog extends ConsumerStatefulWidget {
  final models.Transaction txn;
  const _VoidDialog({required this.txn});

  @override
  ConsumerState<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends ConsumerState<_VoidDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      await ref.read(transactionRepositoryProvider).voidTransaction(
            id: widget.txn.id!,
            actorRole: user?.role ?? '',
            username: user?.username ?? '',
            reason: _reasonCtrl.text,
          );
      await logActivity(ref, 'transaction.void', '#${widget.txn.number ?? '-'}',
          detail: _reasonCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaksi #${widget.txn.number ?? '-'} dibatalkan')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Batalkan #${widget.txn.number ?? '-'}?',
      formKey: _formKey,
      saving: _saving,
      submitLabel: 'Batalkan',
      onSubmit: _submit,
      fields: [
        const Text(
          'Transaksi akan ditandai BATAL dan tidak dihitung di laporan. '
          'Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: AppColors.error),
        ),
        TextFormField(
          controller: _reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan *',
            hintText: 'minimal 3 karakter',
          ),
          validator: (v) {
            if (v == null || v.trim().length < 3) {
              return 'Alasan wajib diisi minimal 3 karakter';
            }
            return null;
          },
        ),
      ],
    );
  }
}

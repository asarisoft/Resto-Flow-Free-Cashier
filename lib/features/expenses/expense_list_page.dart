import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_panel.dart';
import '../../core/widgets/period_filter_bar.dart';
import '../../core/widgets/search_field.dart';
import '../../models/expense.dart';
import 'expense_filter.dart';
import 'expense_form_dialog.dart';
import 'expense_providers.dart';
import 'package:intl/intl.dart';
import '../../core/services/csv_share.dart';
import 'expense_export.dart';

class ExpenseListPage extends ConsumerStatefulWidget {
  const ExpenseListPage({super.key});

  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  ExpenseFilter _filter = const ExpenseFilter();

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Ekspor CSV',
            icon: const Icon(AppIcons.export),
            onPressed: () => _export(expensesAsync.valueOrNull ?? const []),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: _buildBody,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_expense',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(AppIcons.add),
        label: const Text('Tambah'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const ExpenseFormDialog(),
        ),
      ),
    );
  }

  Future<void> _export(List<Expense> all) async {
    final rows = applyExpenseFilter(all, _filter, DateTime.now());
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor')));
      return;
    }
    try {
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      await shareCsv('pengeluaran_$stamp.csv', expensesCsv(rows));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekspor gagal: $e')));
    }
  }

  Widget _buildBody(List<Expense> all) {
    final filtered = applyExpenseFilter(all, _filter, DateTime.now());
    final categories = expenseCategories(all);
    // Kategori terpilih yang sudah tak ada di data → jangan crash dropdown.
    final category = categories.contains(_filter.category) ? _filter.category : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            FilterPanel(
              onReset: _filter.isDefault ? null : () => setState(() => _filter = const ExpenseFilter()),
              top: PeriodFilterBar(
                value: _filter.period,
                onChanged: (p) => setState(() => _filter = _filter.copyWith(period: p)),
              ),
              fields: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(category),
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                      for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _filter = v == null
                        ? _filter.copyWith(clearCategory: true)
                        : _filter.copyWith(category: v)),
                  ),
                ),
                SearchField(
                  hint: 'Cari catatan / kategori',
                  value: _filter.query,
                  onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Summary(total: totalExpenses(filtered), count: filtered.length, periodLabel: _filter.period.label),
            const SizedBox(height: 16),
            AppDataTable<Expense>(
              pageSize: 25,
              rowLabel: (e) => 'Ubah pengeluaran ${e.category ?? ''} ${e.amount}',
              onRowTap: (e) => showDialog(context: context, builder: (_) => ExpenseFormDialog(expense: e)),
              empty: all.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.expense,
                      title: 'Belum ada pengeluaran',
                      subtitle: 'Catat pengeluaran pertama Anda',
                    )
                  : const EmptyState(
                      icon: AppIcons.search,
                      title: 'Tidak ada pengeluaran yang cocok',
                      subtitle: 'Ubah atau reset filter',
                    ),
              rows: filtered,
              columns: [
                AppColumn<Expense>(
                  label: 'Tanggal',
                  minWidth: 120,
                  cell: (e) => Text(formatExpenseDate(e.date)),
                ),
                AppColumn<Expense>(
                  label: 'Kategori',
                  minWidth: 140,
                  cell: (e) => Text(_orDash(e.category)),
                ),
                AppColumn<Expense>(
                  label: 'Catatan',
                  flex: 2,
                  minWidth: 200,
                  cell: (e) => Text(_orDash(e.note)),
                ),
                AppColumn<Expense>(
                  label: 'Nominal',
                  minWidth: 140,
                  numeric: true,
                  cell: (e) => AmountText(
                    amount: e.amount,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.price,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _orDash(String? s) => (s == null || s.trim().isEmpty) ? '—' : s.trim();

class _Summary extends StatelessWidget {
  final int total;
  final int count;
  final String periodLabel;

  const _Summary({required this.total, required this.count, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 320,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total pengeluaran · $periodLabel',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                AmountText(
                  amount: total,
                  style: textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.price,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jumlah catatan',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('$count', style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

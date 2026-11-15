import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/expense.dart';
import 'expense_form_dialog.dart';
import 'expense_providers.dart';

class ExpenseListPage extends ConsumerWidget {
  const ExpenseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final monthTotal = _monthTotal(expenses, DateTime.now());
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: expenses.isEmpty
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _MonthlyTotal(amount: monthTotal),
                        ),
                        const Expanded(
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Belum ada pengeluaran',
                            subtitle: 'Catat pengeluaran pertama Anda',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _MonthlyTotal(amount: monthTotal),
                        const SizedBox(height: 16),
                        for (final expense in expenses) ...[
                          _ExpenseCard(expense: expense),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_expense',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const ExpenseFormDialog(),
        ),
      ),
    );
  }
}

int _monthTotal(List<Expense> expenses, DateTime now) => expenses
    .where((e) => e.date.year == now.year && e.date.month == now.month)
    .fold(0, (total, e) => total + e.amount);

class _MonthlyTotal extends StatelessWidget {
  final int amount;

  const _MonthlyTotal({required this.amount});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Pengeluaran Bulan Ini',
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          AmountText(
            amount: amount,
            style: textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.price,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final category = expense.category?.trim();
    final note = expense.note?.trim();
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category == null || category.isEmpty
                      ? 'Pengeluaran'
                      : category,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  formatExpenseDate(expense.date),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AmountText(
            amount: expense.amount,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.price,
            ),
          ),
        ],
      ),
    );
  }
}

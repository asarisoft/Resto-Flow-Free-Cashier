import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/transaction.dart' as models;
import '../../models/transaction_item.dart';
import 'transaction_filter.dart';

/// Rincian satu transaksi: item, total, bayar, kembali, laba + cetak ulang.
class TransactionDetailDialog extends StatelessWidget {
  final models.Transaction txn;
  final VoidCallback onReprint;

  const TransactionDetailDialog({super.key, required this.txn, required this.onReprint});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final avail = MediaQuery.sizeOf(context).width - 96;
    final width = avail < 560 ? avail : 560.0;

    Widget line(String label, int amount, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: AppColors.textPrimary,
                    )),
              ),
              AmountText(
                amount: amount,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );

    return AlertDialog(
      title: Text('Transaksi #${txn.number}'),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${DateFormat('dd/MM/yyyy HH:mm').format(txn.createdAt)} · ${paymentLabel(txn.paymentMethod)}',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              AppDataTable<TransactionItem>(
                pageSize: 100,
                rows: txn.items,
                columns: [
                  AppColumn(label: 'Item', flex: 3, minWidth: 160, cell: (i) => Text(i.name)),
                  AppColumn(label: 'Qty', minWidth: 60, numeric: true, cell: (i) => Text('${i.qty}')),
                  AppColumn(
                    label: 'Subtotal',
                    flex: 2,
                    minWidth: 120,
                    numeric: true,
                    cell: (i) => AmountText(amount: i.subtotal, style: textTheme.bodyLarge),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              line('Subtotal', txn.subtotal),
              if (txn.discount > 0) line('Diskon', -txn.discount, color: AppColors.error),
              line('Total', txn.total, bold: true),
              line('Dibayar', txn.paid),
              if (txn.change > 0) line('Kembali', txn.change),
              const Divider(height: 24),
              line('Laba', txn.profit, color: txn.profit >= 0 ? AppColors.success : AppColors.error),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: width,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.inputBorder),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(label: 'Cetak ulang', icon: AppIcons.print, onPressed: onReprint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

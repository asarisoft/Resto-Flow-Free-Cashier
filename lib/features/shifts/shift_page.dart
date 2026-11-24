import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/shift.dart';
import '../../printer/printer_service.dart';
import '../../printer/receipt_builder.dart';
import '../auth/auth_controller.dart';
import '../reports/report_providers.dart';
import '../settings/settings_providers.dart';
import 'shift_calc.dart';
import '../activity_log/activity_log_providers.dart';
import 'shift_providers.dart';

/// Nominal kas (modal awal / uang di laci): int >= 0.
int? parseShiftCash(String raw) {
  final v = int.tryParse(raw.trim());
  if (v == null || v < 0) return null;
  return v;
}

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openAsync = ref.watch(openShiftProvider);
    final historyAsync = ref.watch(shiftHistoryProvider);
    final textTheme = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shift Kasir'),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              openAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (open) => _ShiftStatusCard(shift: open),
              ),
              const SizedBox(height: 24),
              Text('Riwayat Shift', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (all) {
                  final closed = all.where((s) => !s.isOpen).toList();
                  if (closed.isEmpty) {
                    return const EmptyState(
                      icon: AppIcons.receipt,
                      title: 'Belum ada shift selesai',
                    );
                  }
                  return Column(
                    children: [for (final s in closed) _ShiftHistoryRow(shift: s)],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftStatusCard extends ConsumerWidget {
  final Shift? shift;
  const _ShiftStatusCard({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final open = shift;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.wallet,
                size: AppIcons.md,
                color: open != null ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                open != null ? 'Shift terbuka' : 'Belum ada shift terbuka',
                style: textTheme.titleMedium?.copyWith(
                  color: open != null ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (open != null) ...[
            const SizedBox(height: 12),
            Text(
              'Dibuka ${DateFormat('dd/MM/yyyy HH:mm').format(open.openedAt)} oleh ${open.openedBy}',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Modal awal', style: textTheme.bodyMedium),
                const Spacer(),
                AmountText(amount: open.openingCash, style: textTheme.bodyLarge),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: open != null ? 'Tutup Shift' : 'Buka Shift',
            icon: open != null ? AppIcons.close : AppIcons.add,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => open != null
                  ? _CloseShiftDialog(shift: open)
                  : const _OpenShiftDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftHistoryRow extends StatelessWidget {
  final Shift shift;
  const _ShiftHistoryRow({required this.shift});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final diff = (shift.countedCash ?? 0) - (shift.expectedCash ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${DateFormat('dd/MM HH:mm').format(shift.openedAt)} → '
                  '${shift.closedAt == null ? '-' : DateFormat('dd/MM HH:mm').format(shift.closedAt!)}',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                AmountText(
                  amount: diff,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: diff >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Dibuka ${shift.openedBy}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Laci ${formatRupiah(shift.countedCash ?? 0)} · '
              'Seharusnya ${formatRupiah(shift.expectedCash ?? 0)}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenShiftDialog extends ConsumerStatefulWidget {
  const _OpenShiftDialog();

  @override
  ConsumerState<_OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends ConsumerState<_OpenShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseShiftCash(_cashCtrl.text)!;
    setState(() => _saving = true);
    try {
      final username = ref.read(currentUserProvider).valueOrNull?.username ?? '';
      await ref.read(shiftsDaoProvider).open(openedBy: username, openingCash: amount);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buka shift: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Buka Shift',
      formKey: _formKey,
      saving: _saving,
      submitLabel: 'Buka Shift',
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _cashCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Modal awal laci (Rp) *',
            prefixText: 'Rp ',
            hintText: '0',
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            if (parseShiftCash(v) == null) return 'Harus angka 0 atau lebih';
            return null;
          },
        ),
      ],
    );
  }
}

class _CloseShiftDialog extends ConsumerStatefulWidget {
  final Shift shift;
  const _CloseShiftDialog({required this.shift});

  @override
  ConsumerState<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<_CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final counted = parseShiftCash(_cashCtrl.text)!;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final reports = ref.read(reportsDaoProvider);
      final revenue = await reports.sumRevenueByMethod(widget.shift.openedAt, now);
      final expense =
          await reports.sumExpensesCreatedBetween(widget.shift.openedAt, now);
      final recap = computeShiftRecap(
        openingCash: widget.shift.openingCash,
        revenueByMethod: revenue,
        totalExpense: expense,
        countedCash: counted,
      );
      final username = ref.read(currentUserProvider).valueOrNull?.username ?? '';
      await ref.read(shiftsDaoProvider).close(
            id: widget.shift.id,
            closedBy: username,
            countedCash: counted,
            expectedCash: recap.expectedCash,
          );
      await logActivity(ref, 'shift.close', 'oleh $username',
          detail: 'selisih ${recap.difference}');
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog(
        context: context,
        builder: (_) => _ShiftRecapDialog(
          shift: Shift(
            id: widget.shift.id,
            openedAt: widget.shift.openedAt,
            openedBy: widget.shift.openedBy,
            openingCash: widget.shift.openingCash,
            closedAt: now,
            closedBy: username,
            countedCash: counted,
            expectedCash: recap.expectedCash,
          ),
          recap: recap,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal tutup shift: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Tutup Shift',
      formKey: _formKey,
      saving: _saving,
      submitLabel: 'Hitung & Tutup',
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _cashCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Uang di laci (Rp) *',
            prefixText: 'Rp ',
            hintText: '0',
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            if (parseShiftCash(v) == null) return 'Harus angka 0 atau lebih';
            return null;
          },
        ),
      ],
    );
  }
}

class _ShiftRecapDialog extends ConsumerWidget {
  final Shift shift;
  final ShiftRecap recap;
  const _ShiftRecapDialog({required this.shift, required this.recap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    Widget row(String label, int value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodyLarge),
              AmountText(
                amount: value,
                style: (textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
              ),
            ],
          ),
        );

    return AlertDialog(
      title: const Text('Rekap Kasir'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row('Omzet Tunai', recap.cashRevenue),
            row('Omzet QRIS', recap.qrisRevenue),
            row('Omzet Kartu', recap.cardRevenue),
            if (recap.otherRevenue != 0) row('Omzet Lain', recap.otherRevenue),
            row('Pengeluaran', recap.totalExpense),
            const Divider(height: 16),
            row('Kas seharusnya', recap.expectedCash),
            row('Kas di laci', shift.countedCash ?? 0),
            row('Selisih', recap.difference,
                color: recap.difference >= 0 ? AppColors.success : AppColors.error),
            const SizedBox(height: 8),
            Text(
              'Semua pengeluaran dianggap tunai.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Selesai'),
        ),
        FilledButton.icon(
          onPressed: () => _print(ref, context),
          icon: const Icon(AppIcons.print, size: AppIcons.sm),
          label: const Text('Cetak'),
        ),
      ],
    );
  }

  Future<void> _print(WidgetRef ref, BuildContext context) async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null) return;
    try {
      final bytes = ReceiptBuilder.buildShiftRecapText(
        profile: profile,
        shift: shift,
        recap: recap,
      ).codeUnits;
      final printer = ref.read(printerServiceProvider);
      if (printer.isConnected) {
        await printer.printBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Rekap dicetak')));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Printer tidak terhubung')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
      }
    }
  }
}

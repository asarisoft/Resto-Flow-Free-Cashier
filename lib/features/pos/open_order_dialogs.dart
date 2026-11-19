import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/transaction.dart' as models;
import 'cart_provider.dart';
import 'pos_providers.dart';

/// Dialog label pesanan terbuka (nama pelanggan / no meja) untuk tombol
/// "Simpan" di POS. [initial] terisi saat menyimpan ulang pesanan yang
/// sedang dilanjutkan. Submit menyimpan keranjang sebagai status 'open'
/// (tanpa nomor struk) lalu mengosongkan keranjang.
class OpenOrderLabelDialog extends ConsumerStatefulWidget {
  final String? initial;
  const OpenOrderLabelDialog({super.key, this.initial});

  @override
  ConsumerState<OpenOrderLabelDialog> createState() =>
      _OpenOrderLabelDialogState();
}

class _OpenOrderLabelDialogState extends ConsumerState<OpenOrderLabelDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _labelCtrl = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final cart = ref.read(cartProvider);
      final subtotal = cart.fold(0, (s, i) => s + i.subtotal);
      final txn = models.Transaction(
        items: cart,
        subtotal: subtotal,
        total: subtotal,
        paid: 0,
        profit: 0,
        status: 'open',
        label: _labelCtrl.text,
        createdAt: DateTime.now(),
      );
      final resumed = ref.read(resumedOrderProvider);
      if (resumed == null) {
        await repo.save(txn);
      } else {
        await repo.updateOpen(id: resumed.id, txn: txn);
      }
      ref.read(cartProvider.notifier).clear();
      ref.read(resumedOrderProvider.notifier).state = null;
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan "${_labelCtrl.text.trim()}" disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Simpan pesanan',
      formKey: _formKey,
      saving: _saving,
      submitLabel: 'Simpan',
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _labelCtrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Nama pelanggan / no meja *',
            hintText: 'mis. Meja 2',
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
        ),
      ],
    );
  }
}

/// Daftar pesanan terbuka: pilih untuk melanjutkan (isi keranjang), atau
/// hapus (dengan konfirmasi). Terbuka untuk kasir & owner.
class OpenOrdersDialog extends ConsumerWidget {
  const OpenOrdersDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(openOrdersProvider);
    return AlertDialog(
      title: const Text('Pesanan terbuka'),
      content: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: AppIcons.receipt,
              title: 'Tidak ada pesanan terbuka',
            );
          }
          // Dialog selebar mungkin (maks 420), tinggi maks 400 agar daftar
          // panjang bisa di-scroll di dalam dialog.
          final avail = MediaQuery.sizeOf(context).width - 96;
          return SizedBox(
            width: avail < 420 ? avail : 420.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < orders.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _OpenOrderTile(order: orders[i]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

class _OpenOrderTile extends ConsumerWidget {
  final models.Transaction order;
  const _OpenOrderTile({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final itemCount = order.items.fold(0, (s, i) => s + i.qty);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        order.label ?? '',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$itemCount item · ${DateFormat('dd/MM HH:mm').format(order.createdAt)}',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(
            amount: order.total,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Hapus pesanan ${order.label}',
            icon: const Icon(AppIcons.delete, color: AppColors.error),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      onTap: () => _resume(context, ref),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ganti isi keranjang?'),
          content: Text(
              'Keranjang sedang berisi item lain dan akan diganti dengan pesanan "${order.label}".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    ref.read(cartProvider.notifier).setItems(order.items);
    ref.read(resumedOrderProvider.notifier).state =
        (id: order.id!, label: order.label ?? '');
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pesanan?'),
        content:
            Text('Pesanan "${order.label}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(transactionRepositoryProvider).deleteOpen(order.id!);
      // Pesanan yang sedang dilanjutkan di keranjang ikut terhapus:
      // kosongkan keranjang & lepas resumed agar Bayar tidak menunjuk
      // baris yang sudah tidak ada.
      final resumed = ref.read(resumedOrderProvider);
      if (resumed != null && resumed.id == order.id) {
        ref.read(cartProvider.notifier).clear();
        ref.read(resumedOrderProvider.notifier).state = null;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }
}

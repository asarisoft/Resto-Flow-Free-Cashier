import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../models/product.dart';
import '../../models/transaction.dart' as models;
import '../../models/transaction_item.dart';
import '../../models/resto_profile.dart';
import '../../printer/printer_service.dart';
import '../../printer/receipt_builder.dart';
import '../../features/products/product_providers.dart';
import '../pos/cart_provider.dart';
import '../../core/widgets/choice_segment.dart';
import '../../core/services/daos/sales_dao.dart' show InsufficientStockException;
import 'checkout_calc.dart';
import '../settings/settings_providers.dart';
import 'open_order_dialogs.dart';
import 'pos_providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/qty_stepper.dart';
import '../../core/widgets/tap_area.dart';
import '../products/product_card.dart';
import '../shifts/shift_page.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  String _selectedCategory = 'All Menu';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final cart = ref.watch(cartProvider);
    final isWide = MediaQuery.of(context).size.width >= 768; // Tablet breakpoint

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide ? null : AppBar(
        title: const Text('Kasir'),
        actions: [
          const _OpenOrdersButton(),
          IconButton(
            tooltip: 'Shift Kasir',
            icon: const Icon(AppIcons.wallet),
            onPressed: () => _openShiftPage(context),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          // Extract categories
          final categories = ['All Menu'];
          for (final p in products) {
            if (p.category != null && p.category!.isNotEmpty && !categories.contains(p.category)) {
              categories.add(p.category!);
            }
          }

          // Filter products
          final filteredProducts = _selectedCategory == 'All Menu'
              ? products
              : products.where((p) => p.category == _selectedCategory).toList();

          if (isWide) {
            return _buildTabletLayout(categories, filteredProducts, cart);
          } else {
            return _buildMobileLayout(categories, filteredProducts, cart);
          }
        },
      ),
    );
  }

  void _openShiftPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShiftPage()),
    );
  }

  Widget _buildTabletLayout(List<String> categories, List<Product> products, List<TransactionItem> cart) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Categories + Grid)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 24, right: 24),
                child: Row(
                  children: [
                    Text('Menu', style: AppTypography.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const _OpenOrdersButton(),
                    IconButton(
                      tooltip: 'Shift Kasir',
                      icon: const Icon(AppIcons.wallet),
                      onPressed: () => _openShiftPage(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Horizontal Categories
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == _selectedCategory;
                    return _CategoryCard(
                      label: cat,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedCategory = cat),
                    );
                  },
                ),
              ),
              // Main Products
              Expanded(
                child: _ProductGrid(products: products, cart: cart, isWide: true),
              ),
            ],
          ),
        ),
        // Rincian pesanan: ~26% layar, dibatasi 300-340 dp.
        LayoutBuilder(
          builder: (context, _) {
            final w = (MediaQuery.sizeOf(context).width * 0.26).clamp(300.0, 340.0);
            return Container(
              key: const Key('cart_panel'),
              width: w,
              color: AppColors.surface,
              child: _CartPanel(cart: cart),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<String> categories, List<Product> products, List<TransactionItem> cart) {
    return Column(
      children: [
        // Horizontal Categories
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _CategoryCard(
                  label: cat,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
        Expanded(child: _ProductGrid(products: products, cart: cart, isWide: false)),
        // Minimal Cart Summary at bottom
        if (cart.isNotEmpty)
          TapArea(
            label: 'Lihat keranjang',
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => _showMobileCart(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.cart, color: AppColors.onPrimary),
                  const SizedBox(width: 12),
                  Text('${cart.fold(0, (s, i) => s + i.qty)} item',
                      style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  AmountText(
                    amount: cart.fold(0, (s, i) => s + i.subtotal),
                    style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showMobileCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _CartPanel(cart: ref.watch(cartProvider)),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapArea(
      label: label,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Tombol "Pesanan terbuka (N)" di header POS (mobile & tablet).
/// Tersembunyi saat tidak ada pesanan terbuka.
class _OpenOrdersButton extends ConsumerWidget {
  const _OpenOrdersButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(openOrdersProvider).valueOrNull?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => const OpenOrdersDialog(),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      icon: const Icon(AppIcons.receipt, size: AppIcons.md),
      label: Text('Pesanan terbuka ($count)'),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  final List<TransactionItem> cart;
  final bool isWide;

  const _ProductGrid({required this.products, required this.cart, required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: EdgeInsets.only(
        top: isWide ? 76 : 16,
        left: isWide ? 24 : 16,
        right: isWide ? 24 : 16,
        bottom: 24,
      ),
      gridDelegate: productGridDelegate,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final cartItem = cart.where((item) => item.productId == product.id).firstOrNull;
        return ProductCard(
          product: product,
          cartQty: cartItem?.qty ?? 0,
          onTap: product.ready
              ? () {
                  final stock = product.stock;
                  // Stok dilacak: jangan tambah melebihi sisa. (Penjaga
                  // terakhir ada di SalesDao saat bayar.)
                  if (stock != null && (cartItem?.qty ?? 0) >= stock) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text('Stok ${product.name} tinggal $stock')));
                    return;
                  }
                  ref.read(cartProvider.notifier).addItem(product);
                }
              : null,
        );
      },
    );
  }
}

class _CartPanel extends ConsumerWidget {
  final List<TransactionItem> cart;

  const _CartPanel({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final subtotal = cart.fold(0, (s, i) => s + i.subtotal);
    final resumed = ref.watch(resumedOrderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48, left: 24, right: 24, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rincian Pesanan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              if (resumed != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Melanjutkan pesanan "${resumed.label}"',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text('Keranjang kosong',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const Divider(height: 32),
                  itemBuilder: (_, i) => _CartItemRow(
                    index: i,
                    item: cart[i],
                    notifier: ref.read(cartProvider.notifier),
                  ),
                ),
        ),
        // Total Box
        if (cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(color: Color(0x1F0E0E0E), blurRadius: 10, offset: Offset(0, -4))
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Jumlah item (${cart.fold(0, (s, i) => s + i.qty)})', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  AmountText(amount: subtotal, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  AmountText(
                    amount: subtotal,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cart.isEmpty ? null : () => _saveOpen(context, ref),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.border),
                        elevation: 0,
                      ),
                      child: Text('Simpan', style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cart.isEmpty ? null : () => _checkout(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Bayar', style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          const Icon(AppIcons.arrowRight, size: AppIcons.md),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _checkout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const CheckoutDialog(),
    );
  }

  /// Simpan keranjang sebagai pesanan terbuka (bayar nanti).
  void _saveOpen(BuildContext context, WidgetRef ref) {
    final resumed = ref.read(resumedOrderProvider);
    showDialog(
      context: context,
      builder: (_) => OpenOrderLabelDialog(initial: resumed?.label),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final int index;
  final TransactionItem item;
  final CartNotifier notifier;

  const _CartItemRow({
    required this.index,
    required this.item,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(AppIcons.food, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TapArea(
                  label: item.note == null || item.note!.isEmpty
                      ? 'Tambah catatan ${item.name}'
                      : 'Ubah catatan ${item.name}',
                  onTap: () => _editNote(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.note != null && item.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.note!,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                QtyStepper(
                  value: item.qty,
                  onChanged: (q) => notifier.updateQty(index, q),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                amount: item.subtotal,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.price,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.discount > 0)
                Text('Disc: Rp ${item.discount}', style: textTheme.labelSmall?.copyWith(color: AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(title: item.name, initial: item.note),
    );
    if (result == null) return;
    final note = result.trim();
    notifier.setNote(index, note.isEmpty ? null : note);
  }
}

class _NoteDialog extends StatefulWidget {
  final String title;
  final String? initial;

  const _NoteDialog({required this.title, this.initial});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Catatan',
          hintText: 'mis. tanpa sambal',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _paidCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  /// Mode input diskon: false = Rp, true = persen.
  bool _percentMode = false;

  int get _discInput => int.tryParse(_discCtrl.text) ?? 0;

  CheckoutCalc get _calc => CheckoutCalc(
        items: ref.read(cartProvider),
        discount: _discInput,
        percent: _percentMode ? _discInput : null,
        paid: int.tryParse(_paidCtrl.text) ?? 0,
      );
  int get _subtotal => _calc.subtotal;

  /// Rupiah yang benar-benar dipotong (sama dengan yang dipakai total & laba).
  int get _discount => _calc.effectiveDiscount;
  int get _total => _calc.total;
  int get _paid => int.tryParse(_paidCtrl.text) ?? 0;
  int get _change => _calc.change;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final isWide = MediaQuery.of(context).size.width >= 600;
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: SizedBox(
        width: isWide ? 400 : double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Subtotal', _subtotal, textTheme),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discCtrl,
                      decoration: InputDecoration(
                        labelText: _percentMode ? 'Diskon (%)' : 'Diskon (Rp)',
                        prefixText: _percentMode ? null : 'Rp ',
                        suffixText: _percentMode ? '%' : null,
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        if (_percentMode) LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ChoiceSegment<bool>(
                      value: _percentMode,
                      options: const [(false, 'Rp'), (true, '%')],
                      onChanged: (v) => setState(() {
                        _percentMode = v;
                        // Angka lama beda arti di mode lain (mis. 10000 ≠ 10000%).
                        _discCtrl.clear();
                      }),
                    ),
                  ),
                ],
              ),
              if (_percentMode && _discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Potongan ${formatRupiah(_discount)}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              const Divider(height: 24),
              _row('Total', _total, textTheme, bold: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(labelText: 'Metode'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                  DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                  DropdownMenuItem(value: 'card', child: Text('Kartu')),
                ],
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dibayar (Rp)',
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              if (_method == 'cash' && _total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickCashButton('Uang pas', _total),
                      for (final s in quickCashSuggestions(_total))
                        if (s != _total) _quickCashButton(formatRupiah(s), s),
                    ],
                  ),
                ),
              if (_change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _row('Kembali', _change, textTheme),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving || _total <= 0 ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan & Cetak'),
        ),
      ],
    );
  }

  Widget _row(String label, int amount, TextTheme tt,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)
                  : tt.bodyLarge),
          AmountText(
            amount: amount,
            style: (bold ? tt.titleMedium : tt.bodyLarge)
                ?.copyWith(fontWeight: bold ? FontWeight.w700 : null),
          ),
        ],
      ),
    );
  }

  Widget _quickCashButton(String label, int amount) {
    return OutlinedButton(
      onPressed: () {
        final s = amount.toString();
        _paidCtrl.value = TextEditingValue(
          text: s,
          selection: TextSelection.collapsed(offset: s.length),
        );
        setState(() {});
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  Future<void> _save() async {
    if (_paid < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uang dibayar kurang dari total')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final items = ref.read(cartProvider);
      final notif = ref.read(cartProvider.notifier);
      final txnRepo = ref.read(transactionRepositoryProvider);
      final profileAsync = ref.read(profileProvider);
      final resumed = ref.read(resumedOrderProvider);

      // Stok dicek dulu (sebelum nomor struk diambil) agar tidak ada nomor terbuang.
      await txnRepo.checkStock(items);

      final profit = _calc.profit;

      final txn = models.Transaction(
        items: items,
        subtotal: _subtotal,
        discount: _discount,
        discountType: _discount > 0 && _percentMode ? 'percent' : 'nominal',
        discountPercent:
            _discount > 0 && _percentMode ? _discInput.clamp(0, 100) : null,
        total: _total,
        paid: _paid,
        change: _change,
        paymentMethod: _method,
        profit: profit,
        createdAt: DateTime.now(),
      );

      // Pesanan terbuka yang dilanjutkan: bayar = UPDATE baris yang sama
      // (nomor struk & createdAt baru). Pesanan baru: insert dengan nomor.
      final int number;
      if (resumed == null) {
        number = await txnRepo.getNextNumber();
        await txnRepo.save(txn.copyWith(number: number));
      } else {
        try {
          number = await txnRepo.payOpen(id: resumed.id, txn: txn);
        } on StateError catch (e) {
          // Pesanan lama sudah tidak ada (mis. dihapus dari perangkat lain):
          // lepas resumed agar kasir tidak macet — tekan tombol bayar lagi
          // dan keranjang tersimpan sebagai transaksi baru.
          ref.read(resumedOrderProvider.notifier).state = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('${e.message}. Tekan "Simpan & Cetak" lagi untuk transaksi baru.'),
              ),
            );
          }
          return;
        }
      }

      final profile = profileAsync.valueOrNull;
      if (profile != null) {
        _tryPrint(txn.copyWith(number: number), profile);
      }

      notif.clear();
      ref.read(resumedOrderProvider.notifier).state = null;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil disimpan!')),
        );
      }
    } on InsufficientStockException catch (e) {
      // Dialog tetap terbuka & keranjang utuh: kasir kurangi qty lalu bayar lagi.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tryPrint(
      models.Transaction txn, RestoProfile profile) async {
    try {
      final bytes = await ReceiptBuilder.buildReceipt(txn, profile);
      final printer = ref.read(printerServiceProvider);
      if (printer.isConnected) {
        await printer.printBytes(bytes);
      }
    } catch (_) {}
  }
}

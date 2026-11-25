import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/pop_on_change.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/product.dart';
import '../../models/transaction.dart' as models;
import '../../models/transaction_item.dart';
import '../../models/resto_profile.dart';
import '../../printer/printer_service.dart';
import '../../printer/receipt_builder.dart';
import '../../features/products/product_providers.dart';
import '../pos/cart_provider.dart';
import '../../core/widgets/choice_segment.dart';
import '../../core/services/daos/sales_dao.dart'
    show InsufficientStockException;
import 'checkout_calc.dart';
import '../settings/settings_providers.dart';
import 'open_order_dialogs.dart';
import 'pos_providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/qty_stepper.dart';
import '../../core/widgets/adaptive_sheet.dart';
import '../../core/widgets/category_filter_bar.dart';
import '../../core/widgets/tap_area.dart';
import '../products/product_card.dart';
import '../products/product_list_row.dart';
import '../products/product_view_mode.dart';
import '../../core/widgets/product_search_bar.dart';
import '../shifts/open_shift_card.dart';
import '../shifts/shift_page.dart';
import '../shifts/shift_providers.dart';
import '../../core/widgets/app_card.dart';
import 'package:intl/intl.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  String _selectedCategory = allCategoryLabel;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final cart = ref.watch(cartProvider);
    final isWide =
        MediaQuery.of(context).size.width >= 768; // Tablet breakpoint

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? null
          : AppBar(
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
          final categories = productCategories(products);
          final byCategory = filterProductsByCategory(products, _selectedCategory);
          final filteredProducts = filterProductsByName(byCategory, _query);

          if (isWide) {
            return _buildTabletLayout(categories, filteredProducts, cart, products.isEmpty);
          } else {
            return _buildMobileLayout(categories, filteredProducts, cart, products.isEmpty);
          }
        },
      ),
    );
  }

  Widget _searchBar(double horizontal) => Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 0),
        child: ProductSearchBar(
          value: _query,
          onChanged: (v) => setState(() => _query = v),
          isList: ref.watch(productViewModeProvider).valueOrNull ?? false,
          onToggleView: () => ref.read(productViewModeProvider.notifier).toggle(),
        ),
      );

  void _openShiftPage(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShiftPage()));
  }

  Widget _buildTabletLayout(
    List<String> categories,
    List<Product> products,
    List<TransactionItem> cart,
    bool noProductsYet,
  ) {
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
                    Text(
                      'Menu',
                      style: AppTypography.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _searchBar(0),
                        ),
                      ),
                    ),
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
              const _ShiftGate(horizontalPadding: 24),
              CategoryFilterBar(
                wide: true,
                categories: categories,
                selected: _selectedCategory,
                onSelected: (c) => setState(() => _selectedCategory = c),
              ),
              // Main Products
              Expanded(
                child: _ProductGrid(
                  products: products,
                  cart: cart,
                  isWide: true,
                  noProductsYet: noProductsYet,
                ),
              ),
            ],
          ),
        ),
        // Rincian pesanan: ~26% layar, dibatasi 300-340 dp.
        LayoutBuilder(
          builder: (context, _) {
            final w = (MediaQuery.sizeOf(context).width * 0.26).clamp(
              300.0,
              340.0,
            );
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

  Widget _buildMobileLayout(
    List<String> categories,
    List<Product> products,
    List<TransactionItem> cart,
    bool noProductsYet,
  ) {
    return Column(
      children: [
        const _ShiftGate(horizontalPadding: 12),
        _searchBar(12),
        CategoryFilterBar(
          categories: categories,
          selected: _selectedCategory,
          onSelected: (c) => setState(() => _selectedCategory = c),
        ),
        Expanded(
          child: _ProductGrid(
            products: products,
            cart: cart,
            isWide: false,
            noProductsYet: noProductsYet,
          ),
        ),
        // Minimal Cart Summary at bottom
        if (cart.isNotEmpty)
          TapArea(
            label: 'Lihat keranjang',
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => _showMobileCart(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  PopOnChange(
                    value: cart.fold(0, (s, i) => s + i.qty),
                    child: const Icon(AppIcons.cart, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${cart.fold(0, (s, i) => s + i.qty)} item',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: CountUpAmount(
                          amount: cart.fold(0, (s, i) => s + i.subtotal),
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
      // Isi sheet memantau keranjang sendiri (bukan salinan saat dibuka), dan
      // menutup sendiri setelah keranjang dikosongkan (bayar / simpan pesanan).
      builder: (sheetCtx) => Consumer(
        builder: (_, sheetRef, __) {
          sheetRef.listen(cartProvider, (prev, next) {
            if ((prev?.isNotEmpty ?? false) && next.isEmpty) {
              // removeRoute, bukan pop: dialog bayar ada DI ATAS sheet,
              // pop akan menutup route paling atas (dialog), bukan sheet ini.
              final route = ModalRoute.of(sheetCtx);
              if (route != null && route.isActive) {
                Navigator.of(sheetCtx).removeRoute(route);
              }
            }
          });
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _CartPanel(cart: sheetRef.watch(cartProvider)),
          );
        },
      ),
    );
  }
}

/// Di atas grid POS: kartu Buka Shift (belum ada shift) atau banner
/// (shift terbuka sejak sebelum hari ini). Transaksi tetap boleh di kasus banner.
class _ShiftGate extends ConsumerWidget {
  final double horizontalPadding;
  const _ShiftGate({required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(openShiftProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final shift = async.value;
    final Widget child;
    if (shift == null) {
      child = const OpenShiftCard();
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!shift.openedAt.isBefore(today)) return const SizedBox.shrink();
      child = AppCard(
        color: AppColors.peach,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Shift dibuka sejak ${DateFormat('dd/MM/yyyy').format(shift.openedAt)}. Tutup dulu?',
                style: AppTypography.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ShiftPage())),
              child: const Text('Ke Shift'),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        // Layar pendek (landscape HP): sisakan ruang untuk kategori & grid.
        maxHeight: MediaQuery.sizeOf(context).height *
            (MediaQuery.sizeOf(context).height < 500 ? 0.15 : 0.3),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
        child: child,
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
  final bool noProductsYet;

  const _ProductGrid({
    required this.products,
    required this.cart,
    required this.isWide,
    required this.noProductsYet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return Center(
        child: Text(noProductsYet ? productEmptyText : productNotFoundText),
      );
    }
    final isList = ref.watch(productViewModeProvider).valueOrNull ?? false;
    final padding = EdgeInsets.only(
      top: 16,
      left: isWide ? 24 : 16,
      right: isWide ? 24 : 16,
      bottom: 24,
    );
    int qtyOf(Product p) =>
        cart.where((i) => i.productId == p.id).firstOrNull?.qty ?? 0;
    if (isList) {
      return ListView.builder(
        padding: padding,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductListRow(
            product: product,
            cartQty: qtyOf(product),
            onTap: product.ready ? () => _add(context, ref, product) : null,
            onQtyChanged: (q) => _changeQty(context, ref, product, q),
          );
        },
      );
    }
    return GridView.builder(
      padding: padding,
      gridDelegate: productGridDelegateFor(context),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          cartQty: qtyOf(product),
          onTap: product.ready ? () => _add(context, ref, product) : null,
          onQtyChanged: isWide ? null : (q) => _changeQty(context, ref, product, q),
        );
      },
    );
  }

  void _changeQty(BuildContext context, WidgetRef ref, Product product, int q) {
    final current = cart.where((i) => i.productId == product.id).fold(0, (s, i) => s + i.qty);
    if (q > current) {
      _add(context, ref, product);
    } else {
      ref.read(cartProvider.notifier).decrementProduct(product.id);
    }
  }

  void _add(BuildContext context, WidgetRef ref, Product product) {
    final stock = product.stock;
    // Stok dilacak: jangan tambah melebihi sisa. (Penjaga
    // terakhir ada di SalesDao saat bayar.)
    // Jumlahkan semua baris produk ini (catatan item bisa
    // memecah produk yang sama jadi beberapa baris).
    final inCart = cart
        .where((i) => i.productId == product.id)
        .fold(0, (s, i) => s + i.qty);
    if (stock != null && inCart >= stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Stok ${product.name} tinggal $stock')),
        );
      return;
    }
    ref.read(cartProvider.notifier).addItem(product);
    HapticFeedback.selectionClick();
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
    final shiftOpen = ref.watch(openShiftProvider).valueOrNull != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Layar pendek (landscape HP): padding atas kecil agar panel muat.
          padding: EdgeInsets.only(
            top: MediaQuery.sizeOf(context).height < 500 ? 12 : 48,
            left: 24,
            right: 24,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rincian Pesanan',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (resumed != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Melanjutkan pesanan "${resumed.label}"',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text(
                    'Keranjang kosong',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
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
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Jumlah item (${cart.fold(0, (s, i) => s + i.qty)})',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CountUpAmount(
                      amount: subtotal,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: CountUpAmount(
                          amount: subtotal,
                          style: textTheme.displayMedium?.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Tooltip(
                  message: shiftOpen ? '' : 'Buka shift dulu',
                  child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: cart.isEmpty || !shiftOpen
                            ? null
                            : () => _saveOpen(context, ref),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          side: const BorderSide(color: AppColors.border),
                          elevation: 0,
                        ),
                        child: Text(
                          'Simpan',
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Bayar',
                        onPressed: cart.isEmpty || !shiftOpen
                            ? null
                            : () => _checkout(context, ref),
                      ),
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _checkout(BuildContext context, WidgetRef ref) {
    showCheckout(context);
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
    // Dua baris supaya muat di panel sempit (HP & panel keranjang tablet):
    // [nama + catatan]  /  [stepper qty ........ subtotal]
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          const SizedBox(height: 4),
          Row(
            children: [
              QtyStepper(
                value: item.qty,
                onChanged: (q) => notifier.updateQty(index, q),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        amount: item.subtotal,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.price,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.discount > 0)
                      Text(
                        'Disc: Rp ${item.discount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
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
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

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

/// Buka pembayaran: bottom sheet di HP (geser-tutup), dialog di tablet.
Future<void> showCheckout(BuildContext context) => showAdaptiveSheet(
  context,
  builder: (_, asSheet) => CheckoutDialog(asSheet: asSheet),
);

class CheckoutDialog extends ConsumerStatefulWidget {
  /// true = isi untuk modal bottom sheet (HP), false = AlertDialog.
  final bool asSheet;
  const CheckoutDialog({super.key, this.asSheet = false});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _paidCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;
  bool _done = false;

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
    // Mode sheet (HP): jarak rapat, Total/Bayar di atas, diskon di bawah
    // (boleh di-scroll) agar Uang pas & Bayar muat tanpa scroll.
    final gap = widget.asSheet ? 8.0 : 12.0;
    final discW = <Widget>[
              _row('Subtotal', _subtotal, textTheme),
              TextField(
                controller: _discCtrl,
                decoration: InputDecoration(
                  labelText: _percentMode ? 'Diskon (%)' : 'Diskon (Rp)',
                  prefixText: _percentMode ? null : 'Rp ',
                  hintText: '0',
                  // Toggle Rp|% di dalam kolom (satu kotak, satu tinggi).
                  suffixIconConstraints: const BoxConstraints(),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
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
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  if (_percentMode) LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (_percentMode && _discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Potongan ${formatRupiah(_discount)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
    ];
    final payW = <Widget>[
              _row('Total', _total, textTheme, bold: true),
              SizedBox(height: gap),
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
              SizedBox(height: gap),
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
                  padding: EdgeInsets.only(top: gap),
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
    ];
    final body = _done
        ? _doneView(context)
        : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...(widget.asSheet
                  ? [...payW, const Divider(height: 24), ...discW]
                  : [...discW, const Divider(height: 24), ...payW]),
            ],
          ),
        );
    final actions = _done
        ? <Widget>[]
        : [
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
          ];
    if (widget.asSheet) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          8 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pembayaran', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Flexible(child: body),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      );
    }
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: SizedBox(width: isWide ? 400 : double.maxFinite, child: body),
      actions: actions,
    );
  }

  /// Tanda centang singkat setelah transaksi tersimpan.
  Widget _doneView(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.of(context, AppMotion.normal),
      curve: AppMotion.pop,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Icon(AppIcons.checkCircle, size: 72, color: AppColors.success),
      ),
    ),
  );

  Widget _row(String label, int amount, TextTheme tt, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: bold
                  ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)
                  : tt.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: AmountText(
                amount: amount,
                style: (bold ? tt.titleMedium : tt.bodyLarge)?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
              ),
            ),
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
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        elevation: 2,
        shadowColor: AppColors.clayShadow,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        discountPercent: _discount > 0 && _percentMode
            ? _discInput.clamp(0, 100)
            : null,
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
                content: Text(
                  '${e.message}. Tekan "Simpan & Cetak" lagi untuk transaksi baru.',
                ),
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
        HapticFeedback.mediumImpact();
        final wait = AppMotion.of(context, AppMotion.slow);
        if (wait > Duration.zero) {
          setState(() => _done = true);
          await Future<void>.delayed(wait);
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil disimpan!')),
        );
      }
    } on InsufficientStockException catch (e) {
      // Dialog tetap terbuka & keranjang utuh: kasir kurangi qty lalu bayar lagi.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tryPrint(models.Transaction txn, RestoProfile profile) async {
    try {
      final bytes = await ReceiptBuilder.buildReceipt(txn, profile);
      final printer = ref.read(printerServiceProvider);
      if (printer.isConnected) {
        await printer.printBytes(bytes);
      }
    } catch (_) {}
  }
}

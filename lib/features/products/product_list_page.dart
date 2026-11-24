import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/product.dart';
import '../products/product_providers.dart';
import 'product_form_dialog.dart';
import '../../core/theme/app_icons.dart';
import 'product_card.dart';
import '../categories/category_page.dart';
import '../../core/services/daos/categories_dao.dart';
import '../users/users_providers.dart';
import '../activity_log/activity_log_providers.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);
    final canManage = ref.watch(canManageProductsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produk'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (canManage) IconButton(
            tooltip: 'Kelola kategori',
            icon: const Icon(AppIcons.category),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryPage(initialType: CategoryType.product)),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return EmptyState(
              icon: AppIcons.product,
              title: 'Belum ada produk',
              subtitle: 'Tambahkan produk pertama Anda',
              action: !canManage ? null : FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                icon: const Icon(AppIcons.add),
                label: const Text('Tambah Produk'),
                onPressed: () => _openForm(context, ref),
              ),
            );
          }
          return _ProductGrid(products: products, ref: ref, canManage: canManage);
        },
      ),
      floatingActionButton: !canManage ? null : FloatingActionButton(
        heroTag: 'add_product',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => _openForm(context, ref),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const ProductFormDialog());
  }
}

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  final WidgetRef ref;
  final bool canManage;

  const _ProductGrid({required this.products, required this.ref, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (_, __) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productListProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: productGridDelegateFor(context),
            itemCount: products.length,
            itemBuilder: (_, i) => ProductCard(
              product: products[i],
              onTap: canManage ? () => _edit(context, products[i]) : null,
              onToggleReady: canManage ? () => _toggle(context, products[i]) : null,
            ),
          ),
        );
      },
    );
  }

  void _edit(BuildContext context, Product product) {
    showDialog(context: context, builder: (_) => ProductFormDialog(product: product));
  }

  void _toggle(BuildContext context, Product product) async {
    final repo = ref.read(productRepositoryProvider);
    try {
      await repo.toggleReady(product.id!, !product.ready);
    } on StateError catch (e) {
      // mis. stok habis: tidak bisa dijadikan ready sebelum stok ditambah.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    await logActivity(ref, 'product.ready', product.name,
        detail: !product.ready ? 'jadi ready' : 'jadi habis');
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ready_chip.dart';
import '../../core/widgets/amount_text.dart';
import '../../models/product.dart';
import '../products/product_providers.dart';
import 'product_form_page.dart';
import 'product_image.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/tap_area.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produk'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                icon: const Icon(AppIcons.add),
                label: const Text('Tambah Produk'),
                onPressed: () => _openForm(context, ref),
              ),
            );
          }
          return _ProductGrid(products: products, ref: ref);
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_product',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => _openForm(context, ref),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductFormPage()),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  final WidgetRef ref;

  const _ProductGrid({required this.products, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = isWide
            ? (constraints.maxWidth ~/ 200).clamp(3, 6)
            : 2;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productListProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isWide ? 1.2 : 1.0,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductCard(
              product: products[i],
              onTap: () => _edit(context, products[i]),
              onToggleReady: () => _toggle(products[i]),
            ),
          ),
        );
      },
    );
  }

  void _edit(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProductFormPage(product: product)),
    );
  }

  void _toggle(Product product) async {
    final repo = ref.read(productRepositoryProvider);
    await repo.toggleReady(product.id!, !product.ready);
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggleReady;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onToggleReady,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return TapArea(
      label: product.name,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: product.imagePath != null
                  ? ProductImage(
                      path: product.imagePath,
                      placeholder: Container(
                          color: AppColors.background,
                          child: const Icon(AppIcons.restaurant, size: AppIcons.xl,
                              color: AppColors.textSecondary)),
                    )
                  : Container(
                      color: AppColors.background,
                      child: const Center(
                        child: Icon(AppIcons.restaurant, size: AppIcons.xl,
                            color: AppColors.textSecondary),
                      ),
                    ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TapArea(
                          label: 'Ubah status ${product.name}',
                          borderRadius: BorderRadius.circular(8),
                          onTap: onToggleReady,
                          child: ReadyChip(ready: product.ready),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      amount: product.price,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.price,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

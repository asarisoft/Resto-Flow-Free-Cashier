import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/ready_chip.dart';
import '../../core/widgets/tap_area.dart';
import '../../models/product.dart';
import 'product_image.dart';

/// Grid kartu produk yang SAMA untuk POS dan halaman Produk.
const productGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 220,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  childAspectRatio: 0.8,
);

/// Kartu produk: foto penuh lebar (cover), nama 1 baris, harga + chip status.
/// [cartQty] > 0 menandai terpilih (POS). [onToggleReady] membuat chip bisa diketuk.
class ProductCard extends StatelessWidget {
  final Product product;
  final int cartQty;
  final VoidCallback? onTap;
  final VoidCallback? onToggleReady;

  const ProductCard({
    super.key,
    required this.product,
    this.cartQty = 0,
    this.onTap,
    this.onToggleReady,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final selected = cartQty > 0;
    return TapArea(
      label: product.ready ? product.name : '${product.name}, habis',
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: product.ready ? 1 : 0.45,
                    child: ProductImage(
                      path: product.imagePath,
                      fit: BoxFit.cover,
                      placeholder: const _ImagePlaceholder(),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$cartQty',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: AmountText(
                          amount: product.price,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.price,
                          ),
                        ),
                      ),
                      onToggleReady == null
                          ? ReadyChip(ready: product.ready, stock: product.stock)
                          : TapArea(
                              label: 'Ubah status ${product.name}',
                              borderRadius: BorderRadius.circular(8),
                              onTap: onToggleReady,
                              child: ReadyChip(ready: product.ready, stock: product.stock),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Icon(AppIcons.food, size: AppIcons.xl, color: AppColors.textSecondary),
      ),
    );
  }
}

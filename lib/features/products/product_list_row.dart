import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/clay.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/qty_stepper.dart';
import '../../core/widgets/ready_chip.dart';
import '../../core/widgets/tap_area.dart';
import '../../models/product.dart';
import 'product_image.dart';

/// Teks saat pencarian tidak ada hasil (Produk & POS).
const productNotFoundText = 'Produk tidak ditemukan';
const productEmptyText = 'Belum ada produk — tambah di menu Produk';

/// Satu baris produk (mode list): foto kecil, nama, harga, chip stok/status.
/// Parameter sama dengan `ProductCard`.
class ProductListRow extends StatelessWidget {
  final Product product;
  final int cartQty;
  final VoidCallback? onTap;
  final VoidCallback? onToggleReady;

  /// Jika diisi dan [cartQty] > 0: stepper − qty + menggantikan chip.
  final ValueChanged<int>? onQtyChanged;

  const ProductListRow({
    super.key,
    required this.product,
    this.cartQty = 0,
    this.onTap,
    this.onToggleReady,
    this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final chip = ReadyChip(ready: product.ready, stock: product.stock);
    final stepper = cartQty > 0 && onQtyChanged != null;
    final row = TapArea(
      label: product.ready ? product.name : '${product.name}, habis',
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: DecoratedBox(
        decoration: ClayDecoration.box(radius: 16, compact: true).copyWith(
          border: cartQty > 0
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  width: 1.5,
                )
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Opacity(
                      opacity: product.ready ? 1 : 0.45,
                      child: ProductImage(
                        path: product.imagePath,
                        placeholder: const ColoredBox(
                          color: AppColors.lilac,
                          child: Icon(
                            AppIcons.food,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartQty > 0 && !stepper
                            ? '${product.name}  ×$cartQty'
                            : product.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 8),
                if (stepper)
                  const SizedBox(width: 136, height: 48)
                else
                  onToggleReady == null
                      ? chip
                      : TapArea(
                          label: 'Ubah status ${product.name}',
                          borderRadius: BorderRadius.circular(8),
                          onTap: onToggleReady,
                          child: chip,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: !stepper
          ? row
          : Stack(
              children: [
                row,
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: QtyStepper(
                      compact: true,
                      value: cartQty,
                      onChanged: onQtyChanged!,
                      name: product.name,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

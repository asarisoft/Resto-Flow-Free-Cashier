import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/resto_profile.dart';
import '../../models/transaction.dart' as models;
import '../../printer/receipt_builder.dart';

/// Preview nota: teks yang sama persis dengan yang dikirim ke printer.
class ReceiptPreview extends StatelessWidget {
  final RestoProfile profile;
  final models.Transaction? txn;

  const ReceiptPreview({super.key, required this.profile, this.txn});

  @override
  Widget build(BuildContext context) {
    final cols = profile.paperWidth == 80 ? 48 : 32;
    final text = ReceiptBuilder.buildText(txn ?? ReceiptBuilder.sampleTransaction(), profile);
    return Semantics(
      container: true,
      label: 'Preview nota kertas ${profile.paperWidth} mm',
      child: Container(
        width: cols * 7.4 + 32,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: AppColors.clayShadow, offset: Offset(6, 8), blurRadius: 18),
          ],
        ),
        child: Text(
          text.trimRight(),
          softWrap: false,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

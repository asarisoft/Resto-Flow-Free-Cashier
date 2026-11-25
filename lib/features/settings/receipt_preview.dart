import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/resto_profile.dart';
import '../../models/transaction.dart' as models;
import '../../printer/receipt_builder.dart';
import 'logo_image_service.dart';

/// Preview nota: teks yang sama persis dengan yang dikirim ke printer.
class ReceiptPreview extends StatelessWidget {
  final RestoProfile profile;
  final models.Transaction? txn;

  const ReceiptPreview({super.key, required this.profile, this.txn});

  @override
  Widget build(BuildContext context) {
    final text = ReceiptBuilder.buildText(txn ?? ReceiptBuilder.sampleTransaction(), profile, withName: false).trimRight();
    final style = AppTypography.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
      color: AppColors.textPrimary,
    );
    // Lebar kotak = lebar teks asli (font monospace beda per device).
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textWidth = painter.width;
    painter.dispose();
    final logo = profile.logoPath;
    return Semantics(
      container: true,
      label: 'Preview nota kertas ${profile.paperWidth} mm',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: AppColors.clayShadow, offset: Offset(6, 8), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.useLogo && logo != null && logo.isNotEmpty)
              Container(
                width: textWidth,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 8),
                child: _LogoPreview(path: logo, width: textWidth * 0.6),
              ),
            // Nama toko besar & tebal, seperti cetak ukuran ganda printer.
            SizedBox(
              width: textWidth,
              child: Text(
                profile.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: style?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            Text(text, softWrap: false, style: style),
          ],
        ),
      ),
    );
  }
}

/// Logo hitam-putih (seperti hasil printer thermal); file hilang/rusak → kosong.
class _LogoPreview extends StatelessWidget {
  final String path;
  final double width;
  const _LogoPreview({required this.path, required this.width});

  static const _gray = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: LogoImageService.resolvePath(path),
      builder: (_, snap) {
        final abs = snap.data;
        if (abs == null) return const SizedBox.shrink();
        return ColorFiltered(
          colorFilter: _gray,
          child: Image.file(
            File(abs),
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

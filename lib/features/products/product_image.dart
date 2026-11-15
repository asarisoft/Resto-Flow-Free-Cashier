import 'dart:io';
import 'package:flutter/material.dart';
import 'product_image_service.dart';

/// Shows a product photo from the local `imagePath` (relative to
/// `<appDocuments>/images/`).
class ProductImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Widget placeholder;

  const ProductImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.isEmpty) return placeholder;
    return FutureBuilder<String>(
      future: ProductImageService.resolvePath(value),
      builder: (context, snap) {
        final absolute = snap.data;
        if (absolute == null) return placeholder;
        return Image.file(
          File(absolute),
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder,
        );
      },
    );
  }
}

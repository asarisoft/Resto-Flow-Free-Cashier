import 'package:flutter/material.dart';

/// Logo KasirKita (kotak membulat). Dekoratif: nama app selalu ada di teks sebelahnya.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/images/app_logo.webp',
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
  }
}

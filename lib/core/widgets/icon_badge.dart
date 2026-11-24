import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Kotak lilac 36x36 untuk ikon di depan input (prefixIcon).
class IconBadge extends StatelessWidget {
  final IconData icon;
  const IconBadge(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          color: AppColors.lilac,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

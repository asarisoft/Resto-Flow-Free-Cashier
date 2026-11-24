import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding, this.height, this.color});

  @override
  Widget build(BuildContext context) {
    // Material transparan di bawah Ink: tile di dalam (ListTile, InkWell)
    // tetap menampilkan background dan ripple.
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: ClayDecoration.box(color: color ?? AppColors.surface),
        child: child,
      ),
    );
  }
}

class AppCardButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  const AppCardButton({super.key, required this.child, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ClayDecoration.box(color: color ?? AppColors.surface),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: AppTypography.textTheme.bodyLarge!,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';

/// Bayangan clay di DecoratedBox LUAR; Material di dalam memotong ripple
/// tanpa memotong bayangan.
class _ClaySurface extends StatelessWidget {
  final Widget child;
  final Color color;
  final double? height;
  final VoidCallback? onTap;

  const _ClaySurface({
    required this.child,
    required this.color,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: ClayDecoration.box(color: color),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? SizedBox(height: height, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: SizedBox(height: height, child: child),
              ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _ClaySurface(
      color: color ?? AppColors.surface,
      height: height,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
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
    return _ClaySurface(
      color: color ?? AppColors.surface,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: AppTypography.textTheme.bodyLarge!,
          child: child,
        ),
      ),
    );
  }
}

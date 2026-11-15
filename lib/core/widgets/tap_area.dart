import 'package:flutter/material.dart';

/// Area tap dengan ripple di atas konten + Semantics tombol berlabel.
/// Pengganti GestureDetector untuk kartu/item yang bisa diketuk.
class TapArea extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String label;
  final BorderRadius? borderRadius;

  const TapArea({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, borderRadius: borderRadius),
            ),
          ),
        ],
      ),
    );
  }
}

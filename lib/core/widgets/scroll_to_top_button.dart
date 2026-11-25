import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/clay.dart';
import 'tap_area.dart';

/// Tombol clay bulat "Kembali ke atas" untuk daftar panjang. Muncul (fade)
/// saat offset > 1 layar; hilang di dekat atas. Letakkan di slot FAB.
class ScrollToTopButton extends StatefulWidget {
  final ScrollController controller;
  /// Jarak di bawah tombol saat tampil (mis. di atas FAB lain).
  final double bottomGap;
  const ScrollToTopButton(
      {super.key, required this.controller, this.bottomGap = 0});

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopButton old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final c = widget.controller;
    if (!c.hasClients) return;
    final show = c.offset > c.position.viewportDimension;
    if (show != _show) setState(() => _show = show);
  }

  void _toTop() {
    final d = AppMotion.of(context);
    if (d == Duration.zero) {
      widget.controller.jumpTo(0);
    } else {
      widget.controller.animateTo(0, duration: d, curve: AppMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.fast),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: !_show
          ? const SizedBox.shrink(key: ValueKey('scroll-top-hidden'))
          : Padding(
              key: const ValueKey('scroll-top'),
              padding: EdgeInsets.only(bottom: widget.bottomGap),
              child: Tooltip(
                message: 'Kembali ke atas',
                child: SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: ClayDecoration.box(
                    color: AppColors.surface,
                    radius: 24,
                    compact: true,
                  ),
                  child: TapArea(
                    label: 'Kembali ke atas',
                    onTap: _toTop,
                    borderRadius: BorderRadius.circular(24),
                    child: const Center(
                      child: Icon(AppIcons.arrowUp,
                          size: AppIcons.md, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
            ),
    );
  }
}

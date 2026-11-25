import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/clay.dart';
import 'tap_area.dart';

/// Pasangan tombol clay bulat untuk daftar panjang. "Kembali ke atas" muncul
/// (fade) saat offset > 1 layar; "Ke bawah" muncul saat belum dekat ujung
/// (lompat ke ujung baris yang termuat, sehingga batch berikutnya ikut dimuat).
/// Letakkan di slot FAB.
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
  bool _showUp = false;
  bool _showDown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
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
    if (!mounted || !c.hasClients || !c.position.hasContentDimensions) return;
    final p = c.position;
    final up = p.pixels > p.viewportDimension;
    final down = p.extentAfter > _nearEnd;
    if (up != _showUp || down != _showDown) {
      setState(() {
        _showUp = up;
        _showDown = down;
      });
    }
  }

  static const _nearEnd = 100.0;

  void _go(double target) {
    final d = AppMotion.of(context);
    if (d == Duration.zero) {
      widget.controller.jumpTo(target);
    } else {
      widget.controller.animateTo(target, duration: d, curve: AppMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ukuran konten bisa berubah tanpa event scroll (data dimuat): cek ulang.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    final c = widget.controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          show: _showUp,
          tooltip: 'Kembali ke atas',
          icon: AppIcons.arrowUp,
          bottomGap: 8,
          onTap: () => _go(0),
        ),
        _RoundButton(
          show: _showDown,
          tooltip: 'Ke bawah',
          icon: AppIcons.arrowDown,
          bottomGap: widget.bottomGap,
          onTap: () => _go(c.position.maxScrollExtent),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final bool show;
  final String tooltip;
  final IconData icon;
  final double bottomGap;
  final VoidCallback onTap;

  const _RoundButton({
    required this.show,
    required this.tooltip,
    required this.icon,
    required this.bottomGap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.fast),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: !show
          ? SizedBox.shrink(key: ValueKey('$tooltip-hidden'))
          : Padding(
              key: ValueKey(tooltip),
              padding: EdgeInsets.only(bottom: bottomGap),
              child: Tooltip(
                message: tooltip,
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
                      label: tooltip,
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: Icon(icon,
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
